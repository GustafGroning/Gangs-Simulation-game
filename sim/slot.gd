class_name Slot
extends RefCounted
# doc 1 §3. The tree is a flat list of slots; Character.rank and patron_id
# are derived from occupancy via World.resync_tree — never set directly.

var id: int = -1
var rank: int = 0
var parent_slot_id: int = -1
var occupant_id: int = -1            # -1 = vacant


func to_dict() -> Dictionary:
	return {
		"id": id,
		"rank": rank,
		"parent_slot_id": parent_slot_id,
		"occupant_id": occupant_id,
	}


static func from_dict(d: Dictionary) -> Slot:
	var s := Slot.new()
	s.id = int(d["id"])
	s.rank = int(d["rank"])
	s.parent_slot_id = int(d["parent_slot_id"])
	s.occupant_id = int(d["occupant_id"])
	return s
