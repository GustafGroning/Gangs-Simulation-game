class_name Config
extends RefCounted
# Run configuration attached to WorldState (doc 1 §3 references `config: Config`
# without defining it). Minimal until the sweep harness (phase 7); tunables
# live in Tuning, never here.

var name: String = "default"


func to_dict() -> Dictionary:
	return {"name": name}


static func from_dict(d: Dictionary) -> Config:
	var c := Config.new()
	c.name = str(d.get("name", "default"))
	return c
