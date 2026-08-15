extends SceneTree
# Phase 6 exit test (doc 5): "all doc 4 §7 criteria across 20 seeds x 200
# turns" with the full 7-verb demo set. Doc 4 §7's points 3-4 ("reading
# three chronicles, can you reconstruct why things happened / were you
# surprised") are a human judgment call for Gustaf, not machine-checkable —
# this test covers point 1 (health metrics in band in > 80% of runs, held at
# 90% per DECISIONS.md's existing precedent) and point 2 (misattribution_rate
# > 0.15 in > 80% of runs), plus a few doc 4 §2 economy bands for the record.

const SEEDS := 20
const TURNS := 200

var _failures: Array[String] = []
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(msg)


func _initialize() -> void:
	var low := {}  # metric key -> count of seeds out of band
	var keys := [
		"action_entropy", "unique_actions_used", "actions_per_char_variance",
		"deaths_per_100_turns", "rank_changes_per_100_turns", "misattribution_rate",
		"job_fill_rate", "standing_gini", "mean_heat", "standing_runaway", "inert_characters",
	]
	for k in keys:
		low[k] = 0
	var judgments_total := 0.0

	for s in range(1, SEEDS + 1):
		var ws := WorldGen.bootstrap(s)
		var chron := Chronicle.new()
		var metrics := Metrics.new()
		for t in TURNS:
			Turn.run(ws, chron, metrics)
		var m := metrics.finalize(ws)

		if float(m["action_entropy"]) <= 2.0:
			low["action_entropy"] += 1
		if float(m["unique_actions_used"]) < 0.8:
			low["unique_actions_used"] += 1
		if float(m["actions_per_char_variance"]) <= 0.0:
			low["actions_per_char_variance"] += 1
		if float(m["deaths_per_100_turns"]) < 2.0 or float(m["deaths_per_100_turns"]) > 6.0:
			low["deaths_per_100_turns"] += 1
		if float(m["rank_changes_per_100_turns"]) < 4.0 or float(m["rank_changes_per_100_turns"]) > 12.0:
			low["rank_changes_per_100_turns"] += 1
		if float(m["misattribution_rate"]) <= 0.15:
			low["misattribution_rate"] += 1
		if float(m["job_fill_rate"]) <= 0.8:
			low["job_fill_rate"] += 1
		if float(m["standing_gini"]) < 0.2 or float(m["standing_gini"]) > 0.5:
			low["standing_gini"] += 1
		if float(m["mean_heat"]) < 0.15 or float(m["mean_heat"]) > 0.45:
			low["mean_heat"] += 1
		if bool(m["standing_runaway"]):
			low["standing_runaway"] += 1
		if int(m["inert_characters"]) > 0:
			low["inert_characters"] += 1
		judgments_total += float(m["judgments_per_100_turns"])

		print("  seed %d: entropy %.2f · deaths/100t %.1f · ranks/100t %.1f · misattr %.2f · fill %.2f · judgments/100t %.1f" % [
			s, m["action_entropy"], m["deaths_per_100_turns"], m["rank_changes_per_100_turns"],
			m["misattribution_rate"], m["job_fill_rate"], m["judgments_per_100_turns"]])

	print("aggregate: mean judgments/100t %.2f" % (judgments_total / SEEDS))

	var threshold := int(ceil(SEEDS * 0.1))  # doc 4 §7: >80% in band; held at 90% (DECISIONS.md precedent)
	for k in keys:
		_check(int(low[k]) <= threshold, "%s out of band in %d/%d seeds (want <= %d)" % [k, low[k], SEEDS, threshold])

	if _failures.is_empty():
		print("PHASE 6 TESTS: PASS (%d checks)" % _checks)
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		printerr("PHASE 6 TESTS: %d/%d checks failed" % [_failures.size(), _checks])
		quit(1)
