class_name Belief
extends RefCounted
# doc 1 §3. One character's claim about an event — partial and possibly wrong
# by design. A belief may know ACTION and TARGET but not ACTOR; that is the
# normal case and the whole point of Dig.
#
# Invariant (I1): event_id >= 0 XOR fabricated == true.

var holder_id: int = -1
var event_id: int = -1               # -1 only for fabrications
var claim: Dictionary = {}           # E.Field -> value; partial
var confidence: float = 0.0
var source_id: int = -1              # who told me; -1 if first-hand
var hops: int = 0
var turn_acquired: int = 0
var fabricated: bool = false         # true if no backing event exists
var spent: bool = false              # consumed as leverage


func to_dict() -> Dictionary:
	var claim_d := {}
	for k: int in claim:
		# ACTION claims hold a StringName; everything else is a char id.
		claim_d[k] = String(claim[k]) if k == E.Field.ACTION else claim[k]
	return {
		"holder_id": holder_id,
		"event_id": event_id,
		"claim": claim_d,
		"confidence": confidence,
		"source_id": source_id,
		"hops": hops,
		"turn_acquired": turn_acquired,
		"fabricated": fabricated,
		"spent": spent,
	}


static func from_dict(d: Dictionary) -> Belief:
	var b := Belief.new()
	b.holder_id = int(d["holder_id"])
	b.event_id = int(d["event_id"])
	for k in d["claim"]:
		var field := int(k)
		b.claim[field] = StringName(str(d["claim"][k])) if field == E.Field.ACTION else int(d["claim"][k])
	b.confidence = float(d["confidence"])
	b.source_id = int(d["source_id"])
	b.hops = int(d["hops"])
	b.turn_acquired = int(d["turn_acquired"])
	b.fabricated = bool(d["fabricated"])
	b.spent = bool(d["spent"])
	return b
