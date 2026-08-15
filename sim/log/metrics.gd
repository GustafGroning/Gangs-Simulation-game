class_name Metrics
extends RefCounted
# doc 4 §2. Phase 2 scope: economy metrics + the counters the content smoke
# test needs. Story metrics land with the info layer and scorer (phases 3-4).

# Job economy counters
var jobs_posted := 0
var jobs_expired := 0                # expired unassigned
var outcome_counts := {
	E.JobOutcome.SUCCESS: 0, E.JobOutcome.PARTIAL: 0,
	E.JobOutcome.FAILURE: 0, E.JobOutcome.DISASTER: 0,
}

# Per-turn samples
var heat_sum := 0.0
var turns_sampled := 0
var board_empty_streak := 0
var board_empty_streak_max := 0
var board_size_max := 0
var runaway_ratio_max := 0.0

# Heat recovery (doc 3 §6 item 5): heat must fall below 0.2 within 10 turns
# of the last heat-adding event.
var _last_heat_add_turn := -1000
var heat_recovery_violations := 0
var _heat_add_pending := false

# Idle tracking (doc 4: inert_characters — nobody doing nothing 20+ turns)
var _idle_streak := {}               # char_id -> current consecutive idle turns
var _idle_streak_max := {}           # char_id -> worst streak seen
var _acted_this_turn := {}           # char_id -> bool

# Action distribution (phase 4): executed actions per turn; the idle
# remainder is filled in at sample_turn.
var action_counts := {}

# Plan tracking (phase 5). `length` is turns-alive at resolution (1 minimum —
# a plan can't complete the same turn it's created, since it's only formed
# while its step is gated); mean_plan_length_at_execution is over completed
# plans only, matching "at execution" — an abandoned plan never executed.
var plans_completed := 0
var plans_aborted := 0
var plan_length_sum := 0
var escalations := 0

# Phase 6 counters (doc 4 §2 health/story metrics).
var deaths := 0
var arrests := 0
var jobs_abandoned := 0             # worker died/was removed before their job resolved
var rank_changes := 0
var judgments := {
	E.Verdict.DISMISSED: 0, E.Verdict.DEMOTED: 0, E.Verdict.EXILED: 0, E.Verdict.KILLED: 0,
}
var _actions_per_char := {}         # char_id -> non-idle actions taken, whole run
var _feud_streak := {}              # pair_key -> consecutive turns both vengeance > 0.4
var _feud_pairs_hit := {}           # pair_key -> true once streak reached 10 (doc 4 §2 "feuds")


func plan_resolved(completed: bool, length: int) -> void:
	if completed:
		plans_completed += 1
		plan_length_sum += length
	else:
		plans_aborted += 1


func escalation() -> void:
	escalations += 1


func death() -> void:
	deaths += 1


func arrest() -> void:
	arrests += 1


func job_abandoned() -> void:
	jobs_abandoned += 1


func rank_change() -> void:
	rank_changes += 1


func judgment_rendered(verdict: int) -> void:
	judgments[verdict] = int(judgments.get(verdict, 0)) + 1


# char_id is the actor who took this (non-idle) action, for
# actions_per_char_variance (doc 4 §2). -1 (default) skips that bookkeeping —
# used by the few call sites with no single responsible actor.
func action_chosen(action: StringName, char_id: int = -1) -> void:
	action_counts[action] = int(action_counts.get(action, 0)) + 1
	if char_id != -1:
		_actions_per_char[char_id] = int(_actions_per_char.get(char_id, 0)) + 1


func action_entropy() -> float:
	var total := 0
	for a in action_counts:
		total += int(action_counts[a])
	if total == 0:
		return 0.0
	var h := 0.0
	for a in action_counts:
		var p := float(action_counts[a]) / total
		if p > 0.0:
			h -= p * log(p) / log(2.0)
	return h


# Upward-reporting tracking (phase 3): who reported to whom.
var reports_to_patron := 0
var reports_to_rival := 0
var disloyal_rival_reports := 0      # sender disliked their patron AND told a rival


