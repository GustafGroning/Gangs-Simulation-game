class_name Heat
extends RefCounted
# doc 3 §5. One organization-wide float, 0..1 — the rhythm mechanism.
# Rises on violence, job failures, disasters; decays every turn in upkeep.
# High-heat effects on detection/severity land with the info layer (phase 3).
# Placement decision (doc 1 layout has no heat.gd): sim/content/, per DECISIONS.md.


static func add(ws: WorldState, amount: float) -> void:
	ws.heat = clampf(ws.heat + amount, 0.0, 1.0)


static func decay(ws: WorldState, lie_low_count: int = 0) -> void:
	var relief := Tuning.HEAT_DECAY + lie_low_count * Tuning.LIE_LOW_HEAT_RELIEF
	ws.heat = clampf(ws.heat - relief, 0.0, 1.0)
