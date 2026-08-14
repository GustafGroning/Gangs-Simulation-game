class_name Chronicle
extends RefCounted
# doc 4 §5. The human-readable output — debugger and shipped end-of-turn
# report in one artifact. Phase 2 carries basic turn/job lines; scorer terms,
# belief-vs-truth sigils and misattribution flags land in phases 3-4.

var lines: PackedStringArray = PackedStringArray()


func header(ws: WorldState, config_hash: String) -> void:
	lines.append("GANGS chronicle — seed %d · config_hash %s" % [ws.seed, config_hash])
	lines.append("")


func turn_header(ws: WorldState) -> void:
	lines.append("")
	lines.append("── TURN %d ─────────────────────────────────  heat %.2f" % [ws.turn, ws.heat])


func line(s: String) -> void:
	lines.append("  " + s)


func text() -> String:
	return "\n".join(lines)


func save(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Chronicle.save: cannot open %s" % path)
		return false
	f.store_string(text() + "\n")
	f.close()
	return true
