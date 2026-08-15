# Questions awaiting Gustaf

Single place for open questions. When answered: harvest into DECISIONS.md/canon/code, then delete the entry.

## 2026-08-15 — Phase 5: pulled SabotageJob forward from phase 6; PhaseTest run interrupted, unverified
Proceeding autonomously through phases 5-7 per instruction. Phase 5's own
task list contradicts itself: the Goal line says "still only the phase-2
verbs" (TakeJob/AssignJob), but the same phase's task list names the
escalation ladder "Sabotage → Frame → Kill". Empirically confirmed (real
test run) that this isn't just a wording slip: with only TakeJob/AssignJob,
AssignJob is almost never gated once `JOBS_PER_TURN=5` (required by phase
4's already-passing no-inert-characters band) — 18/20 seeds formed zero
plans. Phase 2/4's abundance requirement and phase 5's gating requirement
compete for the same resource, so phase 5 as literally scoped can't pass
its own exit test.

My call: pull `SabotageJob` forward from phase 6 (simplest hostile verb,
explicitly named in phase 5's own ladder text), which required adding one
turn of latency between job assignment and resolution (`Job.assigned_turn`)
so a job is ever observably "in progress" for anyone to sabotage. Full
rationale in thoughts/phase_5_planner.md. **This is a significant judgment
call under time pressure — please review whether pulling Sabotage forward
was the right resolution, versus e.g. loosening phase 5's exit-test bands
instead, or a different gating mechanism.**

Session was interrupted (Gustaf went to bed) immediately after this change,
mid-regression-testing — `tests/test_phase3.gd` hung and was killed at a
2-minute timeout, not yet root-caused. **Nothing from this entry has passed
validation.** See thoughts/phase_5_planner.md's "Where it broke off" section
for the exact resume point and suspects.

## 2026-08-14 — TakeJob's perceived detectability vs. actual detectability
`TakeJobAction`'s authored `trace_templates` (read by `Risk.perceived` for the
actor's own risk estimate) use a flat `Tuning.TAKEJOB_RISK_DETECT_ESTIMATE =
0.4` regardless of job kind. Actual trace emission at resolution
(`trace_specs()`) instead uses `Tuning.JOB_TRACE_DETECT[kind]`, which ranges
0.2–0.8 by kind plus a failure bonus. So a character's perceived risk of
taking a heist (true detectability 0.65) is understated, and collection
(true 0.2) is overstated. This could be intentional — actors don't know the
true per-kind number, so a flat estimate is itself a modeling choice about
imperfect self-knowledge — or it could be an oversight where the authored
template should vary by kind like the real one does. Left as a flat estimate
for now (only the magic-number literal was fixed, referencing the new
`Tuning.TAKEJOB_RISK_DETECT_ESTIMATE`); which reading do you want?

## 2026-08-14 — Environment: no Godot binary / no network in the GitHub Actions @claude sandbox
The `@claude` issue/PR automation runs in a sandboxed CI container with no
`godot` binary on PATH and no permitted network access to install one (`curl`,
`apt-cache`, etc. all require interactive approval that isn't available in
this non-interactive context). This means an agent triggered via a GitHub
issue can write GDScript but cannot run `tests/phase*_exit_test.sh` or any
headless sim command — which conflicts with this project's core validation
model ("most failures here are silent... never advance without a passing exit
test"). Options: bake a Godot 4.7 headless binary into the Actions runner
image/setup step, or treat `@claude` issue runs as code-writing/static-review
only and keep exit-test validation to local sessions. Which do you want?
(Update 2026-08-15: no longer blocking phase 4 specifically — a local
Godot-capable session ran `tests/phase4_exit_test.sh` and it now passes, see
thoughts/phase_4_scorer.md and DECISIONS.md. The underlying policy question
for future `@claude` runs stands.)

## 2026-08-14 — Job outcome bands vs. the resolution formula (doc 3)
Doc 3 §6 targets "roughly 30/30/30/10" across SUCCESS/PARTIAL/FAILURE/DISASTER,
but the §1 resolution formula (0.5 + (competence−difficulty)×weight + noise,
banded at 0.75/0.45/0.15) can't produce that split while competence stays
meaningful — hitting it needs noise so large that competence stops mattering.
Current tuning lands at ~28/45/24/3 with competence decisive (COMPETENCE_WEIGHT
raised to 1.0). Options: bless the current split, re-band (e.g. 0.72/0.5/0.2),
or say DISASTER should stay rare. Which do you want?

## 2026-08-14 — Standing runaway band vs. starting spread (doc 4 / doc 2)
Doc 4's health band "no character > 3× median standing" starts at ratio 2.4 on
turn 0 with doc 2's STANDING_BY_RANK [60,40,25,12] — the band leaves almost no
room and single seeds brush 3.0-3.1 with a stable, gini-0.32 economy. Applied
doc 4 §7's ">80% of runs in band" rule (held at 90%) instead of per-seed
perfection, and measured at end-state per doc 4 §2. OK, or should the band be
widened / made rank-relative?

## 2026-08-14 — gdai-mcp plugin copy is incomplete
Copied `addons/gdai-mcp-plugin-godot` from cozy-space as requested, and wrote `.mcp.json` pointing at the standard layout. But the cozy-space copy itself is missing the plugin's binaries: its own `.gitignore` excludes `bin/`, `*.gdextension`, and `*.py` (the MCP server script), and none of those exist on disk there either. The plugin's loader refuses to start without `bin/` ("Binary files ... are missing"), so enabling it in the editor will error until the full plugin (v0.3.2, gdaimcp.com) is re-installed into this project — cozy-space's `.mcp.json` also pointed at an old install path (`/Users/gustafgroning/Desktop/...`), suggesting the working install lived elsewhere. Once the full install is in place, the checked-in `.mcp.json` here should work as-is; if the server command differs, tell me and I'll update it.
