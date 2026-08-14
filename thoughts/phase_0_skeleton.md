# Phase 0 — Skeleton and conventions

Date: 2026-08-14 · Status: **exit test PASS**

## Goal (doc 5)
The project runs headless, deterministically, and does nothing.

## What was built
- `sim/` module structure per doc 1 §4 — 33 files. Skeleton files carry only
  `class_name` + a one-line pointer to the phase that fills them in.
- `sim/enums.gd` — all eight enums from doc 1 §2, verbatim.
- `sim/rng.gd` — `Rng.shuffle` (Fisher-Yates, in-place), `Rng.pick`,
  `Rng.weighted_pick`, `Rng.randfn`; all take an explicit
  `RandomNumberGenerator`.
- `sim/config/tuning.gd` — all 55 constants from doc 4 §1 (incl.
  `DEFAULT_CONF_THRESHOLD` from the trait-distortion notes), typed, grouped,
  with the tuning-order comment.
- `main.gd` — headless `SceneTree` entry point parsing
  `--seed --turns --config --out --sweep --seeds --vary`; prints the
  `(seed, config_hash)` log header; unimplemented paths exit nonzero.
- `./gangs` — CLI wrapper resolving the Godot binary ($GODOT → PATH →
  /Applications). Godot 4.7.1 confirmed on this machine.
- `ci/check_determinism_bans.sh` — the doc 5 grep, adapted to allow
  dot-prefixed calls on the explicit rng (see DECISIONS.md).
- `CLAUDE.md` already carries the hard architectural rules + determinism rules
  verbatim (done in the setup session).

## Exit test — `tests/phase0_exit_test.sh`
Written before the implementation, per standing instruction 7. Three steps:
1. determinism grep passes — **PASS** (and verified non-vacuous: a planted
   violation file tripped all three ban categories, then was removed)
2. every script under `sim/` + `main.gd` parses headless — **PASS** (34 scripts)
3. `./gangs --seed 1 --turns 0` exits clean — **PASS**, header:
   `gangs — seed 1 · config default · config_hash 53980efc9976 · turns 0`

Negative paths verified: `--turns 5` → exit 3, unknown arg → exit 2,
`--sweep` → exit 3.

## Deviations / notes
- `TraceTemplate` got its own file `sim/trace_template.gd` (doc defines the
  class but no file for it) — DECISIONS.md.
- `heat.gd` (named in phase 2's task list, absent from the doc 1 §4 layout) —
  parked in BACKLOG.md for a phase 2 decision.
- Not a git repository yet, so "CI" is a local script — BACKLOG.md.

## Next
Phase 1 — State and invariants: fill the structs (doc 1 §3), `to_dict()` /
`from_dict()` everywhere, `world.gd` accessors, the ten invariants, the
AI-access debug flag on `WorldState.events`, and the 5-character fixture test.
Stopped here per the phase gate.
