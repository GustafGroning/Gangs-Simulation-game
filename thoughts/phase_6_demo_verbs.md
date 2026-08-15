# Phase 6 — The demo verb set (UNVALIDATED — built with no Godot access)

Date: 2026-08-15 · Status: **code complete for phases 5 (exit test) and 6,
never executed**

Built in the `@claude` GitHub Actions issue-automation sandbox, which has no
`godot` binary, no permitted network access to install one, and — unlike
prior sessions — no interactive Bash approval available at all (every
non-allowlisted shell command times out unanswered). Per the triggering
issue's explicit instruction, validation was skipped and the work proceeded
anyway. **Nothing below has been run.** Everything here is the result of a
careful manual read-through of every touched file (checking types, enum
values, invariant interactions, and control flow by hand), not a substitute
for actually running `tests/phase6_exit_test.sh`.

## What shipped

**Phase 5 close-out**: `tests/phase5_exit_test.sh` (the code — planner,
SabotageJob, `test_phase5.gd` — already existed from the prior session's
work, paused mid-regression-test; see `thoughts/phase_5_planner.md`). No
code changes to the planner itself this session.

**Phase 6 — the full 7-verb demo set**:
- `sim/actions/dig.gd` — untargeted (like TakeJob/AssignJob), auto-selects
  the actor's most dig-worthy belief. Four outcomes (resolve/corroborate/
  collapse/false-resolve) computed at execution time against ground truth
  (traces, the underlying event) — `evaluate()`/`requires()` stay
  belief-only. Scoped to the belief's ACTOR field only (Field enum has no
  MOTIVE, nothing populates INSTRUMENT).
- `sim/actions/spread_rumor.gd` — targeted, deliberately tells a chosen
  recipient a held belief. `Beliefs.deliver_chosen` (new) reuses the
  passive-gossip mutation logic with a gentler hop decay.
- `sim/actions/denounce.gd` — targeted, queues a case onto
  `WorldState.pending_judgments`; doesn't adjudicate itself.
- `sim/actions/kill.gd` — targeted, immediate removal + heat + relationship
  scrub (new invariant-safety requirement, see below). Escalation ladder's
  terminal rung.
- `sim/content/judgment.gd` — adjudicates queued Denounce cases at turn
  step 9. Judge selection, `case_strength` formula, and all four verdict
  effects (DISMISSED/DEMOTED/EXILED/KILLED) per doc 3 §4. Never reads
  `ws.events[...].actor_id` — the verdict is entirely a function of belief
  state, matching the doc's central rule.
- `sim/content/contest.gd` — the vacancy contest (doc 3 §2), wired into
  every turn (step 10) for every currently-vacant slot. This is now the
  ONLY way any vacancy fills in the demo (no Advocate action) — including
  the deliberate starting vacancy from `WorldGen.bootstrap`.
- `sim/content/exogenous.gd` — Rival Hit and Arrest only (doc 5 phase 6
  task 7's explicit prioritization out of doc 3 §3's 8 kinds). Placed at a
  new turn "step 1b" (doc's 12-step list has no numbered slot for
  exogenous events). Arrest is also triggered from a violent job's
  DISASTER outcome (doc 3 §1), called from `turn.gd` right after job
  resolution.
- `tests/test_phase6.gd` + `tests/phase6_exit_test.sh` — 20 seeds x 200
  turns, checking doc 4 §7's machine-checkable criteria (health metrics in
  band in >90% of seeds, `misattribution_rate` > 0.15 in >90%). Points 3-4
  of §7 (reconstruct-why / were-you-surprised) are Gustaf's read, not
  automatable.

## Structural changes this required

Kill (and Judgment's KILLED/EXILED verdicts, and Rival Hit) are the first
things in the whole sim that can remove a character mid-run. That broke
three assumptions nothing had ever tested before:

1. **Invariant I9** ("no relationship references a DEAD character") — every
   removal-to-DEAD path now calls the new `World.scrub_relationships`.
2. **A queued candidate's ACTOR could die before its own turn to execute**
   (a higher-priority Kill executing first in the same turn's resolution
   loop). `turn.gd`'s resolution loop now re-checks `actor.state ==
   ACTIVE` the same way it already re-checked `requires()` (invariant I3).
   `AssignJob` got the equivalent target-liveness check for the same
   reason.
3. **A job's worker could die in the one turn between assignment and
   resolution** (phase 5's latency). `Job.resolve()` now short-circuits to
   an "abandoned" outcome instead of crediting/penalizing a dead worker.

Also added `Character.credibility` (doc 3 §4 needs it for a DISMISSED
Denounce's accuser and a collapsed Dig's source — the schema didn't have a
place to put it) and extended `Tuning.ESCALATION_LADDER` to reach Kill
(needed a second dict key — see DECISIONS.md for why).

## What's genuinely unverified and worth watching first

- **Population survival over 200 turns.** Four separate mechanisms can now
  permanently remove a character (Kill, Judgment KILLED/EXILED, Arrest,
  Rival Hit) and none can add one back (Expansion is out of the demo's
  one-rank-change-mechanism scope per design_doc.md). Whether a 16-20
  person cast survives a 200-turn run at all is untested. `RIVAL_HIT_SHARE`
  and `KILL_VENGEANCE_GATE` were set by reasoning about doc 3's stated
  pacing, not by running anything.
- **Whether the contest now firing on the starting vacancy from turn 1
  changes phase 1/3/4/5's existing regression numbers.** Nothing in those
  phases locked in "the starting vacancy stays open" as a pass criterion,
  but it's a real behavioral change to the shared turn loop.
- **The phase-3 hang from the prior session** (see
  `thoughts/phase_5_planner.md`) was never root-caused. If it's still slow
  or stuck, that predates this session — nothing here touches the
  suspects listed there (`Job.assigned_turn`, the `to_resolve` filter).

## Next step when resuming

1. Run `tests/phase6_exit_test.sh` (which chains phase 1/3/4/5 regressions
   first). If phase 3 still hangs, that's the actual first thing to
   root-cause — everything after it is unverified transitively.
2. Watch cast size across the 200-turn runs specifically — if it's
   collapsing, `KILL_VENGEANCE_GATE`, `RIVAL_HIT_SHARE`, and
   `ARREST_HEAT_CHANCE`/`ARREST_FROM_DISASTER_CHANCE` are the knobs to
   loosen, in that order (Kill requires an actual scorer decision so it's
   probably the most self-limiting; Rival Hit and Arrest are blind rolls).
3. Read a chronicle or two by hand for legibility before trusting the
   metrics — this phase adds several new chronicle line types (⚖ Judgment,
   ♛ contest wins, ☠ Rival Hit, 🚓 Arrest) that have never been visually
   checked.
4. Only then: phase 7 (generation + the harness) is still fully unbuilt.
   Note that `sim/gen/world_gen.gd`'s current `WorldGen.bootstrap` already
   implements a fair amount of doc 2's character generation (traits with
   exclusions, temperature, competence, polarized goals, fitness-based slot
   assignment) as pre-phase-7 scaffolding — phase 7's real remaining scope
   is smaller than it looks: history simulation (`history_mode=
   "simulate"`), the six planted hooks, initial belief seeding through the
   real detection/transmission pipeline, `world_summary.txt`, and the
   sweep/ablation harness.
