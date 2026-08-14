extends SceneTree
# Headless entry point. CLI parsing and orchestration only — no sim logic
# lives here. Run via ./gangs, which wraps:
#   godot --headless --script main.gd -- <args>
#
# A run is identified by (seed, config_hash) — both printed in the log header.

const EXIT_OK := 0
const EXIT_USAGE := 2
const EXIT_UNIMPLEMENTED := 3

const VALUE_ARGS: Array[String] = ["--seed", "--turns", "--config", "--out", "--seeds", "--vary"]
const INT_ARGS: Array[String] = ["--seed", "--turns"]


func _initialize() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(argv: PackedStringArray) -> int:
	var opts := {
		"seed": 1,
		"turns": 100,
		"config": "default",
		"out": "runs/",
		"sweep": false,
		"seeds": "",
		"vary": "",
	}

	var i := 0
	while i < argv.size():
		var arg := argv[i]
		if arg == "--sweep":
			opts["sweep"] = true
			i += 1
		elif arg in VALUE_ARGS:
			if i + 1 >= argv.size():
				push_error("missing value for %s" % arg)
				return EXIT_USAGE
			var value := argv[i + 1]
			if arg in INT_ARGS:
				if not value.is_valid_int():
					push_error("%s expects an integer, got '%s'" % [arg, value])
					return EXIT_USAGE
				opts[arg.trim_prefix("--")] = value.to_int()
			else:
				opts[arg.trim_prefix("--")] = value
			i += 2
		else:
			push_error("unknown argument: %s (known: %s, --sweep)" % [arg, ", ".join(VALUE_ARGS)])
			return EXIT_USAGE

	var config_hash := _config_hash()
	print("gangs — seed %d · config %s · config_hash %s · turns %d" % [
		opts["seed"], opts["config"], config_hash, opts["turns"],
	])

	if opts["config"] != "default":
		push_error("only --config default exists yet")
		return EXIT_UNIMPLEMENTED
	if opts["sweep"] or opts["seeds"] != "" or opts["vary"] != "":
		push_error("--sweep / --seeds / --vary: the sweep harness is phase 7")
		return EXIT_UNIMPLEMENTED

	return _single_run(int(opts["seed"]), int(opts["turns"]), str(opts["out"]), config_hash)


func _single_run(p_seed: int, p_turns: int, out_dir: String, config_hash: String) -> int:
	var ws := WorldGen.bootstrap(p_seed)
	var chron := Chronicle.new()
	var metrics := Metrics.new()
	chron.header(ws, config_hash)
	for t in p_turns:
		Turn.run(ws, chron, metrics)
	print("ran %d turns · %d events · heat %.2f" % [ws.turn, ws.events.size(), ws.heat])

	if not out_dir.is_absolute_path():
		out_dir = ProjectSettings.globalize_path("res://").path_join(out_dir)
	var err := DirAccess.make_dir_recursive_absolute(out_dir)
	if err != OK:
		push_error("cannot create output dir %s" % out_dir)
		return 1

	chron.save(out_dir.path_join("chronicle.txt"))
	metrics.save(out_dir.path_join("metrics.json"), ws)
	_save_events_jsonl(ws, out_dir.path_join("events.jsonl"))
	_save_json(ws.to_dict(), out_dir.path_join("final_state.json"))
	_save_world_summary(ws, out_dir.path_join("world_summary.txt"))
	print("outputs written to %s" % out_dir)
	return EXIT_OK


func _save_events_jsonl(ws: WorldState, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot open %s" % path)
		return
	for e: Event in ws.events:
		f.store_line(JSON.stringify(e.to_dict(), "", true, true))
	f.close()


func _save_json(data: Dictionary, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot open %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	f.close()


func _save_world_summary(ws: WorldState, path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot open %s" % path)
		return
	f.store_line("World summary — seed %d, turn %d, heat %.2f" % [ws.seed, ws.turn, ws.heat])
	var ids := ws.characters.keys()
	ids.sort()
	var trait_names := E.Trait.keys()
	var goal_names := E.Goal.keys()
	for cid in ids:
		var c: Character = ws.characters[cid]
		var traits := []
		for t in c.traits:
			traits.append(trait_names[t])
		var dominant := -1
		var best := -1.0
		for g in c.goals:
			if c.goals[g] > best:
				best = c.goals[g]
				dominant = g
		f.store_line("%2d %-8s rank %d  st %5.1f  $%4d  comp %.2f  τ %.2f  %s  drives %s" % [
			cid, c.name, c.rank, c.standing, c.money, c.competence, c.temperature,
			"[" + ", ".join(traits) + "]", goal_names[dominant]])
	f.close()


# Hash over every constant in tuning.gd, so (seed, config_hash) identifies a
# run. Loaded by path rather than by class_name to avoid the editor's global
# class cache being stale on a fresh checkout.
func _config_hash() -> String:
	var tuning := load("res://sim/config/tuning.gd") as GDScript
	if tuning == null:
		push_error("cannot load sim/config/tuning.gd")
		return "ERROR"
	var constants := tuning.get_script_constant_map()
	return JSON.stringify(constants, "", true).sha256_text().substr(0, 12)
