extends SceneTree
# Phase 5 exit test (doc 5): plan mechanics measurably shape behavior —
# mean_plan_length_at_execution > 1.8, plan_completion_rate in [0.25, 0.6],
# and the chronicle shows at least one legible multi-turn plot (a "begins
# plotting" line followed later by the matching execution line).

const SEEDS := 20
const TURNS := 100

var _failures: Array[String] = []
var _checks := 0
var _plot_re := RegEx.new()
var _exec_re := RegEx.new()


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(msg)


func _initialize() -> void:
	_plot_re.compile("^\\s*(\\S+) begins plotting: (\\S+) -> (\\S+)")
	_exec_re.compile("^\\s*(\\S+) (\\S+) (\\S+)\\s+\\(")

	var agg_completion := 0.0
	var length_num := 0.0
	var length_den := 0
	var seeds_with_plot := 0

	for s in range(1, SEEDS + 1):
		var ws := WorldGen.bootstrap(s)
		var chron := Chronicle.new()
		var metrics := Metrics.new()
		for t in TURNS:
			Turn.run(ws, chron, metrics)
		var m := metrics.finalize(ws)

		_check(int(m["plans_completed"]) + int(m["plans_aborted"]) > 0,
			"seed %d: no plans ever formed or resolved" % s)
		if int(m["plans_completed"]) > 0:
			length_num += float(m["mean_plan_length_at_execution"]) * int(m["plans_completed"])
			length_den += int(m["plans_completed"])
		agg_completion += float(m["plan_completion_rate"])

		if _has_legible_plot(chron.lines):
			seeds_with_plot += 1
		else:
			print("  note: seed %d has no legible multi-turn plot in the chronicle" % s)

	# Weighted by plans_completed per seed, not a flat mean-of-means — a seed
	# with one completion shouldn't count as much as one with fifty.
	var mean_length := length_num / maxf(1.0, float(length_den))
	var mean_completion := agg_completion / SEEDS
	print("aggregate: mean_plan_length_at_execution %.2f (n=%d completions) · plan_completion_rate %.2f · legible plots in %d/%d seeds" % [
		mean_length, length_den, mean_completion, seeds_with_plot, SEEDS])

	_check(mean_length > 1.8, "mean_plan_length_at_execution %.2f <= 1.8" % mean_length)
	_check(mean_completion >= 0.25 and mean_completion <= 0.6,
		"plan_completion_rate %.2f outside [0.25, 0.6]" % mean_completion)
	_check(seeds_with_plot >= int(SEEDS * 0.5),
		"legible multi-turn plot found in only %d/%d seeds (want >= half)" % [seeds_with_plot, SEEDS])

	if _failures.is_empty():
		print("PHASE 5 TESTS: PASS (%d checks)" % _checks)
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		printerr("PHASE 5 TESTS: %d/%d checks failed" % [_failures.size(), _checks])
		quit(1)


# True iff some "ACTOR begins plotting: ACTION -> TARGET" line is followed,
# anywhere later in the same chronicle, by an "ACTOR ACTION TARGET (...)"
# execution line for the same triple — the plan visibly forming and landing.
func _has_legible_plot(lines: PackedStringArray) -> bool:
	var open_plots := {}
	for line: String in lines:
		var pm := _plot_re.search(line)
		if pm:
			open_plots["%s|%s|%s" % [pm.get_string(1), pm.get_string(2), pm.get_string(3)]] = true
			continue
		var em := _exec_re.search(line)
		if em:
			var key := "%s|%s|%s" % [em.get_string(1), em.get_string(2), em.get_string(3)]
			if open_plots.get(key, false):
				return true
	return false
