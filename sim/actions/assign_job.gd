class_name AssignJobAction
extends Action
# doc GDD Command, rank-gated. Where the good evil lives: the same verb
# serves duty (keep the board moving, standing) and spite (give the rival
# the job you know will fail — reads vengeance[target] against expected
# failure). The job choice is a deterministic function of actor weights, so
# evaluate and execute derive the same one.


func _init() -> void:
	id = &"assign_job"
	tags = [E.ActionTag.SOCIAL]
	priority = 0  # Command
	targeted = true
	var t := TraceTemplate.new()
	t.kind = E.TraceKind.EYEWITNESS
	t.reveals = [E.Field.ACTOR, E.Field.ACTION, E.Field.TARGET]
	t.base_detectability = Tuning.ASSIGN_TRACE_DETECT
	trace_templates = [t]


func requires(world: WorldState, actor: Character, target: Character) -> bool:
	if target == null or actor.rank >= target.rank:
		return false
	if not (target.id in actor.crew_ids):
		return false
	if Job.assigned_open_job(world, target.id) != null:
		return false
	return _best_choice(world, actor, target)["job"] != null


func evaluate(world: WorldState, actor: Character, target: Character) -> Dictionary:
	return _best_choice(world, actor, target)["magnitudes"]


func execute(world: WorldState, cand: ActionCandidate) -> Event:
	var actor: Character = world.characters[cand.actor_id]
	var target: Character = world.characters[cand.target_id]
	var j: Job = _best_choice(world, actor, target)["job"]
	if j == null:
		return null
	j.assigned_to_id = target.id
	j.assigned_by_id = actor.id
	var e := Event.new()
	e.turn = world.turn
	e.actor_id = actor.id
	e.action = id
	e.target_id = target.id
	e.visibility = E.Visibility.OPEN
	e.outcome = {"job_id": j.id, "kind": String(j.kind)}
	world.add_event(e)
	return e


# Best job for THIS target under the actor's goal weights: duty values
# likely success (board runs well → standing); spite values likely failure
# scaled by vengeance[target].
func _best_choice(world: WorldState, actor: Character, target: Character) -> Dictionary:
	var vengeance: float = actor.vengeance.get(target.id, 0.0)
	var w_standing: float = actor.goals.get(E.Goal.STANDING, 0.0)
	var best: Job = null
	var best_score := -1.0
	var best_mags := {}
	for j: Job in Job.open_unassigned(world):
		if not j.rank_eligible(target.rank):
			continue
		var p_succ := clampf(Job.success_estimate(target, j), 0.0, 1.0)
		var mags := {
			E.Goal.STANDING: Tuning.ASSIGN_DUTY_STANDING * p_succ,
			E.Goal.VENGEANCE: (1.0 - p_succ),
		}
		var proxy: float = w_standing * mags[E.Goal.STANDING] + vengeance * mags[E.Goal.VENGEANCE]
		if proxy > best_score or (proxy == best_score and best != null and j.id < best.id):
			best = j
			best_score = proxy
			best_mags = mags
	return {"job": best, "magnitudes": best_mags}
