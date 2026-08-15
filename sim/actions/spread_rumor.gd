class_name SpreadRumorAction
extends Action
# design_doc.md "Whisper" section / doc 5 phase 6. Deliberately tell a chosen
# target (the candidate target, drawn from attention like any other targeted
# action) a belief the actor already holds. Distinct from passive gossip
# (Beliefs.transmission, which rolls automatically every turn for every
# neighbor): this is a motivated, chosen act with its own trace.


func _init() -> void:
	id = &"spread_rumor"
	tags = [E.ActionTag.DECEPTION]
	priority = 5  # Whisper
	targeted = true
	var t := TraceTemplate.new()
	t.kind = E.TraceKind.HEARSAY
	t.reveals = [E.Field.ACTOR, E.Field.ACTION, E.Field.TARGET]
	t.base_detectability = Tuning.SPREAD_RUMOR_TRACE_DETECT
	trace_templates = [t]


func requires(_world: WorldState, actor: Character, target: Character) -> bool:
	if target == null or target.state != E.CharState.ACTIVE or target.id == actor.id:
		return false
	return _best_belief(actor, target.id) != null


func evaluate(_world: WorldState, actor: Character, target: Character) -> Dictionary:
	var b := _best_belief(actor, target.id)
	if b == null:
		return {}
	var named := int(b.claim.get(E.Field.ACTOR, -1))
	var vengeance_mag := clampf(b.confidence, 0.0, 1.0) if named != -1 and actor.vengeance.get(named, 0.0) > 0.0 else 0.0
	return {
		E.Goal.VENGEANCE: vengeance_mag,
		E.Goal.AMBITION: Tuning.SPREAD_RUMOR_AMBITION_MAG,
	}


func execute(world: WorldState, cand: ActionCandidate) -> Event:
	var actor: Character = world.characters[cand.actor_id]
	var target: Character = world.characters[cand.target_id]
	var b := _best_belief(actor, target.id)
	if b == null:
		return null
	Beliefs.deliver_chosen(world, actor, target, b)
	var e := Event.new()
	e.turn = world.turn
	e.actor_id = actor.id
	e.action = id
	e.target_id = target.id
	e.visibility = E.Visibility.OPEN
	e.outcome = {"event_id": b.event_id}
	world.add_event(e)
	return e


# The belief worth telling THIS target: prefer whatever most damages someone
# the actor holds vengeance against; falls back to the actor's most
# confident actor-claim otherwise (Serves: Vengeance, Ambition).
static func _best_belief(actor: Character, target_id: int) -> Belief:
	var best: Belief = null
	var best_score := -1.0
	var keys := actor.beliefs.keys()
	keys.sort()
	for bk in keys:
		var b: Belief = actor.beliefs[bk]
		if b.event_id < 0 or not b.claim.has(E.Field.ACTOR):
			continue
		var named := int(b.claim[E.Field.ACTOR])
		if named == actor.id or named == target_id:
			continue  # nobody spreads a rumor implicating themselves or the listener
		var vengeance: float = actor.vengeance.get(named, 0.0)
		var score: float = vengeance * b.confidence + b.confidence * 0.01
		if best == null or score > best_score:
			best = b
			best_score = score
	return best
