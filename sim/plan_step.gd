class_name PlanStep
extends RefCounted
# doc 1 §3. One step of a Plan.

var action: StringName = &""
var target_id: int = -1
var instrument_id: int = -1
var visibility: int = E.Visibility.PRIVATE


func to_dict() -> Dictionary:
	return {
		"action": String(action),
		"target_id": target_id,
		"instrument_id": instrument_id,
		"visibility": visibility,
	}


static func from_dict(d: Dictionary) -> PlanStep:
	var s := PlanStep.new()
	s.action = StringName(str(d["action"]))
	s.target_id = int(d["target_id"])
	s.instrument_id = int(d["instrument_id"])
	s.visibility = int(d["visibility"])
	return s
