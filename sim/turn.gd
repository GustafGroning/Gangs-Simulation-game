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

	# 1b. Exogenous events (doc 3 §3). No numbered step in the GDD's 12-step
	# list — placed early so the cast's action selection this turn reacts to
	# a fresh rival hit / arrest rather than a stale one. Judgment call; see
	# DECISIONS.md.
	Exogenous.maybe_fire(ws, chron, metrics)

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
		if c.plan == null:
			Planner.maybe_start(ws, c)
			if c.plan != null:
				chron.line("%s begins plotting: %s -> %s (patience %d)" % [
					c.name, c.plan.goal_action,
					(ws.characters[c.plan.target_id] as Character).name, c.plan.patience])
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
		# Phase 6: the actor may have been killed/exiled by an earlier
		# higher-priority action (or Judgment, or an exogenous event) this
		# same turn — their own queued candidate fizzles just like a stale
		# requires() gate (invariant I3).
		if actor.state != E.CharState.ACTIVE:
			continue
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
			metrics.action_chosen(ev.action, actor.id)
			var tname: String = target.name if target != null else ""
			chron.line("%s %s %s  (%s)" % [actor.name, ev.action, tname, Scorer.top_terms(cand)])
		else:
			contrib_notes[actor.id] = Scorer.top_terms(cand)

	# Starting a job (self-selected or assigned) is real activity even
	# though it resolves next turn — credit the worker now, or the
	# assignment→resolution latency (phase 5) would read as a full idle
	# turn every time a job is taken, artificially inflating idle streaks.
	for j: Job in ws.jobs:
		if j.assigned_turn == ws.turn:
			metrics.mark_acted(j.assigned_to_id)

	# Plan bookkeeping: advance/complete on a match, else tick
	# patience/frustration and abort (or escalate) on exhaustion. Reads
	# actor.last_action/last_target, just set above.
	for cid2 in ids:
		var c2: Character = ws.characters[cid2]
		if c2.state == E.CharState.ACTIVE:
			Planner.tick_after_resolution(ws, c2, metrics)

	# Jobs assigned on an EARLIER turn resolve now, in job-id order. One turn
	# of latency between assignment and resolution (phase 5) — a job spends
	# exactly one turn "in progress" so SabotageJob has a legal window; see
	# Job.assigned_turn's comment and thoughts/phase_5_planner.md.
	var to_resolve := []
	for j: Job in ws.jobs:
		if not j.resolved and j.assigned_to_id != -1 and j.assigned_turn < ws.turn:
			to_resolve.append(j)
	to_resolve.sort_custom(func(a: Job, b: Job): return a.id < b.id)
	for j: Job in to_resolve:
		metrics.mark_acted(j.assigned_to_id)
		var ev := Job.resolve(ws, j, chron, metrics, contrib_notes.get(j.assigned_to_id, ""))
		metrics.action_chosen(ev.action, j.assigned_to_id)
		# Doc 3 §1: "DISASTER on a violent job may trigger an arrest."
		if j.outcome == E.JobOutcome.DISASTER and bool(Tuning.JOB_KINDS[j.kind].get("violent", false)):
			Exogenous.maybe_arrest_from_disaster(ws, j.assigned_to_id, chron, metrics)
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
	# 9. Judgment — any Denounce triggered this turn is adjudicated.
	Judgment.process_all(ws, chron, metrics)
	# 10. Rank changes — vacancies (from Kill, Judgment, arrests, or the
	# initial deliberate vacancy) contested, tree redrawn.
	Contest.run_all(ws, chron, metrics)
	# 11. Goal update — weight dynamics and decay toward baseline.
	Weights.update(ws)

	# 12. Report. Expiry runs here so a job can still be worked on its
	# expiry turn; then the turn's numbers are sampled.
	Job.expire_open(ws, chron, metrics)
	metrics.sample_turn(ws)
	World.assert_invariants(ws)
