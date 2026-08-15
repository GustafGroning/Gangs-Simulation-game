class_name DenounceAction
extends Action
# design_doc.md "Strike" section / doc 3 §4 / doc 5 phase 6. Publicly accuse
# a target of a hostile event the actor believes they committed; adjudicated
# by Judgment.process_all() at turn step 9. The action itself only queues the
# case onto WorldState.pending_judgments — Judgment owns the verdict so it
# can also be reached the same way from any future accusation source.


func _init() -> void:
	id = &"denounce"
	tags = [E.ActionTag.PUBLIC]
	priority = 3  # Strike
	targeted = true
	var t := TraceTemplate.new()
	t.kind = E.TraceKind.EYEWITNESS
	t.reveals = [E.Field.ACTOR, E.Field.ACTION, E.Field.TARGET]
	t.base_detectability = 1.0  # a public accusation is not a secret
	trace_templates = [t]
	visibilities = [E.Visibility.OPEN]


func requires(_world: WorldState, actor: Character, target: Character) -> bool:
	if target == null or target.state != E.CharState.ACTIVE or target.id == actor.id:
		return false
	if absi(actor.rank - target.rank) > Tuning.DENOUNCE_RANK_GAP_MAX:
		return false
	return _best_case(actor, target.id) != null


func evaluate(_world: WorldState, actor: Character, target: Character) -> Dictionary:
	var b := _best_case(actor, target.id)
	if b == null:
		return {}
	return {
		E.Goal.AMBITION: clampf(Tuning.DENOUNCE_AMBITION_MAG * b.confidence, 0.0, 1.0),
		E.Goal.VENGEANCE: clampf(b.confidence, 0.0, 1.0),
	}


func execute(world: WorldState, cand: ActionCandidate) -> Event:
	var actor: Character = world.characters[cand.actor_id]
	var target: Character = world.characters[cand.target_id]
	var b := _best_case(actor, target.id)
	if b == null:
		return null
	var e := Event.new()
	e.turn = world.turn
	e.actor_id = actor.id
	e.action = id
	e.target_id = target.id
	e.visibility = E.Visibility.OPEN
	e.outcome = {"event_id": b.event_id}
	world.add_event(e)
	world.pending_judgments.append({
		"accuser_id": actor.id, "accused_id": target.id, "event_id": b.event_id, "turn": world.turn,
	})
	return e


# The actor's strongest belief naming target as the actor of some event —
# "belief above threshold" per doc 3 §4.
static func _best_case(actor: Character, target_id: int) -> Belief:
	var best: Belief = null
	var keys := actor.beliefs.keys()
	keys.sort()
	for bk in keys:
		var b: Belief = actor.beliefs[bk]
		if b.event_id < 0:
			continue
		if int(b.claim.get(E.Field.ACTOR, -1)) != target_id:
			continue
		if b.confidence < Tuning.DENOUNCE_CONF_THRESHOLD:
			continue
		if best == null or b.confidence > best.confidence:
			best = b
	return best
