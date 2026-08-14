class_name ActionCandidate
extends RefCounted
# doc 1 §3. The unit the scorer operates on. Transient — never stored on
# WorldState. `contributions` produces the two explanatory terms in every
# chronicle line; it is populated DURING scoring, not after.

var action: StringName = &""
var actor_id: int = -1
var target_id: int = -1
var instrument_id: int = -1
var visibility: int = E.Visibility.PRIVATE

var utility: float = 0.0
var risk: float = 0.0
var affinity: float = 0.0
var commitment: float = 0.0
var score: float = 0.0

var contributions: Dictionary = {}   # String -> float, for the log


func to_dict() -> Dictionary:
	return {
		"action": String(action),
		"actor_id": actor_id,
		"target_id": target_id,
		"instrument_id": instrument_id,
		"visibility": visibility,
		"utility": utility,
		"risk": risk,
		"affinity": affinity,
		"commitment": commitment,
		"score": score,
		"contributions": contributions.duplicate(),
	}


static func from_dict(d: Dictionary) -> ActionCandidate:
	var c := ActionCandidate.new()
	c.action = StringName(str(d["action"]))
	c.actor_id = int(d["actor_id"])
	c.target_id = int(d["target_id"])
	c.instrument_id = int(d["instrument_id"])
	c.visibility = int(d["visibility"])
	c.utility = float(d["utility"])
	c.risk = float(d["risk"])
	c.affinity = float(d["affinity"])
	c.commitment = float(d["commitment"])
	c.score = float(d["score"])
	c.contributions = (d["contributions"] as Dictionary).duplicate()
	return c