func report_delivered(_sender: int, _recipient: int, is_patron: bool, sender_opinion_of_patron: float) -> void:
	if is_patron:
		reports_to_patron += 1
	else:
		reports_to_rival += 1
		if sender_opinion_of_patron < -0.1:
			disloyal_rival_reports += 1


func begin_turn(ws: WorldState) -> void:
	_acted_this_turn = {}
	_heat_add_pending = false
	for cid: int in ws.characters:
		if (ws.characters[cid] as Character).state == E.CharState.ACTIVE:
			_acted_this_turn[cid] = false


func mark_acted(char_id: int) -> void:
	_acted_this_turn[char_id] = true


func heat_added(ws: WorldState) -> void:
	_heat_add_pending = true


func job_posted() -> void:
	jobs_posted += 1


# Board availability is measured AFTER posting, at selection time — with
# demand far above JOBS_PER_TURN the board is legitimately swept clean by
# the end of every turn, so an end-of-turn sample would only measure surplus.
func board_sample(open_count: int) -> void:
	board_size_max = maxi(board_size_max, open_count)
	if open_count == 0:
		board_empty_streak += 1
		board_empty_streak_max = maxi(board_empty_streak_max, board_empty_streak)
	else:
		board_empty_streak = 0


func idle_streak(char_id: int) -> int:
	return int(_idle_streak.get(char_id, 0))


func job_expired() -> void:
	jobs_expired += 1


func job_outcome(outcome: int) -> void:
	outcome_counts[outcome] += 1


func sample_turn(ws: WorldState) -> void:
	turns_sampled += 1
	heat_sum += ws.heat
	if _heat_add_pending:
		_last_heat_add_turn = ws.turn
	elif ws.turn - _last_heat_add_turn >= 10 and ws.heat >= 0.2:
		heat_recovery_violations += 1

	for cid in _acted_this_turn:
		if _acted_this_turn[cid]:
			_idle_streak[cid] = 0
		else:
			_idle_streak[cid] = int(_idle_streak.get(cid, 0)) + 1
			_idle_streak_max[cid] = maxi(int(_idle_streak_max.get(cid, 0)), int(_idle_streak[cid]))
			action_counts[&"idle"] = int(action_counts.get(&"idle", 0)) + 1

	var standings := _active_standings(ws)
	var med := _median(standings)
	if med > 0.0:
		for s in standings:
			runaway_ratio_max = maxf(runaway_ratio_max, s / med)

	_sample_feuds(ws)


# "Pairs with sustained mutual vengeance > 0.4 for 10+ turns" (doc 4 §2).
func _sample_feuds(ws: WorldState) -> void:
	var ids := ws.characters.keys()
	ids.sort()
	for i in ids.size():
		var a: int = ids[i]
		var ca: Character = ws.characters[a]
		if ca.state != E.CharState.ACTIVE:
			continue
		for j in range(i + 1, ids.size()):
			var b: int = ids[j]
			var cb: Character = ws.characters[b]
			if cb.state != E.CharState.ACTIVE:
				continue
			var key := World.pair_key(a, b)
			var mutual: bool = float(ca.vengeance.get(b, 0.0)) > 0.4 and float(cb.vengeance.get(a, 0.0)) > 0.4
			if mutual:
				_feud_streak[key] = int(_feud_streak.get(key, 0)) + 1
				if int(_feud_streak[key]) >= 10:
					_feud_pairs_hit[key] = true
			else:
				_feud_streak[key] = 0


func _active_standings(ws: WorldState) -> Array[float]:
	var out: Array[float] = []
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.state == E.CharState.ACTIVE:
			out.append(c.standing)
	return out


static func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var v := values.duplicate()
	v.sort()
	var n := v.size()
	return v[n / 2] if n % 2 == 1 else (v[n / 2 - 1] + v[n / 2]) * 0.5


static func _end_ratio(standings: Array[float]) -> float:
	var med := _median(standings)
	if med <= 0.0:
		return 999.0
	var top := 0.0
	for s in standings:
		top = maxf(top, s)
	return top / med


