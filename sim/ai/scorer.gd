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
	var wu := weighted_utility(c, cand.target_id, mags, cand.action)
	cand.utility = wu["utility"]
	for g in wu["terms"]:
		if absf(wu["terms"][g]) > Tuning.CONTRIBUTION_DISPLAY_THRESHOLD:
			cand.contributions[g] = wu["terms"][g]

	# Risk — derived from trace templates.
	cand.risk = Risk.perceived(ws, c, action, cand)
	if cand.risk > Tuning.CONTRIBUTION_DISPLAY_THRESHOLD:
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

	# Plan commitment (gangs-action-choice.md §4): if this candidate matches
	# the character's active plan's current step, it gets the continuation
	# bonus (so a persisting intent doesn't flip-flop turn to turn) plus, for
	# a non-terminal step, the discounted terminal value γ^steps_remaining ×
	# terminal_score — the mechanism that lets a low-utility enabling step
	# compete with a high-value one-shot action. The terminal step's own
	# evaluate() already prices the goal in full, so only the bonus applies
	# there (adding the discounted terminal value too would double-count).
	var on_plan := c.plan != null and c.plan.step_index < c.plan.steps.size() \
		and _matches_step(cand, c.plan.steps[c.plan.step_index])
	if on_plan:
		var steps_remaining: int = c.plan.steps.size() - 1 - c.plan.step_index
		var discounted := 0.0
		if steps_remaining > 0:
			discounted = pow(Tuning.GAMMA, steps_remaining) * c.plan.terminal_score
		cand.commitment = Tuning.CONTINUATION_BONUS + discounted
		if absf(cand.commitment) > Tuning.CONTRIBUTION_DISPLAY_THRESHOLD:
			cand.contributions["plan"] = cand.commitment
	else:
		cand.commitment = 0.0

	# Repetition penalty — skipped for the active plan's own step; repeating
	# it isn't a flip-flopping loop, it's the plan working as intended.
	var repetition := 0.0
	if action.subject_to_repetition_penalty and not on_plan \
		and cand.action == c.last_action and cand.target_id == c.last_target:
		repetition = Tuning.REPETITION_PENALTY
		cand.contributions["repetition"] = -repetition

	cand.score = cand.utility - cand.risk + affinity + cand.commitment - repetition


static func _matches_step(cand: ActionCandidate, step: PlanStep) -> bool:
	return cand.action == step.action and cand.target_id == step.target_id \
		and cand.instrument_id == step.instrument_id


# Shared by the live scorer and the planner's plan-value estimate, so a
# plan's projected terminal_score uses the exact same weight lookup the real
# scorer will apply once the step is no longer gated. LOYALTY/VENGEANCE
# weights are target-indexed; the scalar goals come from `goals`. `context`
# is only for the assert message.
static func weighted_utility(c: Character, target_id: int, mags: Dictionary, context: String = "") -> Dictionary:
	var utility := 0.0
	var terms := {}
	for g in mags:
		var m: float = mags[g]
		assert(m >= -1.0 and m <= 1.0,
			"%s magnitude %f for goal %d outside -1..1 — unnormalized evaluate" % [context, m, g])
		var weight := 0.0
		match g:
			E.Goal.VENGEANCE:
				weight = c.vengeance.get(target_id, 0.0)
			E.Goal.LOYALTY:
				weight = c.loyalty.get(target_id, 0.0)
			_:
				weight = c.goals.get(g, 0.0)
		var term := weight * m
		utility += term
		terms[E.Goal.keys()[g].to_lower()] = term
	return {"utility": utility, "terms": terms}


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
