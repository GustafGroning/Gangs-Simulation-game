class_name IdleAction
extends Action
# The floor candidate: always legal, zero utility, no event, no traces.
# Exists so selection always has a defined answer when everything else is
# gated or too risky (Lie Low takes this role post-demo).


func _init() -> void:
	id = &"idle"
	tags = []
	priority = 6
	targeted = false
