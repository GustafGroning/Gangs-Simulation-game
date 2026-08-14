class_name Scorer
extends RefCounted
# gangs-action-choice.md §3. score = utility − risk + affinity + commitment.
# The scorer NEVER branches on action identity — it calls action.evaluate()
# and does arithmetic (hard rule 2). It reads belief state only; the turn
# loop asserts WorldState.events was never touched around each call.
#
# Contributions are populated DURING scoring — they become the two
# explanatory terms on every chronicle line.


static func score_all(ws: WorldState, c: Character, cands: Array) -> void:
	for cand: ActionCandidate in cands:
		_score(ws, c, cand)


static func _score(ws: WorldState, c: Character, cand: ActionCandidate) -> void:
	var action := ActionRegistry.get_action(cand.action)
	var target: Character = ws.characters.get(cand.target_id) if cand.target_id != -1 else null

	# Utility: Σ weight[goal] × magnitude. LOYALTY/VENGEANCE weights are
	# target-indexed; the scalar goals come from `goals`.
	var mags := action.evaluate(ws, c, target)
	var utility := 0.0
	for g in mags:
		var m: float = mags[g]
		assert(m >= -1.0 and m <= 1.0,
			"action %s magnitude %f for goal %d outside -1..1 — unnormalized evaluate" % [cand.action, m, g])
		var weight := 0.0
		match g:
			E.Goal.VENGEANCE:
				weight = c.vengeance.get(cand.target_id, 0.0)
			E.Goal.LOYALTY:
				weight = c.loyalty.get(cand.target_id, 0.0)
			_:
				weight = c.goals.get(g, 0.0)
		var term := weight * m
		utility += term
		if absf(term) > 0.001:
			cand.contributions[E.Goal.keys()[g].to_lower()] = term
	cand.utility = utility

	# Risk — derived from trace templates.
	cand.risk = Risk.perceived(ws, c, action, cand)
	if cand.risk > 0.001:
		cand.contributions["risk"] = -cand.risk

	# Trait affinity — colours choices, must not dominate them.
	var affinity := 0.0
	for t in c.traits:
		for tag in Tuning.TRAIT_TAG_AFFINITY.get(t, []):
			if tag in action.tags:
				affinity += Tuning.AFFINITY_BONUS
	cand.affinity = affinity
	if affinity > 0.0:
		cand.contributions["affinity"] = affinity

	# Loyal hard veto: no hostile action against the patron.
	var hostile := E.ActionTag.VIOLENCE in action.tags or E.ActionTag.DECEPTION in action.tags
	if hostile and c.has_trait(E.Trait.LOYAL) and cand.target_id == c.patron_id and cand.target_id != -1:
		cand.score = Tuning.LOYAL_VETO_SCORE
		cand.contributions["loyal_veto"] = Tuning.LOYAL_VETO_SCORE
		return

	# Repetition penalty (skipped for active plan steps — phase 5).
	var repetition := 0.0
	if cand.action == c.last_action and cand.target_id == c.last_target and cand.action != &"idle":
		repetition = Tuning.REPETITION_PENALTY
		cand.contributions["repetition"] = -repetition

	cand.commitment = 0.0  # plan commitment lands in phase 5
	cand.score = utility - cand.risk + affinity + cand.commitment - repetition


# The two largest-magnitude terms, for the chronicle.
static func top_terms(cand: ActionCandidate, count: int = 2) -> String:
	var keys := cand.contributions.keys()
	keys.sort_custom(func(a, b):
		var va: float = absf(cand.contributions[a])
		var vb: float = absf(cand.contributions[b])
		return va > vb if va != vb else str(a) < str(b))
	var parts := []
	for i in mini(count, keys.size()):
		parts.append("%s %+.2f" % [keys[i], cand.contributions[keys[i]]])
	return " · ".join(parts) if not parts.is_empty() else "no drives"
