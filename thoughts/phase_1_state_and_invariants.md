# Phase 1 — State and invariants

Date: 2026-08-14 · Status: **exit test PASS** (34 checks)

## What was built
- All core structs from doc 1 §3, verbatim fields: `Character`, `Relationship`,
  `Event`, `Trace`, `Belief`, `Plan`, `PlanStep`, `ActionCandidate`, `Slot`,
  `WorldState`. Plus `Config` (doc 1 §3 references the type but never defines
  it — minimal `{name}` placeholder, see DECISIONS.md) and the `TraceTemplate`
  fields from doc 1 §5.
- `to_dict()` / `from_dict()` on every state struct. Both native and
  JSON-text round trips are byte-identical (JSON stringifies int dictionary
  keys and turns ints into doubles; `from_dict` normalizes both back).
  The RNG state is serialized as a string — it is a 64-bit int and JSON
  numbers are doubles.
- `world.gd` accessors: `pair_key`, `relationship_of`, `set_relationship`,
  `opinion_of` (earned + purchased channel), `slot_of`, `patron_of`,
  `crew_of`, `resync_tree`. All tree/relationship access goes through these.
- `World.check_invariants()` returning tagged violations + `assert_invariants()`
  wrapper. `WorldState.events` debug access flag with `clear_events_read()` /
  `assert_ai_clean()` (doc 4 §3).
- 5-character fixture world in `tests/test_phase1.gd`: 6 slots (one vacant),
  4 relationships, 2 events (one anonymous sabotage), 1 actor-less trace,
  1 partial belief + 1 fabrication.

## Exit test — `tests/phase1_exit_test.sh`
1. determinism grep — PASS
2. `--import` regenerates the global class cache (headless runs need this
   after new `class_name` files — see DECISIONS.md)
3. all 35 scripts parse — PASS
4. fixture invariants + accessors + double round-trip + access flag +
   8 corruption probes — PASS (each corruption fires exactly its own invariant)

## Deviations / notes
- **Invariants I3 and I4** (requires() held at selection; no acting on unheld
  beliefs) are execution-time contracts, not state predicates — they cannot be
  checked from a snapshot. They will be enforced at the point of action
  execution/scoring (phases 4+). The corruption suite covers the 8
  state-decidable invariants.
- **`beliefs: Dictionary` is keyed by event_id (doc 1), so two fabrications
  held by the same character would collide at key -1.** Not a problem until
  Fabricate exists; logged in BACKLOG.md for a phase 3 decision.
- `TraceTemplate` gets no serialization — it is authored action data, not
  world state.
- Added `Tuning.PURCHASED_OPINION_MULT` (needed by `opinion_of`, absent from
  doc 4 §1).

## Next
Phase 2 — turn loop and job economy.
