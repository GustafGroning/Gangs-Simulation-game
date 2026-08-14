class_name Event
extends RefCounted
# doc 1 §3. Ground truth — immutable after creation, append-only into
# WorldState via add_event(); array index == id. The AI never reads these.

var id: int = -1
var turn: int = 0
var actor_id: int = -1
var action: StringName = &""
var target_id: int = -1
var instrument_id: int = -1          # -1 if acted directly
var visibility: int = E.Visibility.PRIVATE
var attributed_to_id: int = -1       # only when visibility == ATTRIBUTED
var outcome: Dictionary = {}         # action-specific result payload


func to_dict() -> Dictionary:
	return {
		"id": id,
		"turn": turn,
		"actor_id": actor_id,
		"action": String(action),
		"target_id": target_id,
		"instrument_id": instrument_id,
		"visibility": visibility,
		"attributed_to_id": attributed_to_id,
		"outcome": outcome.duplicate(true),
	}


static func from_dict(d: Dictionary) -> Event:
	var e := Event.new()
	e.id = int(d["id"])
	e.turn = int(d["turn"])
	e.actor_id = int(d["actor_id"])
	e.action = StringName(str(d["action"]))
	e.target_id = int(d["target_id"])
	e.instrument_id = int(d["instrument_id"])
	e.visibility = int(d["visibility"])
	e.attributed_to_id = int(d["attributed_to_id"])
	e.outcome = (d["outcome"] as Dictionary).duplicate(true)
	return e
