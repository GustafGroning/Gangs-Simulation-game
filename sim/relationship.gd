class_name Relationship
extends RefCounted
# doc 1 §3. Directed: A's feeling toward B. Stored on WorldState keyed by
# World.pair_key(from_id, to_id); never index the dictionary raw — read
# through World.opinion_of, which folds in the purchased (brittle) channel.

var from_id: int = -1
var to_id: int = -1
var opinion: float = 0.0             # earned opinion, −1..1
var known_motive: float = 0.0        # 0..1 — how publicly known the grudge is
var interactions: int = 0


func to_dict() -> Dictionary:
	return {
		"from_id": from_id,
		"to_id": to_id,
		"opinion": opinion,
		"known_motive": known_motive,
		"interactions": interactions,
	}


static func from_dict(d: Dictionary) -> Relationship:
	var r := Relationship.new()
	r.from_id = int(d["from_id"])
	r.to_id = int(d["to_id"])
	r.opinion = float(d["opinion"])
	r.known_motive = float(d["known_motive"])
	r.interactions = int(d["interactions"])
	return r
