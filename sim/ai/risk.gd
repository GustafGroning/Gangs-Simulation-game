class_name Risk
extends RefCounted
# gangs-action-choice.md §3b. perceived_risk = P_detected × P_attributed ×
# severity — DERIVED from the action's trace templates and tags, never
# authored per action (hard rule 4). All three are estimates BY the actor;
# traits distort the estimate, not the outcome. Reads tree structure,
# relationships and heat — never WorldState.events.


static func perceived(ws: WorldState, c: Character, action: Action, cand: ActionCandidate) -> float:
	if action.trace_templates.is_empty():
		return 0.0

	# P_detected: combine per-template detection chances.
	var density := _observer_density(ws, c, cand.target_id)
	var p_none := 1.0
	for t: TraceTemplate in action.trace_templates:
		var p := t.base_detectability * density * (1.0 + ws.heat)
		if c.has_trait(E.Trait.RECKLESS):
			p *= Tuning.RECKLESS_DETECT_MULT  # underestimates — gets caught constantly
		p_none *= 1.0 - clampf(p, 0.0, 0.95)
	var p_detected := 1.0 - p_none

	# P_attributed: does it land on me?
	var reveals_actor := false
	for t: TraceTemplate in action.trace_templates:
		if E.Field.ACTOR in t.reveals and cand.visibility != E.Visibility.ANONYMOUS:
			reveals_actor = true
	var p_attr := Tuning.P_ATTR_ACTOR_REVEALED if reveals_actor else Tuning.P_ATTR_BASE
	if cand.target_id != -1:
		var rel := World.relationship_of(ws, c.id, cand.target_id)
		if rel != null:
			p_attr += Tuning.P_ATTR_MOTIVE_WEIGHT * rel.known_motive
		# More people with motive against the target = safer for everyone.
		var alternatives := 0
		var ids := ws.characters.keys()
		ids.sort()
		for sid in ids:
			if sid == c.id or sid == cand.target_id:
				continue
			var orel := World.relationship_of(ws, sid, cand.target_id)
			if orel != null and orel.known_motive > 0.2:
				alternatives += 1
		p_attr -= Tuning.P_ATTR_ALT_RELIEF * alternatives
	p_attr = clampf(p_attr, 0.05, 1.0)

	# Severity from tags, scaled by heat; Craven inflates it.
	var severity := 0.0
	for tag in action.tags:
		severity = maxf(severity, float(Tuning.RISK_SEVERITY_BY_TAG.get(tag, 0.0)))
	severity *= 1.0 + ws.heat * 0.5
	if c.has_trait(E.Trait.CRAVEN):
		severity *= Tuning.CRAVEN_SEVERITY_MULT

	return clampf(p_detected * p_attr * severity * Tuning.RISK_SCALE, 0.0, Tuning.RISK_CAP)


# How watched is the neighbourhood of the target (or myself, untargeted)?
static func _observer_density(ws: WorldState, c: Character, target_id: int) -> float:
	var focus := target_id if target_id != -1 else c.id
	var dist := World.tree_distances(ws)
	var total := 0.0
	var n := 0
	var ids := ws.characters.keys()
	ids.sort()
	for cid in ids:
		if cid == c.id or cid == focus:
			continue
		if (ws.characters[cid] as Character).state != E.CharState.ACTIVE:
			continue
		var d: int = dist.get(cid, {}).get(focus, 99)
		total += Tuning.PROX_BY_DIST[mini(d, Tuning.PROX_BY_DIST.size() - 1)]
		n += 1
	return total / maxf(1.0, float(n))
