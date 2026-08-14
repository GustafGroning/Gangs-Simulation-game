# Phase 4 — Scorer (WIP: implemented, NOT yet validated)

Date: 2026-08-14 · Status: **code complete, exit test written but NOT RUN**

Gustaf returned mid-phase; run paused here. Nothing below has passed its
exit test yet — treat all of phase 4 as unverified.

## Built (unverified)
- `actions/action.gd` — the doc 1 §5 contract, plus `priority` (resolution
  class), `targeted`, `visibilities`, and `trace_specs()` (dynamic trace
  emission specs, defaulting to the authored templates).
- `actions/registry.gd` — static id→Action registry (idle, take_job,
  assign_job), asserts on unknown ids.
- `actions/idle.gd` — the always-legal floor candidate (stands in for Lie
  Low, which is not a demo verb).
- `actions/take_job.gd` — evaluates best open job (standing/wealth
  magnitudes from expected outcome), executes by self-assignment; work event
  still comes from Job.resolve. Kind-dependent trace specs moved here.
- `actions/assign_job.gd` — duty (likely success → standing) vs spite
  (likely failure × vengeance[target]); deterministic job choice shared by
  evaluate/execute.
- `ai/attention.gd` — priority-ordered salience (patron, patron's patron,
  crew, grudges/loyalties, vacancy competitors, recent-belief people),
  Paranoid +3 cap, curiosity slots.
- `ai/candidates.gd` — gate-first generation over the attention set.
- `ai/risk.gd` — P_detected × P_attributed × severity derived from
  templates/tags; Reckless/Craven distortions; motive raises attribution,
  alternative suspects lower it. Observer density via per-turn-cached tree
  distances (`World.tree_distances`, invalidated on resync_tree).
- `ai/scorer.gd` — utility Σ w×m (hard error outside −1..1), risk, trait
  affinity, LOYAL veto, repetition penalty; contributions populated during
  scoring; `top_terms()` feeds the chronicle.
- `ai/selection.gd` — softmax over top 5 with per-character temperature.
- `ai/weights.gd` — believed-harm → vengeance (severity × confidence),
  decay toward baseline / toward zero with dust removal.
- `turn.gd` — scaffold replaced: per-character clear_events_read →
  attention → candidates → score → softmax → assert_ai_clean; resolution
  sorted by priority with pre-drawn random tiebreak; requires() re-checked
  at execution (I3); assignment pre-emption; contribution terms on
  chronicle lines.
- `metrics.gd` — action_counts + action_entropy (executed actions + idle).

## Next step when resuming
Run `tests/phase4_exit_test.sh` (already written):
entropy > 1.0, vengeance-assignment correlation (planted grudges → harder
jobs, disproportionate targeting), fill/inert sanity under the scorer,
phases 1+3 regressions, CLI chronicle carries contribution terms.
Expect a tuning iteration or two (e.g. assign-vs-take balance, fill rate).
