# Phase 5 — Planner (WIP, paused mid-session for the night)

Date: 2026-08-15 · Status: **code written, NOT validated — stopped on a hung test**

Session paused here at Gustaf's request (going to bed). Nothing below has
passed its exit test. Do not advance past phase 5 until it does.

## Design decision: pulled SabotageJob forward from phase 6

`demo_tasks.md`'s phase 5 Goal line says "Still only the phase-2 verbs"
(TakeJob/AssignJob), but its own task list names the escalation ladder
"Sabotage → Frame → Kill" — a real self-contradiction in the doc. Empirically
confirmed with a real test run: with only TakeJob/AssignJob, AssignJob's only
recoverable gate ("no eligible job for target right now") almost never fires
once `JOBS_PER_TURN=5` (required by phase 4's already-passing no-inert-
characters band) — 18/20 seeds formed literally zero plans. Phase 2/4's
abundance requirement and phase 5's gating requirement fight over the same
resource.

Resolution: pulled `SabotageJob` forward (the simplest phase-6 verb, and the
one named in phase 5's own escalation-ladder text). This needed a real
structural change — jobs previously resolved the SAME turn they were
assigned, leaving no turn where a job was "in progress" for anyone to
intervene on. Added `Job.assigned_turn` and one turn of latency between
assignment and resolution (`turn.gd`: jobs with `assigned_turn < ws.turn`
resolve). Frame and Kill remain out of scope (Frame isn't a demo verb at
all per CLAUDE.md's seven; Kill is still phase 6).

**This is a judgment call under real time pressure, not a canon-sanctioned
answer.** Flagged in QUESTIONS.md. Worth Gustaf's review specifically:
whether pulling Sabotage forward was the right call vs. some other fix
(e.g. loosening the phase-5 exit test's numeric bands instead, or a
different gating mechanism entirely).

## Built (UNVALIDATED — nothing below has been run to a pass)

- `Action.gated_recoverably()` / `Action.plan_value()` — new virtual hooks
  (default false / `{}`), the planner's belief-safe way to value a
  currently-illegal targeted action without calling `evaluate()` (which is
  usually undefined for a missing resource). Never branches on action
  identity (rule 2 intact) — planner calls these the same way the scorer
  calls `evaluate()`.
- `Scorer.weighted_utility()` — factored out of `_score()` so the planner's
  terminal-value estimate uses the identical goal-weight lookup the real
  scorer will apply later.
- `Scorer._score()` — plan commitment wired: continuation bonus + (for a
  non-terminal step) discounted terminal value, when a candidate matches the
  active plan's current step. Repetition penalty now skips a candidate that
  IS the plan's own step.
- `ai/planner.gd` — `maybe_start()` (scans attention for the best
  gated-but-valuable targeted action, forms a single-step-at-a-time Plan) and
  `tick_after_resolution()` (advance/complete on a match, else tick
  patience/frustration, abort or escalate via `Tuning.ESCALATION_LADDER` on
  exhaustion).
- `turn.gd` — wired `Planner.maybe_start` after attention build, per-turn
  `chron.line` on plan formation, `Planner.tick_after_resolution` after the
  resolution loop, and a fix for the metrics gap the new job latency opened
  (a worker previously got `mark_acted` credit when their job resolved
  same-turn; now that's a turn later, so a separate scan credits
  `assigned_turn == ws.turn` immediately — otherwise every job-taking turn
  would misread as idle and likely re-break phase 4's inert-characters band).
- `metrics.gd` — `plan_resolved()`, `plans_completed`/`plans_aborted`,
  `plan_completion_rate`, `mean_plan_length_at_execution` (weighted by
  completions per seed, not a flat mean-of-means; "length" = turns alive,
  1 minimum since a plan can't complete the turn it's created — it only
  forms while gated).
- `sim/actions/sabotage_job.gd` — new action. Priority 3 (Strike), tags
  `[DECEPTION]`. `requires()`: target has a job assigned on a strictly
  earlier turn, not yet resolved or sabotaged. Trace reveals ACTION+TARGET
  only, never ACTOR (doc 3's general principle) — misattribution is left to
  the existing phase-3 belief/mutation machinery, no new plumbing needed.
  Has its own `gated_recoverably`/`plan_value` (target not currently mid-job
  — this is the REAL planning trigger now, not AssignJob's).
- `Job.assigned_turn` (new field, not in doc 3's Job struct — flagged) +
  `Job.resolve()` now reads `sabotaged_by_id` into the doc-3 formula's
  `sabotage_penalty` term (was a hardcoded 0.0 placeholder already left by
  whoever built phase 4). `Tuning.SABOTAGE_PENALTY`, `SABOTAGE_AMBITION_MAG`,
  `ESCALATION_LADDER = {assign_job: [assign_job, sabotage_job]}` added.
- `tests/test_phase5.gd` written (20 seeds × 100 turns): per-seed sanity
  that plans form/resolve at all, `mean_plan_length_at_execution > 1.8`,
  `plan_completion_rate` in [0.25, 0.6], and a regex-based chronicle check
  for a "begins plotting" line followed later by the matching execution
  line (any action, not hardcoded to assign_job).

## Where it broke off

Ran phase1 (PASS, 34 checks) and phase4 regressions successfully after the
planner wiring, before the job-latency change. After adding
`Job.assigned_turn` + the one-turn latency + SabotageJob, re-ran phase1
(PASS) then **phase3's regression test (`tests/test_phase3.gd`) hung and
was killed at the 2-minute timeout** — did not even print its usual
`aggregate: ...` line first. Have NOT root-caused this. Prime suspects,
next session:

1. An infinite or pathological loop somewhere touching `Job.assigned_turn`
   or the new `to_resolve` filter (`j.assigned_turn < ws.turn`) — e.g. if
   any code path sets `assigned_turn` incorrectly (or never advances it),
   a job could sit forever un-resolved without erroring, and something
   downstream might loop waiting on it.
2. `SabotageJob` or `Planner` interacting badly with phase 3's belief/
   transmission machinery in a way that's slow rather than infinite (100
   turns × 20 seeds with a new action + one-turn job latency roughly
   doubles job-related bookkeeping — could just be genuinely slower, not
   hung; worth trying a smaller turn count first to check before assuming
   a real loop).
3. Test phase4 regression (`test_phase4.gd`) was **not re-run** after the
   job-latency/Sabotage changes — do that too, it's the more likely one to
   show a real behavioral regression (inert characters, fill rate) since it
   exercises the scorer over the same economy phase 3 does not.

**Have not touched**: phase 5's own exit test hasn't been re-run since these
changes either (only ran it once, before the Sabotage pull-forward, where
it correctly failed for the reasons documented above).

## Next step when resuming

1. Debug the phase3 hang first — cheap check: run `test_phase3.gd` with a
   debug print of turn number, or temporarily cut SEEDS/TURNS down, to see
   whether it's slow-but-finite or genuinely stuck. `Job.assigned_turn` and
   the `to_resolve` filter in `turn.gd` are the newest code in that path.
2. Once phase 1/3/4 regressions are clean again, run `tests/test_phase5.gd`
   and iterate on tuning (`DEFAULT_PATIENCE`, `FRUSTRATION_THRESHOLD`,
   `PLAN_MIN_TERMINAL_SCORE`) the same way phase 4's `JOBS_PER_TURN` got
   tuned against its own exit test.
3. Write `tests/phase5_exit_test.sh` (doesn't exist yet) once the above
   passes, following `tests/phase4_exit_test.sh`'s shape.
4. Only then: phases 6 and 7, per demo_tasks.md, still fully unbuilt.
