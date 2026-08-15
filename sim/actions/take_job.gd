class_name TakeJobAction
extends Action
# doc GDD Earn. Self-select onto the best open job for this actor; the work
# event itself is created by job resolution at the end of the turn.


func _init() -> void:
	id = &"take_job"
	tags = [E.ActionTag.ECONOMIC]
	priority = 2  # Earn
	targeted = false
	var t := TraceTemplate.new()
	t.kind = E.TraceKind.EYEWITNESS
	t.reveals = [E.Field.ACTOR, E.Field.ACTION, E.Field.TARGET]
	t.base_detectability = Tuning.TAKEJOB_RISK_DETECT_ESTIMATE
	trace_templates = [t]


func requires(world: WorldState, actor: Character, _target: Character) -> bool:
	if Job.assigned_open_job(world, actor.id) != null:
		return false  # already has work this turn
	return Job.best_for(world, actor) != null


func evaluate(world: WorldState, actor: Character, _target: Character) -> Dictionary:
	var j := Job.best_for(world, actor)
	if j == null:
		return {}
	var quality := Job.success_estimate(actor, j) - 0.45  # negative = likely failure
	return {
		E.Goal.STANDING: clampf(quality * 2.0 * j.payout_standing / Tuning.TAKEJOB_STANDING_NORM, -1.0, 1.0),
		E.Goal.WEALTH: clampf(maxf(0.0, quality) * 2.0 * j.payout_money / Tuning.TAKEJOB_MONEY_NORM, 0.0, 1.0),
	}


func execute(world: WorldState, cand: ActionCandidate) -> Event:
	var actor: Character = world.characters[cand.actor_id]
	var j := Job.best_for(world, actor)
	if j == null:
		return null
	j.assigned_to_id = actor.id
	j.assigned_turn = world.turn
	return null  # the take_job event is written by Job.resolve


# Detectability of worked jobs depends on the job kind (doc 3 trace
# profiles); failures are conspicuous.
func trace_specs(_ws: WorldState, e: Event) -> Array:
	var kind := StringName(str(e.outcome.get("kind", "")))
	var detect: float = Tuning.JOB_TRACE_DETECT.get(kind, 0.3)
	var outcome := int(e.outcome.get("outcome", E.JobOutcome.SUCCESS))
	if outcome == E.JobOutcome.FAILURE or outcome == E.JobOutcome.DISASTER:
		detect += Tuning.JOB_FAILURE_DETECT_BONUS
	return [{
		"kind": E.TraceKind.EYEWITNESS,
		"reveals": [E.Field.ACTOR, E.Field.ACTION, E.Field.TARGET],
		"detect": detect,
		"points_to_id": e.actor_id,
	}]
