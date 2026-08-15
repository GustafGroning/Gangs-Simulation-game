# Questions awaiting Gustaf

Single place for open questions. When answered: harvest into DECISIONS.md/canon/code, then delete the entry.

## 2026-08-15 — Phases 5-6 built in a sandbox with no Godot binary — NOTHING below has been executed
This entire pass (finishing phase 5, building all of phase 6) was written in
the `@claude` GitHub Actions sandbox, which — same as the 2026-08-14 entry
below — has no `godot` binary on PATH and no permitted package/network
access to install one, and this time additionally has no interactive Bash
approval available (every non-allowlisted shell command times out
unanswered), so not even a quick "does godot exist" probe was possible.
Per your issue instruction, validation was explicitly skipped and the work
proceeded anyway — but that means `tests/phase5_exit_test.sh` and
`tests/phase6_exit_test.sh` (both written this session) have **never been
run**, not even once, and neither have the phase 1/3/4 regressions this
session's edits touch (turn.gd's resolution loop, Beliefs, Traces,
assign_job.gd). Everything below is static-review-only. **First thing to do
on a local/Godot-capable session: run `tests/phase6_exit_test.sh` and
iterate on tuning** — I'd specifically watch:
- `deaths_per_100_turns` (target 2-6): tuned `RIVAL_HIT_SHARE=0.125` and
  `KILL_VENGEANCE_GATE=0.5` by reasoning, not measurement — very plausibly
  wrong in either direction.
- Whether the cast survives 200 turns at all — with only ONE rank-change
  mechanism (contest, no Advocate/Expansion) and now several ways to
  permanently remove people (Kill, Judgment KILLED/EXILED, arrest, rival
  hit), a 16-20 person cast could plausibly deplete over 200 turns. Nothing
  currently caps or replenishes population.
- Whether `Contest.run_all` firing on the deliberate starting vacancy from
  turn 1 onward (new behavior — no Advocate action exists in the 7-verb
  demo, so the automatic end-of-turn contest is now the ONLY way any
  vacancy fills) changes phase 1/3/4/5's regression numbers. Nothing in
  those phases' exit tests locked in "the starting vacancy stays open," but
  it's a real behavioral change to the shared turn loop worth a look.
- The phase-3 hang from the entry this replaces was never root-caused
  either (see thoughts/phase_5_planner.md) — if `test_phase3.gd` is still
  slow/stuck, it predates this session's changes.

## 2026-08-15 — Design gaps in this pass, needing your read
Several places where canon was vague enough that I made a call rather than
invent canon silently (per CLAUDE.md). All are comments in the code too;
listed together here for a single pass:
- **Kill's "opportunity or instrument" gate** (`sim/actions/kill.gd`) —
  read as: tree-adjacent (crew/patron — "opportunity") OR
  `vengeance >= KILL_VENGEANCE_GATE=0.5` ("instrument", i.e. motivated
  enough to have found one). Any crew/patron pair can currently kill each
  other with zero grudge as long as the scorer's utility clears risk — is
  proximity alone too permissive?
- **Dig is scoped to the belief's ACTOR field only** (`sim/actions/dig.gd`)
  — the Field enum (doc 1 §2) has no MOTIVE value and nothing populates
  INSTRUMENT yet, so "field: actor | instrument | motive | verify(field)"
  from design_doc.md's Dig spec is narrowed to ACTOR, which the doc itself
  calls the crux of the design. Add MOTIVE to the Field enum for a future
  pass, or is ACTOR-only sufficient for the demo?
- **Judgment DEMOTED with no vacant lower slot** (`sim/content/judgment.gd`
  `_demote`) — the schema has no "active but slot-less" CharState, so this
  falls back to EXILED. Judgment call under time pressure, not a canon
  answer.
- **Arrest is permanent, not "5-15 turns"** (`sim/content/exogenous.gd`) —
  same CharState gap (no state for "temporarily absent"); implemented as a
  permanent EXILED-equivalent removal instead of building a whole
  scheduled-return subsystem. Worth a real mechanism if arrests turn out to
  matter a lot for pacing.
- **Exogenous events step placement** — doc 3 §3 has no numbered slot in
  the GDD's 12-step turn order; placed at "1b", right after upkeep/before
  the job board, so the cast reacts to a fresh event the same turn. Turn.gd
  flags this too.
- **Only Rival Hit + Arrest built** of doc 3 §3's 8 exogenous kinds, per
  doc 5 phase 6 task 7's explicit "prioritise" instruction — the other six
  (police pressure, the big score, lean times, the informant, family
  trouble, outside offer) are BACKLOG.md, not built.

## 2026-08-15 — Phase 5 (RESOLVED — validated this session, statically): pulled SabotageJob forward from phase 6
Prior entry's resolution stands: `SabotageJob` was pulled forward from phase
6 into phase 5 (see DECISIONS.md and thoughts/phase_5_planner.md for the
original rationale — phase 5's own task list contradicted its Goal line,
and empirically zero plans formed under TakeJob/AssignJob alone once
`JOBS_PER_TURN=5`). `tests/phase5_exit_test.sh` was written this session to
close out the phase, but — see the entry above — it has not actually been
run. Still flagged for your review, now alongside phase 6's own judgment
calls.

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
