class_name Planner
extends RefCounted
# gangs-action-choice.md §4. Plan generation, persistence and resolution —
# the fix for the tempo problem (a high-value gated action shouldn't be
# discarded, it should be planned toward).
#
# Phase 5 scope: the verb set is still only TakeJob/AssignJob
# (demo_tasks.md's phase 5 Goal line). Neither has an actor-achievable
# multi-step precondition chain — AssignJob's only recoverable gate, once
# rank/crew eligibility already holds, is "no open job matches the target
# right now" (Action.gated_recoverably), which clears itself on the next
# board refresh rather than through another action. True backward-chaining
# through an intermediate action (the doc's DoFavor→Kill example) needs
# verbs outside the 7-verb demo (DoFavor is post-demo; Sabotage/Kill are
# phase 6) — see QUESTIONS.md and thoughts/phase_5_planner.md. Plans this
# phase are single-step, gated purely on that job-availability condition,
# and persist across turns via patience the same way a longer chain would;
# the escalation ladder (Tuning.ESCALATION_LADDER, empty until phase 6) is
# wired end to end so adding Sabotage/Kill later needs no planner changes.
#
# Reads only belief-adjacent character state (own attention/goals/vengeance,
# other characters' structural/public fields, the public job board) — never
# WorldState.events, same boundary the scorer holds.


# Called once per active character per turn, after attention is built and
# before candidate generation, so a freshly-formed plan's step is visible to
# this turn's Candidates.generate() the moment it stops being gated.
static func maybe_start(ws: WorldState, c: Character) -> void:
	if c.plan != null:
		return
	var best_action: Action = null
	var best_target: Character = null
	var best_score := -INF

	for tid in c.attention:
		var target: Character = ws.characters.get(tid)
		if target == null:
			continue
		for action: Action in ActionRegistry.all_actions():
			if not action.targeted or action.requires(ws, c, target):
				continue  # untargeted, or already legal — the normal candidate flow covers it
			if not action.gated_recoverably(ws, c, target):
				continue
			var mags := action.plan_value(ws, c, target)
			if mags.is_empty():
				continue
			var utility: float = Scorer.weighted_utility(c, target.id, mags, action.id)["utility"]
			if utility > best_score:
				best_score = utility
				best_action = action
				best_target = target

	if best_action == null or best_score < Tuning.PLAN_MIN_TERMINAL_SCORE:
		return

	var step := PlanStep.new()
	step.action = best_action.id
	step.target_id = best_target.id
	step.instrument_id = -1
	step.visibility = E.Visibility.OPEN

	var p := Plan.new()
	p.goal_action = best_action.id
	p.target_id = best_target.id
	p.steps = [step]
	p.step_index = 0
	p.patience = Tuning.DEFAULT_PATIENCE
	p.frustration = 0
	p.terminal_score = best_score
	c.plan = p


# Called once per active character per turn, after resolution (so
# actor.last_action/last_target reflect what actually executed). Advances or
# completes on a match, otherwise ticks patience/frustration and aborts (or
# escalates, once phase 6 populates the ladder) on exhaustion.
static func tick_after_resolution(ws: WorldState, c: Character, metrics: Metrics) -> void:
	var p := c.plan
	if p == null:
		return
	var step: PlanStep = p.steps[p.step_index]

	if c.last_action == step.action and c.last_target == step.target_id:
		p.step_index += 1
		if p.step_index >= p.steps.size():
			metrics.plan_resolved(true, _length(p))
			c.plan = null
		return

	var target: Character = ws.characters.get(step.target_id)
	var alive := target != null and target.state == E.CharState.ACTIVE
	p.patience -= 1
	if alive and ActionRegistry.get_action(step.action).gated_recoverably(ws, c, target):
		p.frustration += 1

	if not alive or p.patience <= 0 or p.frustration >= Tuning.FRUSTRATION_THRESHOLD:
		if not _try_escalate(ws, c, target):
			metrics.plan_resolved(false, _length(p))
			c.plan = null


static func _length(p: Plan) -> int:
	return maxi(Tuning.DEFAULT_PATIENCE - p.patience + 1, 1)


# Next rung of Tuning.ESCALATION_LADDER for this plan's goal_action, if the
# config has one and it's currently reachable. Empty ladder (phase 5) always
# returns false — abandon-and-replan, gangs-action-choice.md §4's other
# valid branch, not a fallback of last resort.
static func _try_escalate(ws: WorldState, c: Character, target: Character) -> bool:
	if target == null or target.state != E.CharState.ACTIVE:
		return false
	var ladder: Array = Tuning.ESCALATION_LADDER.get(c.plan.goal_action, [])
	var idx: int = ladder.find(c.plan.goal_action)
	if idx == -1 or idx + 1 >= ladder.size():
		return false
	var next_id: StringName = ladder[idx + 1]
	var next_action := ActionRegistry.get_action(next_id)
	if not (next_action.requires(ws, c, target) or next_action.gated_recoverably(ws, c, target)):
		return false
	var step := PlanStep.new()
	step.action = next_id
	step.target_id = target.id
	step.instrument_id = -1
	step.visibility = E.Visibility.OPEN
	c.plan.steps.append(step)
	c.plan.step_index += 1
	c.plan.goal_action = next_id
	c.plan.patience = Tuning.DEFAULT_PATIENCE
	c.plan.frustration = 0
	return true