static func gini(values: Array[float]) -> float:
	var v := values.duplicate()
	v.sort()
	var n := v.size()
	if n == 0:
		return 0.0
	var total := 0.0
	for x in v:
		total += x
	if total <= 0.0:
		return 0.0
	var acc := 0.0
	for i in n:
		acc += (2.0 * (i + 1) - n - 1) * v[i]
	return acc / (n * total)


func inert_characters() -> int:
	var count := 0
	for cid in _idle_streak_max:
		if int(_idle_streak_max[cid]) >= Tuning.INERT_TURNS:
			count += 1
	return count


func finalize(ws: WorldState) -> Dictionary:
	var standings := _active_standings(ws)
	var resolved := 0
	for o in outcome_counts:
		resolved += int(outcome_counts[o])
	var closed := resolved + jobs_expired
	var open_now := 0
	var leaked := 0
	for j: Job in ws.jobs:
		if not j.resolved:
			if ws.turn > j.expires_turn:
				leaked += 1
			else:
				open_now += 1
	var outcome_fractions := {}
	var outcome_names := {
		E.JobOutcome.SUCCESS: "success", E.JobOutcome.PARTIAL: "partial",
		E.JobOutcome.FAILURE: "failure", E.JobOutcome.DISASTER: "disaster",
	}
	for o in outcome_counts:
		outcome_fractions[outcome_names[o]] = float(outcome_counts[o]) / maxf(1.0, float(resolved))
	return {
		"turns": turns_sampled,
		"jobs_posted": jobs_posted,
		"jobs_resolved": resolved,
		"jobs_expired_unassigned": jobs_expired,
		"jobs_open_at_end": open_now,
		"jobs_leaked": leaked,
		"job_fill_rate": float(resolved) / maxf(1.0, float(closed)),
		"outcome_fractions": outcome_fractions,
		"mean_heat": heat_sum / maxf(1.0, float(turns_sampled)),
		"heat_recovery_violations": heat_recovery_violations,
		"board_empty_streak_max": board_empty_streak_max,
		"board_size_max": board_size_max,
		"standing_gini": gini(standings),
		# doc 4 §2: metrics are computed from the end-state — runaway is an
		# end-of-run property. The worst transient ratio stays as a diagnostic.
		"standing_runaway": _end_ratio(standings) > Tuning.RUNAWAY_STANDING_RATIO,
		"end_standing_ratio": _end_ratio(standings),
		"runaway_ratio_max_transient": runaway_ratio_max,
		"inert_characters": inert_characters(),
		"reports_to_patron": reports_to_patron,
		"reports_to_rival": reports_to_rival,
		"disloyal_rival_reports": disloyal_rival_reports,
		"action_entropy": action_entropy(),
		"action_counts": _action_counts_readable(),
		"plans_completed": plans_completed,
		"plans_aborted": plans_aborted,
		"plan_completion_rate": float(plans_completed) / maxf(1.0, float(plans_completed + plans_aborted)),
		"mean_plan_length_at_execution": float(plan_length_sum) / maxf(1.0, float(plans_completed)),
		"escalation_events": escalations,
		"deaths_per_100_turns": float(deaths) * 100.0 / maxf(1.0, float(turns_sampled)),
		"arrests": arrests,
		"jobs_abandoned": jobs_abandoned,
		"rank_changes_per_100_turns": float(rank_changes) * 100.0 / maxf(1.0, float(turns_sampled)),
		"judgments_per_100_turns": float(_judgments_total()) * 100.0 / maxf(1.0, float(turns_sampled)),
		"dismissed_verdict_fraction": float(judgments.get(E.Verdict.DISMISSED, 0)) / maxf(1.0, float(_judgments_total())),
		"feuds": _feud_pairs_hit.size(),
		"unique_actions_used": _unique_actions_used(),
		"actions_per_char_variance": _variance(_actions_per_char_values(ws)),
		# Lie Low is not one of the demo's 7 verbs — always 0, trivially in-band.
		"lie_low_fraction": 0.0,
	}.merged(info_metrics(ws))


