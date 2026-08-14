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

## 2026-08-14 — Static review pass (no Godot available)
A `@claude` GitHub Actions run picked this up to continue but the sandbox has
no Godot binary and no network access to install one — `tests/phase4_exit_test.sh`
still could not be run. Did a full static review instead (design docs +
CLAUDE.md hard rules vs. every phase-4 file) and fixed what's checkable without
execution:
- **Rule-2 violation**: `scorer.gd`'s repetition penalty special-cased
  `cand.action != &"idle"` by literal id. Replaced with
  `Action.subject_to_repetition_penalty` (false only on `IdleAction`).
- **Magic numbers**: `assign_job.gd`'s and `take_job.gd`'s authored trace
  detectability, and `risk.gd`'s detect cap and heat-severity multiplier, were
  inlined instead of reading `Tuning`. All now reference `Tuning` constants
  (`ASSIGN_TRACE_DETECT`, `TAKEJOB_RISK_DETECT_ESTIMATE` — new, `DETECT_CAP`,
  `RISK_HEAT_SEVERITY_MULT` — new, `CONTRIBUTION_DISPLAY_THRESHOLD` — new).
- **Dead code**: `candidates.gd` had a redundant `action.id != &"idle"` guard
  around `requires()` for untargeted actions (idle never overrides
  `requires`, so it was a no-op check that also named an action by id outside
  its own file). Removed.
- **Weak exit-test check**: `phase4_exit_test.sh`'s "chronicle carries
  contribution terms" grep matched a bare `(`, which `Job.generate_board`'s
  unrelated posting lines already satisfy — it had near-zero power to catch a
  scorer/chronicle wiring regression. Anchored on `Scorer.top_terms`'s actual
  `name ±0.00` format instead.
- Flagged one open design question in `QUESTIONS.md` (TakeJob's flat
  perceived-detectability estimate vs. actual per-kind detectability) rather
  than silently resolving it either way.
- Confirmed clean: no ground-truth (`world.events`) reads under `sim/ai/`, no
  action-identity branching in `selection.gd`, no determinism-ban violations,
  the −1..1 magnitude bound is a real `assert` not a clamp, `-1` target-id
  handling is consistent throughout.

**Still true: nothing below has actually been run.** The vengeance-assignment
mechanics look internally consistent by inspection (see review notes) but the
exit test's numeric bands (entropy, hit-rate margins, fill/inert sanity) need
a real headless run — expect the tuning iteration the previous note called
out. This needs a Godot-capable (local or CI-with-Godot) session.

## Next step when resuming
Run `tests/phase4_exit_test.sh` on a machine with Godot 4.7 installed:
entropy > 1.0, vengeance-assignment correlation (planted grudges → harder
jobs, disproportionate targeting), fill/inert sanity under the scorer,
phases 1+3 regressions, CLI chronicle carries contribution terms.
Expect a tuning iteration or two (e.g. assign-vs-take balance, fill rate).
Per the phase gate (demo_tasks.md standing instruction #8), phases 5-7 do not
start until this passes and is reported.
