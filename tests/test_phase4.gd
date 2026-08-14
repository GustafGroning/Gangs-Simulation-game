extends SceneTree
# Phase 4 exit test (doc 5): with only TakeJob and AssignJob, characters
# differentiate — action_entropy > 1.0, assignment choices correlate with
# vengeance, and assert_ai_clean() never fires (any violation crashes the
# run via the per-selection assertion in the turn loop).

const SEEDS := 20
const TURNS := 100

var _failures: Array[String] = []
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(msg)


func _initialize() -> void:
	var entropy_low_seeds := 0
	var agg_entropy := 0.0
	var vengeful_p := []      # success estimates of assignments to grudge targets
	var neutral_p := []       # ... to everyone else
	var vengeful_hits := 0    # assignments that went to the planted target
	var vengeful_chances := 0 # assignments by a vengeful superior (any target)

	for s in range(1, SEEDS + 1):
		var ws := WorldGen.bootstrap(s)
		var chron := Chronicle.new()
		var metrics := Metrics.new()

		# Plant grudges: three superiors with >=2 crew hate one crew member.
		var planted := {}  # assigner_id -> target_id
		var ids := ws.characters.keys()
		ids.sort()
		for cid in ids:
			if planted.size() >= 3:
				break
			var c: Character = ws.characters[cid]
			if c.state == E.CharState.ACTIVE and c.crew_ids.size() >= 2:
				planted[cid] = c.crew_ids[0]

		var events_seen := {}
		var scan := func(w: WorldState) -> void:
			# Keep the planted grudges alive against decay.
			for a in planted:
				(w.characters[a] as Character).vengeance[planted[a]] = 0.9
			# Scan this turn's assignments.
			for e: Event in w.events:
				if events_seen.has(e.id) or e.action != &"assign_job":
					events_seen[e.id] = true
					continue
				events_seen[e.id] = true
				var jid := int(e.outcome["job_id"])
				var j: Job = null
				for cand: Job in w.jobs:
					if cand.id == jid:
						j = cand
						break
				if j == null:
					continue
				var p := Job.success_estimate(w.characters[e.target_id], j)
				if planted.has(e.actor_id):
					vengeful_chances += 1
					if planted[e.actor_id] == e.target_id:
						vengeful_hits += 1
						vengeful_p.append(p)
					else:
						neutral_p.append(p)
				else:
					neutral_p.append(p)

		scan.call(ws)  # plant before turn 1
		for t in TURNS:
			Turn.run(ws, chron, metrics, [scan])
		var m := metrics.finalize(ws)

		agg_entropy += m["action_entropy"]
		if m["action_entropy"] <= 1.0:
			entropy_low_seeds += 1
			print("  note: seed %d action_entropy %.2f (%s)" % [s, m["action_entropy"], str(m["action_counts"])])
		_check(m["job_fill_rate"] > 0.7, "seed %d: fill rate collapsed to %.2f under the scorer" % [s, m["job_fill_rate"]])
		_check(m["inert_characters"] <= 1, "seed %d: %d inert characters under the scorer" % [s, m["inert_characters"]])

	var mean_vengeful := _mean(vengeful_p)
	var mean_neutral := _mean(neutral_p)
	var hit_rate := float(vengeful_hits) / maxf(1.0, float(vengeful_chances))
	print("aggregate: entropy %.2f · vengeful assignments p_succ %.2f vs neutral %.2f · grudge-target hit rate %.2f (%d/%d)" % [
		agg_entropy / SEEDS, mean_vengeful, mean_neutral, hit_rate, vengeful_hits, vengeful_chances])

	_check(entropy_low_seeds <= SEEDS / 10, "action_entropy <= 1.0 in %d/%d seeds" % [entropy_low_seeds, SEEDS])
	_check(agg_entropy / SEEDS > 1.0, "aggregate action_entropy %.2f <= 1.0" % (agg_entropy / SEEDS))
	# Correlation with vengeance, two ways: grudge targets get chosen
	# disproportionately (>= their crew share ~50%), and they get worse jobs.
	_check(vengeful_chances > 0, "vengeful superiors never assigned at all")
	_check(hit_rate > 0.5, "grudge targets got only %.2f of their superiors' assignments" % hit_rate)
	_check(mean_vengeful < mean_neutral - 0.02,
		"assignments to grudge targets not harder (p %.2f vs %.2f)" % [mean_vengeful, mean_neutral])

	if _failures.is_empty():
		print("PHASE 4 TESTS: PASS (%d checks)" % _checks)
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		printerr("PHASE 4 TESTS: %d/%d checks failed" % [_failures.size(), _checks])
		quit(1)


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()
