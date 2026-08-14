extends SceneTree
# Phase 3 exit test (doc 5) — the real gate on the project. With random job
# assignment and one scripted anonymous sabotage per 10 turns, over 20 seeds:
#  - beliefs about the sabotages exist and are unevenly distributed
#  - misattribution_rate > 0.15
#  - >= 3 confident falsehoods per 100 turns
#  - no belief without a backing event or `fabricated` (invariant, every turn)
#  - a disloyal subordinate's report demonstrably reaches a rival
# Statistical bands hold per doc 4 §7 (>80% of runs; held at 90% here);
# structural checks hold in all runs.

const SEEDS := 20
const TURNS := 100

var _failures: Array[String] = []
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(msg)


func _initialize() -> void:
	var agg_misattr := 0.0
	var agg_falsehoods := 0.0
	var agg_accuracy := 0.0
	var misattr_low_seeds := 0
	var falsehood_low_seeds := 0
	var disloyal_total := 0

	for s in range(1, SEEDS + 1):
		var ws := WorldGen.bootstrap(s)
		var chron := Chronicle.new()
		var metrics := Metrics.new()
		var saboteur_events: Array[int] = []
		var inject := func(w: WorldState) -> void:
			if w.turn % 10 != 0:
				return
			var pair := _pick_sabotage_pair(w)
			if pair.is_empty():
				return
			var e := Event.new()
			e.turn = w.turn
			e.actor_id = pair[0]
			e.action = &"sabotage_job"
			e.target_id = pair[1]
			e.visibility = E.Visibility.ANONYMOUS
			w.add_event(e)
			saboteur_events.append(e.id)
			chron.line("† truth: %s sabotages %s (anonymous, scripted)" % [
				(w.characters[pair[0]] as Character).name, (w.characters[pair[1]] as Character).name])
		for t in TURNS:
			Turn.run(ws, chron, metrics, [inject])
		var m := metrics.finalize(ws)

		# Beliefs about sabotages exist, and are unevenly distributed.
		var holders_per_event: Array[int] = []
		var per_char_counts := {}
		for eid in saboteur_events:
			var holders := 0
			for cid: int in ws.characters:
				if cid == (ws.events[eid] as Event).actor_id:
					continue
				if (ws.characters[cid] as Character).beliefs.has(eid):
					holders += 1
					per_char_counts[cid] = int(per_char_counts.get(cid, 0)) + 1
			holders_per_event.append(holders)
		var total_holders := 0
		for h in holders_per_event:
			total_holders += h
		_check(total_holders > 0, "seed %d: no beliefs about any sabotage" % s)
		var counts := per_char_counts.values()
		counts.sort()
		var some_without := per_char_counts.size() < ws.characters.size()
		var uneven: bool = some_without or (not counts.is_empty() and counts[0] != counts[counts.size() - 1])
		_check(uneven, "seed %d: sabotage beliefs perfectly evenly distributed" % s)

		if m["misattribution_rate"] <= 0.15:
			misattr_low_seeds += 1
			print("  note: seed %d misattribution_rate %.2f" % [s, m["misattribution_rate"]])
		if m["confident_falsehoods"] < 3:
			falsehood_low_seeds += 1
			print("  note: seed %d confident_falsehoods %d" % [s, m["confident_falsehoods"]])
		agg_misattr += m["misattribution_rate"]
		agg_falsehoods += m["confident_falsehoods"]
		agg_accuracy += m["mean_belief_accuracy"]
		disloyal_total += m["disloyal_rival_reports"]

	print("aggregate: misattr %.2f · falsehoods %.1f/run · accuracy %.2f · disloyal-rival reports %d" % [
		agg_misattr / SEEDS, agg_falsehoods / SEEDS, agg_accuracy / SEEDS, disloyal_total])

	_check(misattr_low_seeds <= SEEDS / 10, "misattribution_rate <= 0.15 in %d/%d seeds" % [misattr_low_seeds, SEEDS])
	_check(falsehood_low_seeds <= SEEDS / 10, "confident_falsehoods < 3 in %d/%d seeds" % [falsehood_low_seeds, SEEDS])
	_check(agg_misattr / SEEDS > 0.15, "aggregate misattribution_rate %.2f <= 0.15" % (agg_misattr / SEEDS))
	# mean_belief_accuracy has no phase-3 gate (doc 5): its doc-4 band is a
	# full-demo target evaluated at phases 6-7, once Dig can correct beliefs.
	# It is printed above for the record.
	# A disloyal subordinate's report demonstrably reached a rival.
	_check(disloyal_total > 0, "no disloyal subordinate ever reported to a rival")

	if _failures.is_empty():
		print("PHASE 3 TESTS: PASS (%d checks)" % _checks)
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		printerr("PHASE 3 TESTS: %d/%d checks failed" % [_failures.size(), _checks])
		quit(1)


# Saboteur: someone with a sibling they dislike; victim: that sibling.
func _pick_sabotage_pair(ws: WorldState) -> Array:
	var candidates := []
	var ids := ws.characters.keys()
	ids.sort()
	for cid in ids:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE or c.patron_id == -1:
			continue
		for sib in World.crew_of(ws, c.patron_id):
			if sib != cid and World.opinion_of(ws, cid, sib) < 0.0:
				candidates.append([cid, sib])
	if candidates.is_empty():
		return []
	return Rng.pick(candidates, ws.rng)
