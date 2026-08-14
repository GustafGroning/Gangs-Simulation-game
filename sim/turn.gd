class_name Turn
extends RefCounted
# The 12-step turn resolution order (gangs-gdd.md, Game flow). Steps not yet
# built are stubbed AND MARKED (Judgment/rank changes → phase 6).
#
# Resolution priority within step 4 (from Action.priority):
#   Command → Cover → Earn → Strike → Court → Whisper → Learn


# `injections` are Callables(ws) run after resolution — scripted events for
# tests; exogenous events may reuse the slot.
static func run(ws: WorldState, chron: Chronicle, metrics: Metrics, injections: Array = []) -> void:
	ws.turn += 1
	metrics.begin_turn(ws)
	chron.turn_header(ws)

	# 1. Upkeep — heat decay, trace decay. STUB: recurring costs (post-demo).
	Heat.decay(ws)
	Traces.decay_all(ws)

	# 2. Job board
	Job.generate_board(ws, chron, metrics)
	metrics.board_sample(Job.open_unassigned(ws).size())

	# 3. Action selection — every character simultaneously, via the scorer,
	# against their own belief state. The events-access flag is cleared
	# before and asserted clean after EVERY selection: the AI must never
	# touch ground truth.
	var intents := []
	var ids := ws.characters.keys()
	ids.sort()
	for cid in ids:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE:
			continue
		ws.clear_events_read()
		c.attention = Attention.build(ws, c)
		var cands := Candidates.generate(ws, c)
		Scorer.score_all(ws, c, cands)
		var pick := Selection.choose(ws, c, cands)
		ws.assert_ai_clean()
		if pick != null:
			intents.append(pick)

	# 4. Resolution in priority order. Ties are broken by a pre-drawn random
	# key (sort_custom is not stable) so no actor id has a structural edge.
	var tiebreak := {}
	for cand: ActionCandidate in intents:
		tiebreak[cand] = ws.rng.randf()
	intents.sort_custom(func(a: ActionCandidate, b: ActionCandidate):
		var pa: int = ActionRegistry.get_action(a.action).priority
		var pb: int = ActionRegistry.get_action(b.action).priority
		if pa != pb:
			return pa < pb
		if tiebreak[a] != tiebreak[b]:
			return tiebreak[a] < tiebreak[b]
		return a.actor_id < b.actor_id)

	var heat_before := ws.heat
	var contrib_notes := {}
	for cand: ActionCandidate in intents:
		var action := ActionRegistry.get_action(cand.action)
		var actor: Character = ws.characters[cand.actor_id]
		var target: Character = ws.characters.get(cand.target_id) if cand.target_id != -1 else null
		# Directed assignment pre-empts self-selection: whoever was given a
		# job this turn forfeits their own chosen action (doc 3 §1).
		if Job.assigned_open_job(ws, actor.id) != null:
			continue
		# Invariant I3: requires() is re-checked at execution; a stale
		# candidate fizzles into idleness rather than executing illegally.
		if not action.requires(ws, actor, target):
			continue
		var ev := action.execute(ws, cand)
		actor.last_action = cand.action
		actor.last_target = cand.target_id
		if ev != null:
			metrics.mark_acted(actor.id)
			metrics.action_chosen(ev.action)
			var tname: String = target.name if target != null else ""
			chron.line("%s %s %s  (%s)" % [actor.name, ev.action, tname, Scorer.top_terms(cand)])
		else:
			contrib_notes[actor.id] = Scorer.top_terms(cand)

	# Jobs that found a worker this turn resolve now, in job-id order.
	var to_resolve := []
	for j: Job in ws.jobs:
		if not j.resolved and j.assigned_to_id != -1:
			to_resolve.append(j)
	to_resolve.sort_custom(func(a: Job, b: Job): return a.id < b.id)
	for j: Job in to_resolve:
		metrics.mark_acted(j.assigned_to_id)
		var ev := Job.resolve(ws, j, chron, metrics, contrib_notes.get(j.assigned_to_id, ""))
		metrics.action_chosen(ev.action)
	if ws.heat > heat_before:
		metrics.heat_added(ws)

	for inj in injections:
		(inj as Callable).call(ws)

	# 5. Trace emission — from templates, by the loop, never by actions.
	Traces.emit_for_turn(ws)
	# 6. Detection.
	Traces.detection(ws, chron)
	# 7. Transmission — one hop per turn, with decay and actor mutation.
	Beliefs.transmission(ws, chron)
	# 8. Upward reporting — recipient selection, budgets, fidelity.
	Beliefs.upward_reporting(ws, metrics, chron)
	# 9. Judgment — STUB until phase 6.
	# 10. Rank changes — STUB until phase 6.
	# 11. Goal update — weight dynamics and decay toward baseline.
	Weights.update(ws)

	# 12. Report. Expiry runs here so a job can still be worked on its
	# expiry turn; then the turn's numbers are sampled.
	Job.expire_open(ws, chron, metrics)
	metrics.sample_turn(ws)
	World.assert_invariants(ws)
