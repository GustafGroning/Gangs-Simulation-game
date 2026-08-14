class_name TraceTemplate
extends RefCounted
# doc 1 §5 — per-action trace spec. The turn loop emits Traces from these;
# actions never emit their own. Risk derivation (ai/risk.gd) reads them too.
# Authored action data, not world state — no to_dict/from_dict.

var kind: int = E.TraceKind.PHYSICAL
var reveals: Array[int] = []           # E.Field
var base_detectability: float = 0.4
var points_to: StringName = &"actor"   # "actor" | "instrument" | "attributed"
var delay_turns: int = 0               # e.g. Skim surfaces late
