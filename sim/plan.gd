class_name Plan
extends RefCounted
# doc 1 §3. Multi-turn intent; scoring semantics live in ai/planner.gd (phase 5).

var goal_action: StringName = &""
var target_id: int = -1
var steps: Array = []                # Array[PlanStep]
var step_index: int = 0
var patience: int = 0                # turns remaining before abandon
var frustration: int = 0
var terminal_score: float = 0.0      # cached at creation


func to_dict() -> Dictionary:
	var steps_d := []
	for s: PlanStep in steps:
		steps_d.append(s.to_dict())
	return {
		"goal_action": String(goal_action),
		"target_id": target_id,
		"steps": steps_d,
		"step_index": step_index,
		"patience": patience,
		"frustration": frustration,
		"terminal_score": terminal_score,
	}


static func from_dict(d: Dictionary) -> Plan:
	var p := Plan.new()
	p.goal_action = StringName(str(d["goal_action"]))
	p.target_id = int(d["target_id"])
	for sd in d["steps"]:
		p.steps.append(PlanStep.from_dict(sd))
	p.step_index = int(d["step_index"])
	p.patience = int(d["patience"])
	p.frustration = int(d["frustration"])
	p.terminal_score = float(d["terminal_score"])
	return p
