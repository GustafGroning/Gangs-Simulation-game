class_name Action
extends RefCounted
# doc 1 §5 — the action contract. `evaluate` is the ONLY place
# action-specific knowledge lives. Actions never reference other actions;
# the scorer never branches on action identity; traces are emitted by the
# turn loop from templates — actions do not emit their own.

var id: StringName = &""
var tags: Array[int] = []                    # E.ActionTag
var trace_templates: Array = []              # Array[TraceTemplate] — risk reads these
# Resolution priority class: 0 Command · 1 Cover · 2 Earn · 3 Strike ·
# 4 Court · 5 Whisper · 6 Learn (gangs-gdd.md resolution order).
var priority: int = 2
# Whether candidates expand over the attention set (target = character).
var targeted: bool = false
# Visibility parameters this action can be performed with (lazy expansion
# only adds more when the action is hostile — phase 6).
var visibilities: Array[int] = [E.Visibility.OPEN]


# Is this action legal for actor→target, given ONLY the actor's beliefs?
# (target is null for untargeted actions.)
func requires(_world: WorldState, _actor: Character, _target: Character) -> bool:
	return true


# Returns { E.Goal: magnitude }, magnitudes in −1..1 (enforced by the scorer
# as a hard error, not a clamp).
func evaluate(_world: WorldState, _actor: Character, _target: Character) -> Dictionary:
	return {}


# Apply effects, return the Event (may be null when the effect materializes
# elsewhere, e.g. TakeJob's work event comes from job resolution).
func execute(_world: WorldState, _cand: ActionCandidate) -> Event:
	return null


# Dynamic trace specs for an executed event (kind-dependent detectability
# etc.). Defaults to materializing the authored templates.
func trace_specs(_ws: WorldState, e: Event) -> Array:
	var out := []
	for t: TraceTemplate in trace_templates:
		var points := e.actor_id
		if t.points_to == &"instrument" and e.instrument_id != -1:
			points = e.instrument_id
		elif t.points_to == &"attributed" and e.attributed_to_id != -1:
			points = e.attributed_to_id
		out.append({
			"kind": t.kind,
			"reveals": t.reveals.duplicate(),
			"detect": t.base_detectability,
			"points_to_id": points,
		})
	return out
