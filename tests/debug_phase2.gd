extends SceneTree
# Diagnostic dump for phase 2 tuning — not part of any exit test.

func _initialize() -> void:
	for s in [11, 13, 20]:
		var ws := WorldGen.bootstrap(s)
		var chron := Chronicle.new()
		var metrics := Metrics.new()
		var min_median := 999.0
		for t in 100:
			Turn.run(ws, chron, metrics)
			var st: Array[float] = []
			for cid: int in ws.characters:
				st.append((ws.characters[cid] as Character).standing)
			st.sort()
			var med := (st[7] + st[8]) * 0.5
			min_median = minf(min_median, med)
		var m := metrics.finalize(ws)
		print("=== seed %d: fill %.2f outcomes %s" % [s, m["job_fill_rate"], str(m["outcome_fractions"])])
		print("    min median %.1f · runaway max %.2f · inert %d" % [min_median, m["runaway_ratio_max"], m["inert_characters"]])
		var ids := ws.characters.keys()
		ids.sort()
		for cid in ids:
			var c: Character = ws.characters[cid]
			print("    %2d %-7s r%d st %6.1f comp %.2f idle_max %2d" % [
				cid, c.name, c.rank, c.standing, c.competence,
				int(metrics._idle_streak_max.get(cid, 0))])
	quit(0)
