class_name DigAction
extends Action
# design_doc.md "Learn" section / doc 5 phase 6. Resolves a held belief's
# ACTOR field — the schema's Field enum (doc 1 §2) has no MOTIVE value and
# nothing currently populates INSTRUMENT, so Dig is scoped to ACTOR, which
# the doc itself calls "the crux of the entire design". See QUESTIONS.md.
#
# Untargeted, like TakeJob/AssignJob: the Action contract's target is always
# a Character, never a Belief, so Dig auto-selects the single most
# dig-worthy belief the actor holds rather than exposing belief identity as
# a candidate target (see _best_belief).
#
# evaluate()/requires() read only the actor's own beliefs (belief-state
# boundary, hard rule 3). The actual outcome roll in execute() reads
# WorldState (traces, the underlying event) — legal at execution time, the
# same way Job.resolve() reads ground truth to resolve a job (Job's
# perceived-risk estimate is likewise belief-only; the real dice land at
# execution).


func _init() -> void:
	id = &"dig"
	tags = [E.ActionTag.INVESTIGATIVE]
	priority = 6  # Learn
	targeted = false
	# "Digging emits its own trace" — a HEARSAY trace revealing the digger
	# (ACTOR = the digger, via the default points_to "actor") and what/whom
	# they're digging around.
	var t := TraceTemplate.new()
	t.kind = E.TraceKind.HEARSAY
	t.reveals = [E.Field.ACTOR, E.Field.ACTION, E.Field.TARGET]
	t.base_detectability = Tuning.DIG_TRACE_DETECTABILITY
	trace_templates = [t]


func requires(_world: WorldState, actor: Character, _target: Character) -> bool:
	return _best_belief(actor) != null


func evaluate(_world: WorldState, actor: Character, _target: Character) -> Dictionary:
	var b := _best_belief(actor)
	if b == null:
		return {}
	var uncertainty := 1.0 - b.confidence
	return {
		E.Goal.AMBITION: clampf(uncertainty * Tuning.DIG_AMBITION_SCALE, 0.0, 1.0),
		E.Goal.SECURITY: clampf(uncertainty * Tuning.DIG_SECURITY_SCALE, 0.0, 1.0),
	}


# Four outcomes (design_doc.md): Resolve (true actor fills in), Corroborate
# (confidence rises, no new field), Collapse (no supporting trace — a bad
# lead), False resolve (a confident, plausible, WRONG answer, weighted the
# same way rumor mutation is).
func execute(world: WorldState, cand: ActionCandidate) -> Event:
	var actor: Character = world.characters[cand.actor_id]
	var b := _best_belief(actor)
	if b == null:
		return null
	var orig: Event = world.events[b.event_id]
	var traces_alive: bool = not (world.traces_by_event.get(b.event_id, []) as Array).is_empty()
	var elapsed := world.turn - orig.turn
	var p_succ := clampf(
		Tuning.DIG_BASE_SUCCESS
		+ (0.3 if traces_alive else -0.3)
		- elapsed * Tuning.DIG_ELAPSED_DECAY
		+ (Tuning.DIG_OBSERVANT_BONUS if actor.has_trait(E.Trait.OBSERVANT) else 0.0)
		- world.heat * Tuning.DIG_HEAT_PENALTY_MULT,
		0.05, 0.95)

	var result := ""
	var suspect_id := -1
	if world.rng.randf() < Tuning.DIG_FALSE_RESOLVE_CHANCE:
		suspect_id = Beliefs.pick_plausible_suspect(world, orig.target_id, [orig.actor_id, actor.id])
		result = "false_resolve" if suspect_id != -1 else "collapse"
	elif world.rng.randf() < p_succ:
		result = "resolve" if traces_alive else "corroborate"
	else:
		result = "collapse"

	match result:
		"resolve":
			b.claim[E.Field.ACTOR] = orig.actor_id
			b.confidence = Tuning.DIG_RESOLVE_CONFIDENCE
			b.hops = 0
			b.source_id = -1
		"corroborate":
			b.confidence = clampf(b.confidence + Tuning.DIG_CORROBORATE_BUMP, 0.0, 1.0)
		"false_resolve":
			b.claim[E.Field.ACTOR] = suspect_id
			b.confidence = Tuning.DIG_FALSE_RESOLVE_CONFIDENCE
			b.hops = 0
			b.source_id = -1
		"collapse":
			b.confidence = Tuning.DIG_COLLAPSE_CONFIDENCE
			if b.source_id != -1 and world.characters.has(b.source_id):
				var teller: Character = world.characters[b.source_id]
				teller.credibility = clampf(teller.credibility - Tuning.DIG_COLLAPSE_CREDIBILITY_HIT, 0.0, 1.0)
	b.turn_acquired = world.turn

	var e := Event.new()
	e.turn = world.turn
	e.actor_id = actor.id
	e.action = id
	e.target_id = orig.target_id
	e.visibility = E.Visibility.OPEN
	e.outcome = {"dug_event_id": b.event_id, "result": result}
	world.add_event(e)
	return e


# Most dig-worthy: a grounded, non-fabricated belief missing ACTOR, or
# holding one below DIG_UNCERTAIN_CONF_THRESHOLD. Ties broken toward lower
# confidence first (the least-resolved case), then event_id.
static func _best_belief(actor: Character) -> Belief:
	var best: Belief = null
	var keys := actor.beliefs.keys()
	keys.sort()
	for bk in keys:
		var b: Belief = actor.beliefs[bk]
		if b.event_id < 0 or b.fabricated:
			continue
		if b.claim.has(E.Field.ACTOR) and b.confidence >= Tuning.DIG_UNCERTAIN_CONF_THRESHOLD:
			continue
		if best == null or b.confidence < best.confidence:
			best = b
	return best
