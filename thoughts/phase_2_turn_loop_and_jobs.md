# Phase 2 — Turn loop and job economy

Date: 2026-08-14 · Status: **exit test PASS** (126 checks; 19/20 seeds fully in band)

## What was built
- `turn.gd` — the 12-step resolution order with phases 3-6 steps stubbed and
  marked. Resolution priority Command → Earn wired (the other classes have no
  verbs yet). Strict one-action-per-character, with directed assignment
  pre-empting self-selection (doc 3 §1).
- `content/jobs.gd` — Job struct, six kinds (tuning-table-driven), weighted
  generation with jitter, expiry with the superior's standing penalty,
  resolution per the doc 3 formula and outcome bands.
- `content/heat.gd` — accumulation + decay (placement decision: doc 1's layout
  has no heat.gd; content/ since doc 3 specs it).
- `log/chronicle.gd`, `log/metrics.gd` — turn output and economy metrics.
- `gen/world_gen.gd` — BOOTSTRAP world builder (16 chars, 17 slots, one
  rank-2 vacancy, doc-2-shaped: traits w/ exclusions, polarized goals,
  fitness-based slot assignment, structural+chemistry opinions). Phase 7
  replaces the guts (history, hooks, floors).
- `main.gd` — full single-run pipeline: chronicle.txt, metrics.json,
  events.jsonl, final_state.json, world_summary.txt.
- Scaffold selection policy (random, replaced by the scorer in phase 4):
  superiors assign 80% (hunger- and fit-weighted), others take (fit-weighted),
  contested jobs go to whoever idled longest.

## Exit test — `tests/phase2_exit_test.sh`
20 seeds × 100 turns in-process, plus phase-1 regression and a CLI run:
- board never starves (>2 turns) at selection time, never overflows — 20/20
- fill rate 0.99 (target > 0.8) — 20/20
- no leaked jobs; heat recovers < 0.2 within 10 turns — 20/20
- inert characters 0 (target 0) — 20/20
- standing in band 19/20 seeds (seed 9 end ratio 3.02, threshold 3.0);
  passing per doc 4 §7's ">80% of runs in band" philosophy, held at 90%
- outcomes aggregate 28/45/24/3 (see canon tension below), gini 0.32
  (band 0.2-0.5)
- determinism: same seed → byte-identical event ledger

## The tuning fight (three iterations, worth remembering)
1. **Naive first run failed exactly as doc 4 predicts**: board "empty" (it was
   measuring surplus after consumption, not availability at selection),
   runaway ratios to 7×, 2-5 inert characters per seed.
2. Fixes: board sampled after posting; hunger-weighted allocation (assignment
   and contested takes go to the longest-idle); fit-weighted matching
   (squared) so weak characters work easy jobs; standing soft cap implemented
   (canon declares standing soft-capped, no mechanism given); losses scale
   with stature (mirror of the cap — a nobody can't be driven far below their
   rank floor); JOBS_PER_TURN 2→3, COMPETENCE_WEIGHT 0.6→1.0,
   PARTIAL standing 0.3→0.5 (all with rationale comments in tuning.gd).
3. Runaway metric corrected to canon: doc 4 §2 says metrics are computed from
   the END-STATE; the transient max stays in metrics.json as a diagnostic.

## Canon tensions (flagged, not silently resolved — QUESTIONS.md)
- Doc 3 §6's "roughly 30/30/30/10" outcome split is unreachable with the
  doc 3 resolution formula while competence stays meaningful; we land at
  ~28/45/24/3 with competence decisive. Bands in the smoke test are wide.
- Doc 4's "no character > 3× median standing" sits close to doc 2's own
  starting spread (boss 60 / median 25 = 2.4 at turn 0); passing 100% of
  seeds would require flattening the hierarchy. Doc 4 §7's >80%-of-runs rule
  applied instead.
- Doc 3 §6 item 6 (exogenous event rate) deferred to phase 6 where exo
  events are built (doc 5 puts them there).

## Notes
- `tests/debug_phase2.gd` is a per-seed diagnostic dump — kept for tuning.
- Job trace profiles (doc 3 kind table) intentionally not wired: trace
  emission is phase 3.
