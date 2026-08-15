class_name SabotageJobAction
extends Action
# doc GDD Strike / doc 3 §1. Pulled forward from phase 6 (see DECISIONS.md
# and thoughts/phase_5_planner.md): the first hostile action, and the
# reason Job.assigned_turn/turn.gd's one-turn assignment→resolution latency
# exists — sabotage needs a target whose job is assigned but not yet
# resolved, which same-turn resolution never allowed anyone to observe.
#
# Doc 3's asymmetry: a sabotaged job still creates its ordinary take_job
# failure event with the ASSIGNEE as actor (Job.resolve, unconditionally) —
# this event, with the saboteur as actor, is the separate one that may or
# may not surface. reveals deliberately omits ACTOR (like most traces) so
# the normal belief/mutation machinery decides whether it's ever pinned on
# the right person.


func _init() -> void:
	id = &"sabotage_job"
	tags = [E.ActionTag.DECEPTION]
	priority = 3  # Strike
	targeted = true
	var t := TraceTemplate.new()
	t.kind = E.TraceKind.PHYSICAL
	t.reveals = [E.Field.ACTION, E.Field.TARGET]
	t.base_detectability = Tuning.SABOTAGE_TRACE_DETECT
	trace_templates = [t]


func requires(world: WorldState, _actor: Character, target: Character) -> bool:
	if target == null or target.state != E.CharState.ACTIVE:
		return false
	var j := Job.assigned_open_job(world, target.id)
	# assigned_turn < world.turn: must have been assigned on an EARLIER
	# turn — "know target's assignment" implies prior knowledge, not a job
	# someone else's higher-priority action assigned earlier this same turn.
	return j != null and j.assigned_turn < world.turn and j.sabotaged_by_id == -1


func evaluate(world: WorldState, _actor: Character, target: Character) -> Dictionary:
	var j := Job.assigned_open_job(world, target.id)
	if j == null:
		return {}
	# Spoiling a job that was headed for success is the most satisfying —
	# spoiling one already headed for FAILURE does little.
	var p_succ := clampf(Job.success_estimate(target, j), 0.0, 1.0)
	return {
		E.Goal.VENGEANCE: p_succ,
		E.Goal.AMBITION: Tuning.SABOTAGE_AMBITION_MAG,
	}


# Recoverable gate for the planner: target isn't mid-job right now, but
# will be again — this is the phase-5 vehicle for genuine multi-turn
# vengeance plans (AssignJob's own gate rarely fires once jobs are abundant
# enough to satisfy phase 4's no-inert-characters band; see DECISIONS.md).
func gated_recoverably(world: WorldState, _actor: Character, target: Character) -> bool:
	if target == null or target.state != E.CharState.ACTIVE:
		return false
	return Job.assigned_open_job(world, target.id) == null


func plan_value(_world: WorldState, actor: Character, target: Character) -> Dictionary:
	if actor.vengeance.get(target.id, 0.0) <= 0.0:
		return {}
	var typical := Job.new()
	typical.difficulty = Tuning.PLAN_ASSUMED_JOB_DIFFICULTY
	return {
		E.Goal.VENGEANCE: clampf(Job.success_estimate(target, typical), 0.0, 1.0),
		E.Goal.AMBITION: Tuning.SABOTAGE_AMBITION_MAG,
	}


func execute(world: WorldState, cand: ActionCandidate) -> Event:
	var actor: Character = world.characters[cand.actor_id]
	var target: Character = world.characters[cand.target_id]
	var j := Job.assigned_open_job(world, target.id)
	if j == null:
		return null
	j.sabotaged_by_id = actor.id
	var e := Event.new()
	e.turn = world.turn
	e.actor_id = actor.id
	e.action = id
	e.target_id = target.id
	e.visibility = E.Visibility.OPEN
	e.outcome = {"job_id": j.id, "kind": String(j.kind)}
	world.add_event(e)
	return e
