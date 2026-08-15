# Phase 4 — Scorer

Date: 2026-08-14 to 2026-08-15 · Status: **PHASE 4 EXIT TEST: PASS**

`tests/phase4_exit_test.sh` passes end to end on a local Godot 4.7.1
session: determinism grep, class-cache/parse, phase 1+3 regressions (34 +
44 checks), the phase 4 scorer test (45 checks, 20 seeds × 100 turns), and
a CLI run with contribution terms in the chronicle. Per demo_tasks.md
standing instruction #8, phase 5 can now start (new session).

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

## 2026-08-15 — First real run (local Godot 4.7.1), two bugs found and fixed

`tests/phase4_exit_test.sh` initially failed 13/45 checks in `test_phase4.gd`:
`inert_characters` over threshold in 11/20 seeds, and "vengeful superiors
never assigned at all" / "grudge targets got only 0.00 of their superiors'
assignments" in all 20. Root-caused both with throwaway diagnostic scripts
(`tests/debug_phase4.gd`, kept — a couple more were used and deleted) before
touching any code:

- **Real bug, game logic: rank-3 characters starve under the scorer.**
  `tests/debug_phase4.gd` showed the scorer legitimately ranking `assign_job`
  at a grudge target as the top-scoring candidate turn after turn — the
  vengeance mechanic itself was never broken. The starvation was structural:
  the phase-2 scaffold policy that `JOBS_PER_TURN=3` was tuned against (see
  phase-2 entry in DECISIONS.md) had an explicit "contested takes go to the
  longest-idle" anti-starvation rule. The phase-4 scorer replaced that
  wholesale with deterministic goal-driven best-fit choice (per DECISIONS.md
  phase-2 note: "Replaced wholesale by the scorer in phase 4") — with no
  fairness tiebreak, the same low-fit rank-3 characters (locked out of
  heist/negotiation by doc 3's rank bands, and outnumbering every other rank)
  kept losing the same jobs to the same higher-fit competitors every turn.
  Raised `JOBS_PER_TURN` 3→5 (see comment in `tuning.gd`): 11 failing seeds
  → 2 at `JOBS_PER_TURN=4` → 0 at `5`. This is a **judgment call, not a
  design-doc answer** — doc 4 doesn't give a value for a 16-character cast
  under scorer-driven (non-scaffold) selection; flagging here per CLAUDE.md
  rather than treating it as self-evidently correct. Worth a real sweep in
  phase 7 rather than resting on 20 seeds.
- **Test-harness bug, not a game bug:** `test_phase4.gd`'s per-seed `scan`
  closure incremented `vengeful_chances`/`vengeful_hits` (plain `int` locals
  declared outside the closure) from inside the closure. GDScript lambdas
  capture value-type locals (int/float/bool/String) **by value** — the
  closure was mutating its own private snapshot, never the outer variable,
  so both stayed 0 for the entire run regardless of what actually happened.
  (`vengeful_p`/`neutral_p`, both Arrays — a reference type — worked
  correctly the whole time, which is why the aggregate print already showed
  a real "p_succ 0.49 vs 0.65" split even while `hit_rate` read "0.00 (0/0)".)
  Fixed by routing both counters through a Dictionary. After the fix: grudge
  targets get 76% of their vengeful superior's assignments (2424/3192) —
  the real signal the test was written to catch, just never actually
  reporting it.

Both fixes are small and mechanical; nothing about the scorer's actual
decision logic needed to change. Full exit test now passes: determinism grep,
class-cache/parse, phase 1+3 regressions (34+44 checks), phase 4 scorer test
(45/45), CLI run with contribution terms.

Per the phase gate (demo_tasks.md standing instruction #8), phase 5 can now
start — new session, per Work modes in CLAUDE.md.
