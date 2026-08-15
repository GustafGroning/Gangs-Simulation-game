class_name KillAction
extends Action
# design_doc.md "Strike" section / doc 5 phase 6. Removal → vacancy contest
# (the demo's one rank-change mechanism besides Judgment). "Opportunity or
# instrument" (doc's requires column) isn't a precise gate — read as
# physical proximity in the tree (an "opportunity") OR a grudge strong
# enough that the actor has gone looking for "an instrument". See
# QUESTIONS.md. The escalation ladder's terminal rung (sabotage_job -> kill,
# tuning.gd's ESCALATION_LADDER) — Frame is skipped, it isn't a demo verb.


func _init() -> void:
	id = &"kill"
	tags = [E.ActionTag.VIOLENCE]
	priority = 3  # Strike
	targeted = true
	var t := TraceTemplate.new()
	t.kind = E.TraceKind.EYEWITNESS
	t.reveals = [E.Field.ACTOR, E.Field.ACTION, E.Field.TARGET]
	t.base_detectability = Tuning.KILL_TRACE_DETECT
	trace_templates = [t]


func requires(_world: WorldState, actor: Character, target: Character) -> bool:
	if target == null or target.state != E.CharState.ACTIVE or target.id == actor.id:
		return false
	return _has_opportunity(actor, target)


func evaluate(_world: WorldState, actor: Character, target: Character) -> Dictionary:
	var superior := target.rank < actor.rank
	return {
		E.Goal.VENGEANCE: clampf(actor.vengeance.get(target.id, 0.0) + 0.3, 0.0, 1.0),
		E.Goal.AMBITION: clampf(Tuning.KILL_AMBITION_MAG * (Tuning.KILL_AMBITION_SUPERIOR_MULT if superior else 1.0), 0.0, 1.0),
	}


# The ladder's terminal rung: recoverable once vengeance is building but
# hasn't crossed the gate yet (proximity, being structural, never "clears on
# its own" the way a missing job or a missing opportunity through vengeance
# growth does).
func gated_recoverably(_world: WorldState, actor: Character, target: Character) -> bool:
	if target == null or target.state != E.CharState.ACTIVE or target.id == actor.id:
		return false
	return not _has_opportunity(actor, target) and actor.vengeance.get(target.id, 0.0) > 0.0


func plan_value(_world: WorldState, actor: Character, target: Character) -> Dictionary:
	if actor.vengeance.get(target.id, 0.0) <= 0.0:
		return {}
	var superior := target.rank < actor.rank
	return {
		E.Goal.VENGEANCE: clampf(actor.vengeance.get(target.id, 0.0) + 0.3, 0.0, 1.0),
		E.Goal.AMBITION: clampf(Tuning.KILL_AMBITION_MAG * (Tuning.KILL_AMBITION_SUPERIOR_MULT if superior else 1.0), 0.0, 1.0),
	}


func execute(world: WorldState, cand: ActionCandidate) -> Event:
	var actor: Character = world.characters[cand.actor_id]
	var target: Character = world.characters[cand.target_id]
	var e := Event.new()
	e.turn = world.turn
	e.actor_id = actor.id
	e.action = id
	e.target_id = target.id
	e.visibility = E.Visibility.OPEN
	world.add_event(e)
	World.scrub_relationships(world, target.id)
	var sid := World.slot_of(world, target.id)
	if sid != -1:
		(world.slots[sid] as Slot).occupant_id = -1
	target.state = E.CharState.DEAD
	World.resync_tree(world)
	Heat.add(world, Tuning.HEAT_KILL)
	return e


static func _has_opportunity(actor: Character, target: Character) -> bool:
	if target.id in actor.crew_ids or target.id == actor.patron_id:
		return true
	return actor.vengeance.get(target.id, 0.0) >= Tuning.KILL_VENGEANCE_GATE
