extends SceneTree
# Loads every GDScript under res://sim/ plus main.gd and fails on any script
# that does not parse. Run: godot --headless --script tests/check_scripts.gd


func _initialize() -> void:
	var failures: Array[String] = []
	var count := _check_dir("res://sim", failures)
	count += _check_file("res://main.gd", failures)
	if failures.is_empty():
		print("script check OK — %d scripts parsed" % count)
		quit(0)
	else:
		for f in failures:
			printerr("script check FAILED: %s" % f)
		quit(1)


func _check_dir(path: String, failures: Array[String]) -> int:
	var count := 0
	var dir := DirAccess.open(path)
	if dir == null:
		failures.append("%s: cannot open directory" % path)
		return 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				count += _check_dir(full, failures)
		elif entry.ends_with(".gd"):
			count += _check_file(full, failures)
		entry = dir.get_next()
	dir.list_dir_end()
	return count


func _check_file(path: String, failures: Array[String]) -> int:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		failures.append(path)
	return 1
