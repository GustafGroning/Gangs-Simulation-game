# Phase 3 — Information layer

Date: 2026-08-14 · Status: **exit test PASS** (44 checks)

## What was built
- `info/traces.gd` — template lookup (moves onto Action classes in phase 4),
  emission by the turn loop (never by actions), subtractive decay with
  removal below TRACE_MIN_DETECT, detection roll:
  detectability × proximity(tree BFS) × (1+heat) × OBSERVANT bonus.
- `info/beliefs.gd` — all belief updates funnel through one `_merge`:
  field-filling, corroboration (+0.1 same-name different-source — this is
  where confident falsehoods are born), conflict (higher confidence wins the
  name, certainty erodes). First-hand beliefs for actors and assignees.
  Transmission: one hop/turn to graph neighbors, per-hop confidence decay,
  actor mutation toward known-motive suspects, and **speculation** — a
  nameless rumor about a hostile event grows a name with
  ACTOR_SPECULATION_CHANCE. Upward reporting: P scales with confidence,
  self/patron/friend-implication suppressed ×0.1, recipient WEIGHTED (patron
  favored, disloyalty redirects to rivals), fidelity scaled by loyalty,
  superior attention budget (4/turn, most confident first).
- Sabotage trace: PHYSICAL revealing ACTION+TARGET, never ACTOR — verified
  explicitly (the crux invariant of the design).
- Siblings get known_motive 0.3 at generation (rivalry for the same advocacy
  is public) — this is what motive-biased mutation bites on pre-Dig.
- Chronicle: hostile-event actor beliefs are printed with truth-vs-belief
  flags (✗ WRONG); scripted ground truth marked with †.

## Exit test — `tests/phase3_exit_test.sh` (20 seeds × 100 turns, sabotage every 10)
- beliefs about sabotages exist, unevenly distributed — 20/20
- misattribution_rate: aggregate **0.79** (gate > 0.15), every seed above
- confident falsehoods: ~302/run (gate ≥ 3)
- grounding invariant (I1) asserted every turn — no violations
- disloyal subordinates delivered 2,792 reports to rivals across seeds
- phases 1-2 regressions still green

## Design notes / watch-items
- **Speculation is an addition to canon** (mutation of an *absent* actor
  field): without it, zero misattribution can exist before Dig lands —
  canon's "rumors drift toward whoever already looks guilty" supports it.
  DECISIONS.md.
- misattribution 0.79 and hostile-belief accuracy ~0.2 are the *pre-Dig*
  equilibrium: nothing can correct a wrong rumor yet. Dig (phase 6) is the
  corrective force; re-evaluate doc 4's mean_belief_accuracy band (0.5–0.8)
  at phases 6-7. Overall accuracy runs 0.96 because truthful eyewitness
  beliefs about open jobs dominate numerically — metrics now report both
  `mean_belief_accuracy` and `hostile_belief_accuracy`.
- Reporting volume is high (~140 rival reports/run) — acceptable now;
  worth rechecking when the scorer makes information consequential.