func _judgments_total() -> int:
	var total := 0
	for v in judgments:
		total += int(judgments[v])
	return total


func _unique_actions_used() -> float:
	var enabled := 0
	for a: Action in ActionRegistry.all_actions():
		if a.id != &"idle":
			enabled += 1
	var used := 0
	for a in action_counts:
		if a != &"idle" and int(action_counts[a]) > 0:
			used += 1
	return float(used) / maxf(1.0, float(enabled))


func _actions_per_char_values(ws: WorldState) -> Array:
	var values := []
	for cid: int in ws.characters:
		values.append(float(_actions_per_char.get(cid, 0)))
	return values


static func _variance(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var mean := 0.0
	for v in values:
		mean += float(v)
	mean /= values.size()
	var acc := 0.0
	for v in values:
		acc += (float(v) - mean) * (float(v) - mean)
	return acc / values.size()


func _action_counts_readable() -> Dictionary:
	var out := {}
	for a in action_counts:
		out[String(a)] = action_counts[a]
	return out


# ---- Story metrics (doc 4 §2) — computed from the ledger and end-state ----

static func info_metrics(ws: WorldState) -> Dictionary:
	var hostile_events: Array[int] = []
	for e: Event in ws.events:
		if e.action in Beliefs.HOSTILE_ACTIONS:
			hostile_events.append(e.id)

	# Plurality actor claim per hostile event.
	var misattributed := 0
	for eid in hostile_events:
		var votes := {}
		for cid: int in ws.characters:
			var b: Belief = (ws.characters[cid] as Character).beliefs.get(eid)
			if b == null or not b.claim.has(E.Field.ACTOR) or cid == (ws.events[eid] as Event).actor_id:
				continue
			var a := int(b.claim[E.Field.ACTOR])
			votes[a] = int(votes.get(a, 0)) + 1
		var best := -1
		var best_count := 0
		var tied := false
		for a in votes:
			if votes[a] > best_count:
				best = a
				best_count = votes[a]
				tied = false
			elif votes[a] == best_count:
				tied = true
		if best != -1 and not tied and best != (ws.events[eid] as Event).actor_id:
			misattributed += 1

	# Confident falsehoods + actor-claim accuracy, across all grounded beliefs.
	var confident_falsehoods := 0
	var actor_claims := 0
	var actor_claims_correct := 0
	var hostile_claims := 0
	var hostile_claims_correct := 0
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		for bk in c.beliefs:
			var b: Belief = c.beliefs[bk]
			if b.event_id < 0 or not b.claim.has(E.Field.ACTOR):
				continue
			var e: Event = ws.events[b.event_id]
			var correct := int(b.claim[E.Field.ACTOR]) == e.actor_id
			actor_claims += 1
			if correct:
				actor_claims_correct += 1
			elif b.confidence > 0.6:
				confident_falsehoods += 1
			if e.action in Beliefs.HOSTILE_ACTIONS and cid != e.actor_id:
				hostile_claims += 1
				if correct:
					hostile_claims_correct += 1

	return {
		"hostile_events": hostile_events.size(),
		"misattribution_rate": float(misattributed) / maxf(1.0, float(hostile_events.size())),
		"confident_falsehoods": confident_falsehoods,
		# Over ALL actor claims, mundane open events included — mostly
		# truthful eyewitness beliefs, so this runs high by construction.
		"mean_belief_accuracy": float(actor_claims_correct) / maxf(1.0, float(actor_claims)),
		# Over hostile events only — where the information game actually is.
		"hostile_belief_accuracy": float(hostile_claims_correct) / maxf(1.0, float(hostile_claims)),
		"actor_claims": actor_claims,
	}


func save(path: String, ws: WorldState) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Metrics.save: cannot open %s" % path)
		return false
	f.store_string(JSON.stringify(finalize(ws), "\t", true, true) + "\n")
	f.close()
	return true
