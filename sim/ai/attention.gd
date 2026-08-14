class_name Attention
extends RefCounted
# gangs-action-choice.md §1. ~6 salient others per character per turn.
# Reads tree structure, own goal dictionaries and OWN BELIEFS — never
# WorldState.events. A character who hasn't noticed the threat three nodes
# over is correct behaviour, not a bug.


static func build(ws: WorldState, c: Character) -> Array[int]:
	var picked: Array[int] = []
	var cap := Tuning.ATTENTION_SIZE
	if c.has_trait(E.Trait.PARANOID):
		cap += Tuning.ATTENTION_PARANOID_BONUS

	# Priority order: patron, patron's patron, subordinates, grudges and
	# loyalties, vacancy competitors, people from recent beliefs.
	var ordered: Array[int] = []
	if c.patron_id != -1:
		ordered.append(c.patron_id)
		var p: Character = ws.characters.get(c.patron_id)
		if p != null and p.patron_id != -1:
			ordered.append(p.patron_id)
	for m in c.crew_ids:
		ordered.append(m)
	var grudges := c.vengeance.keys()
	grudges.sort_custom(func(a, b):
		return c.vengeance[a] > c.vengeance[b] if c.vengeance[a] != c.vengeance[b] else a < b)
	for g in grudges:
		if c.vengeance[g] > 0.0:
			ordered.append(int(g))
	var loyal := c.loyalty.keys()
	loyal.sort_custom(func(a, b):
		return c.loyalty[a] > c.loyalty[b] if c.loyalty[a] != c.loyalty[b] else a < b)
	for l in loyal:
		if c.loyalty[l] > 0.0:
			ordered.append(int(l))
	ordered.append_array(_vacancy_competitors(ws, c))
	ordered.append_array(_recent_belief_people(ws, c))

	for cid in ordered:
		if picked.size() >= cap:
			break
		if cid != c.id and not (cid in picked) and _active(ws, cid):
			picked.append(cid)

	# Curiosity slots — prevents the graph from calcifying.
	var others: Array[int] = []
	for cid: int in ws.characters:
		if cid != c.id and _active(ws, cid) and not (cid in picked):
			others.append(cid)
	others.sort()
	for i in Tuning.ATTENTION_RANDOM_SLOTS:
		if others.is_empty():
			break
		var pick := int(Rng.pick(others, ws.rng))
		others.erase(pick)
		picked.append(pick)
	return picked


static func _active(ws: WorldState, cid: int) -> bool:
	var c: Character = ws.characters.get(cid)
	return c != null and c.state == E.CharState.ACTIVE


# Same-rank characters when a slot one rank above (or at my rank) is vacant.
static func _vacancy_competitors(ws: WorldState, c: Character) -> Array[int]:
	var out: Array[int] = []
	var vacant_ranks := {}
	var sids := ws.slots.keys()
	sids.sort()
	for sid in sids:
		var s: Slot = ws.slots[sid]
		if s.occupant_id == -1:
			vacant_ranks[s.rank] = true
	if vacant_ranks.has(c.rank - 1) or vacant_ranks.has(c.rank):
		var ids := ws.characters.keys()
		ids.sort()
		for cid in ids:
			if cid != c.id and _active(ws, cid) and (ws.characters[cid] as Character).rank == c.rank:
				out.append(cid)
	return out


static func _recent_belief_people(ws: WorldState, c: Character) -> Array[int]:
	var out: Array[int] = []
	var bkeys := c.beliefs.keys()
	bkeys.sort()
	for bk in bkeys:
		var b: Belief = c.beliefs[bk]
		if ws.turn - b.turn_acquired > Tuning.BELIEF_RECENCY_WINDOW:
			continue
		for field in [E.Field.ACTOR, E.Field.TARGET]:
			if b.claim.has(field):
				out.append(int(b.claim[field]))
	return out
