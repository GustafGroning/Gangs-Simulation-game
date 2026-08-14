class_name Weights
extends RefCounted
# gangs-action-choice.md §6. Goal weights move in response to what happened
# and decay toward the character's generated baseline — arcs that END are
# what read as stories. Reads BELIEFS only: vengeance scales with the
# confidence of the belief, not with truth (rumors get physical weight).


static func update(ws: WorldState) -> void:
	var ids := ws.characters.keys()
	ids.sort()
	for cid in ids:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE:
			continue
		_harm_beliefs(ws, c)
		_decay(c)


# "Believe you were harmed by X" → Vengeance[X] += severity × confidence.
static func _harm_beliefs(ws: WorldState, c: Character) -> void:
	var bkeys := c.beliefs.keys()
	bkeys.sort()
	for bk in bkeys:
		var b: Belief = c.beliefs[bk]
		if b.turn_acquired != ws.turn:
			continue
		var claimed_action := StringName(str(b.claim.get(E.Field.ACTION, "")))
		if not Tuning.VENGEANCE_HARM_SEVERITY.has(claimed_action):
			continue
		if int(b.claim.get(E.Field.TARGET, -1)) != c.id:
			continue
		var actor := int(b.claim.get(E.Field.ACTOR, -1))
		if actor == -1 or actor == c.id:
			continue
		var severity: float = Tuning.VENGEANCE_HARM_SEVERITY[claimed_action]
		var bump := severity * b.confidence * Tuning.VENGEANCE_BELIEF_RATE
		c.vengeance[actor] = clampf(float(c.vengeance.get(actor, 0.0)) + bump, 0.0, 1.0)


static func _decay(c: Character) -> void:
	for g in c.goals:
		var base: float = c.goal_baseline.get(g, c.goals[g])
		c.goals[g] = c.goals[g] + (base - c.goals[g]) * Tuning.WEIGHT_DECAY_RATE
	# Target-indexed weights decay toward zero; drop dust so dictionaries
	# stay small and serialization stays clean.
	for dict in [c.vengeance, c.loyalty]:
		var drop := []
		for t in dict:
			dict[t] = float(dict[t]) * (1.0 - Tuning.WEIGHT_DECAY_RATE)
			if dict[t] < 0.01:
				drop.append(t)
		for t in drop:
			dict.erase(t)
