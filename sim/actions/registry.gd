class_name ActionRegistry
extends RefCounted
# id → Action. The registry is the source of truth for which actions exist;
# action identity is a StringName, never an enum. Instances are stateless
# authored data, so caching them in a static is replay-safe.

static var _actions: Dictionary = {}


static func _ensure() -> void:
	if not _actions.is_empty():
		return
	for a: Action in [
		IdleAction.new(), TakeJobAction.new(), AssignJobAction.new(), SabotageJobAction.new(),
		DigAction.new(), SpreadRumorAction.new(), DenounceAction.new(), KillAction.new(),
	]:
		_actions[a.id] = a


static func has_action(id: StringName) -> bool:
	_ensure()
	return _actions.has(id)


static func get_action(id: StringName) -> Action:
	_ensure()
	assert(_actions.has(id), "unknown action id: %s" % id)
	return _actions[id]


static func all_actions() -> Array:
	_ensure()
	var ids := _actions.keys()
	ids.sort()
	var out := []
	for id in ids:
		out.append(_actions[id])
	return out
