class_name Exogenous
extends RefCounted
# doc 3 §3. Demo scope prioritises Rival Hit and Arrest (doc 5 phase 6 task
# 7: "the two that matter most for texture") — the other six kinds in doc
# 3's table are BACKLOG.md. No module-level static state: the cooldown is
# derived from the event ledger each call so it stays correct across the
# many independent WorldStates a single test process runs through (a static
# var would leak between seeds — see world.gd's tree-distance cache for the
# pattern that DOES need one, keyed by instance id, and why this doesn't).


static func maybe_fire(ws: WorldState, chron: Chronicle, metrics: Metrics) -> void:
	if ws.turn - _last_exo_turn(ws) >= Tuning.EXO_COOLDOWN and ws.rng.randf() < Tuning.EXO_BASE_CHANCE * Tuning.RIVAL_HIT_SHARE:
		_rival_hit(ws, chron, metrics)
		return
	# Heat-triggered arrest is independently paced (doc 3: "Heat spike or job
	# DISASTER"), not gated by the rival-hit cooldown above.
	if ws.heat > Tuning.ARREST_HEAT_TRIGGER and ws.rng.randf() < Tuning.ARREST_HEAT_CHANCE:
		_arrest(ws, chron, metrics, "heat")


# Doc 3 §1: "DISASTER on a violent job may trigger an arrest." Called from
# turn.gd right after a violent job resolves as DISASTER.
static func maybe_arrest_from_disaster(ws: WorldState, worker_id: int, chron: Chronicle, metrics: Metrics) -> void:
	if ws.rng.randf() < Tuning.ARREST_FROM_DISASTER_CHANCE:
		_arrest(ws, chron, metrics, "disaster", worker_id)


static func _last_exo_turn(ws: WorldState) -> int:
	var evs: Array = ws.events
	for i in range(evs.size() - 1, -1, -1):
		var e: Event = evs[i]
		if ws.turn - e.turn > Tuning.EXO_COOLDOWN:
			break
		if e.action == &"rival_hit" or e.action == &"arrest":
			return e.turn
	return -1000


# "An outsider kills a member. Everyone suspects an insider anyway" — the
# actor is -1 (nobody in the tree), the trace (info/traces.gd) never reveals
# ACTOR, and the belief layer's own speculation machinery does the rest.
static func _rival_hit(ws: WorldState, chron: Chronicle, metrics: Metrics) -> void:
	var victim_id := _random_active(ws)
	if victim_id == -1:
		return
	var victim: Character = ws.characters[victim_id]

	var e := Event.new()
	e.turn = ws.turn
	e.actor_id = -1
	e.action = &"rival_hit"
	e.target_id = victim_id
	e.visibility = E.Visibility.OPEN
	ws.add_event(e)

	World.scrub_relationships(ws, victim_id)
	var sid := World.slot_of(ws, victim_id)
	if sid != -1:
		(ws.slots[sid] as Slot).occupant_id = -1
	victim.state = E.CharState.DEAD
	World.resync_tree(ws)
	Heat.add(ws, Tuning.HEAT_KILL)
	metrics.death()
	chron.line("☠ RIVAL HIT: %s is killed by an outsider. No one in the tree is responsible — but everyone will have a theory." % victim.name)


# Doc 3 §2: the one vacancy source with no culprit. Public, unambiguous fact
# (no trace is registered for &"arrest" in info/traces.gd, so no ACTOR
# speculation can ever attach to it). No CharState models a temporary
# absence (doc 1 §2: ACTIVE/DEAD/EXILED only), so this is a permanent
# removal for the demo — trading away "returns after 5-15 turns"; see
# QUESTIONS.md.
static func _arrest(ws: WorldState, chron: Chronicle, metrics: Metrics, cause: String, forced_id: int = -1) -> void:
	var victim_id := forced_id
	var forced_valid: bool = forced_id != -1 and ws.characters.has(forced_id) and (ws.characters[forced_id] as Character).state == E.CharState.ACTIVE
	if not forced_valid:
		victim_id = _random_active(ws)
	if victim_id == -1:
		return
	var victim: Character = ws.characters[victim_id]

	var e := Event.new()
	e.turn = ws.turn
	e.actor_id = -1  # the state, not an insider
	e.action = &"arrest"
	e.target_id = victim_id
	e.visibility = E.Visibility.OPEN
	e.outcome = {"cause": cause}
	ws.add_event(e)

	var sid := World.slot_of(ws, victim_id)
	if sid != -1:
		(ws.slots[sid] as Slot).occupant_id = -1
	victim.state = E.CharState.EXILED
	World.resync_tree(ws)
	metrics.arrest()

	var claim := {E.Field.ACTION: &"arrest", E.Field.TARGET: victim_id}
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.state == E.CharState.ACTIVE:
			Beliefs.grant_public(ws, c, e.id, claim, Tuning.FIRSTHAND_ACTOR_CONFIDENCE)
	chron.line("🚓 ARREST (%s): %s is taken in. No one is blamed — the board just opened a slot." % [cause, victim.name])


static func _random_active(ws: WorldState) -> int:
	var candidates: Array[int] = []
	var ids := ws.characters.keys()
	ids.sort()
	for cid in ids:
		if (ws.characters[cid] as Character).state == E.CharState.ACTIVE:
			candidates.append(cid)
	if candidates.is_empty():
		return -1
	return Rng.pick(candidates, ws.rng)
