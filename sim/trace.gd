class_name Trace
extends RefCounted
# doc 1 §3. Evidence emitted by an event — the ONLY channel for learning.
# Most traces must NOT include E.Field.ACTOR in `reveals`; that gap is the game.

var id: int = -1
var event_id: int = -1
var turn_created: int = 0
var kind: int = E.TraceKind.PHYSICAL
var reveals: Array[int] = []         # E.Field — which fields it exposes
var points_to_id: int = -1           # who it implicates (may be wrong)
var detectability: float = 0.5       # current, decays each turn
var found_by: Array[int] = []        # char_ids who have found it
var destroyed: bool = false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"event_id": event_id,
		"turn_created": turn_created,
		"kind": kind,
		"reveals": Array(reveals),
		"points_to_id": points_to_id,
		"detectability": detectability,
		"found_by": Array(found_by),
		"destroyed": destroyed,
	}


static func from_dict(d: Dictionary) -> Trace:
	var t := Trace.new()
	t.id = int(d["id"])
	t.event_id = int(d["event_id"])
	t.turn_created = int(d["turn_created"])
	t.kind = int(d["kind"])
	t.reveals = World.int_array(d["reveals"])
	t.points_to_id = int(d["points_to_id"])
	t.detectability = float(d["detectability"])
	t.found_by = World.int_array(d["found_by"])
	t.destroyed = bool(d["destroyed"])
	return t
