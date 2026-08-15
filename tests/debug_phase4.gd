extends SceneTree
# Diagnostic: why does a superior with vengeance[crew] = 0.9 never pick
# assign_job against that crew member? Not part of any exit test.

func _initialize() -> void:
	var ws := WorldGen.bootstrap(1)
	var ids := ws.characters.keys()
	ids.sort()
	var assigner := -1
	var grudge_target := -1
	for cid in ids:
		var c: Character = ws.characters[cid]
		if c.state == E.CharState.ACTIVE and c.crew_ids.size() >= 2:
			assigner = cid
			grudge_target = c.crew_ids[0]
			break
	print("assigner=%d (%s) rank=%d crew=%s" % [assigner, (ws.characters[assigner] as Character).name,
		(ws.characters[assigner] as Character).rank, str((ws.characters[assigner] as Character).crew_ids)])
	print("grudge_target=%d (%s) rank=%d" % [grudge_target, (ws.characters[grudge_target] as Character).name,
		(ws.characters[grudge_target] as Character).rank])

	(ws.characters[assigner] as Character).vengeance[grudge_target] = 0.9

	# Run a few turns to get jobs on the board, printing candidates each time
	# for the assigner right before selection.
	var chron := Chronicle.new()
	var metrics := Metrics.new()
	for t in 5:
		ws.turn += 1
		metrics.begin_turn(ws)
		Heat.decay(ws)
		Traces.decay_all(ws)
		Job.generate_board(ws, chron, metrics)
		metrics.board_sample(Job.open_unassigned(ws).size())

		var c: Character = ws.characters[assigner]
		ws.clear_events_read()
		c.attention = Attention.build(ws, c)
		print("--- turn %d --- attention=%s open_jobs=%d" % [ws.turn, str(c.attention), Job.open_unassigned(ws).size()])
		var cands := Candidates.generate(ws, c)
		Scorer.score_all(ws, c, cands)
		ws.assert_ai_clean()
		var by_action := {}
		for cand: ActionCandidate in cands:
			var key := "%s->%d" % [cand.action, cand.target_id]
			by_action[key] = cand.score
		var keys := by_action.keys()
		keys.sort_custom(func(a, b): return by_action[a] > by_action[b])
		for k in keys.slice(0, 8):
			print("   %s score=%.3f" % [k, by_action[k]])

		# Now actually run the full turn for real.
		ws.turn -= 1  # undo the manual increment; let Turn.run do it properly
		Turn.run(ws, chron, metrics)
		(ws.characters[assigner] as Character).vengeance[grudge_target] = 0.9
	quit(0)
