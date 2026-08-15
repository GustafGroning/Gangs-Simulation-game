# Technical decisions

Newest first. Each entry: what was decided, and why.

## 2026-08-15 — Phase 6 (UNVALIDATED — see QUESTIONS.md's sandbox entry)

Built in the `@claude` GitHub Actions sandbox with no Godot binary and no
interactive Bash approval — everything below is static review, never run.
Finishes phase 5 (writes the exit test only — the code was already there)
and builds all of phase 6: the last three demo verbs, Judgment, the vacancy
contest, and Rival Hit/Arrest.

- **`Character.credibility: float = 1.0`** — new field, not in doc 1's
  schema. Doc 3 §4: "a DISMISSED verdict damages the accuser's credibility,
  reducing the weight of their future beliefs during transmission"; reused
  for a collapsed Dig's source too. Multiplies confidence in
  `Beliefs.transmission`/`upward_reporting`/`deliver_chosen`. I7 range-checked
  like every other 0..1 field.
- **`World.scrub_relationships(ws, char_id)`** — new helper, called
  whenever a character becomes DEAD (Kill, Judgment KILLED, Rival Hit).
  Invariant I9 forbids a relationship referencing a DEAD character (EXILED
  is fine); nothing previously removed a character mid-run, so this gap
  was latent until Kill existed.
- **Actor-liveness re-check added to turn.gd's resolution loop**
  (`if actor.state != E.CharState.ACTIVE: continue`) — Kill can now remove
  a character mid-turn (a higher-priority action executing before a
  lower-priority one queued by the same now-dead actor). Same idea as the
  existing `requires()` re-check (invariant I3), just covering the actor's
  own liveness, which no `requires()` implementation checked before because
  nothing could previously die mid-turn. `AssignJob.requires()`/
  `gated_recoverably()` got the equivalent target-liveness check for the
  same reason (a target could now die between candidate generation and
  execution).
- **`Job.resolve()` guards a since-removed worker** — a job's worker can
  now die/be exiled/arrested in the one turn between assignment and
  resolution (phase 5's latency). Resolving against them would silently
  credit/penalize a no-longer-active character; instead the job is marked
  `resolved` with `PENDING` outcome and a new `jobs_abandoned` metric, no
  event side effects.
- **Vacancy contest wired into every turn (`Contest.run_all`, turn step
  10)** — runs for EVERY currently-vacant slot, including the deliberate
  starting rank-2 vacancy from `WorldGen.bootstrap`. There is no Advocate
  action in the 7-verb demo, so this is now the ONLY way any vacancy ever
  fills — meaning the starting vacancy will be contested and filled from
  turn 1 onward, a real behavioral change to the shared turn loop that
  phases 1-5's existing regression tests were never run against post-change
  (see QUESTIONS.md).
- **Exogenous events placed at turn step "1b"**, right after upkeep/trace
  decay and before the job board — doc 3 §3 doesn't assign a numbered slot
  in the GDD's 12-step order. Placed early so the cast's own action
  selection that turn reacts to a fresh rival hit/arrest.
- **`RIVAL_HIT_SHARE = 0.125`** — doc 3's `EXO_BASE_CHANCE=0.15` is
  specified against the FULL 8-kind exogenous table ("roughly one shock
  every 6-8 turns"); only Rival Hit is implemented as a base-chance roll
  (Arrest is independently triggered by heat/DISASTER), so using
  `EXO_BASE_CHANCE` at face value for Rival Hit alone would fire ~8x doc
  3's intended overall cadence. Scaled by 1/8 as a placeholder weighting
  until more exogenous kinds exist. Unverified — see QUESTIONS.md.
- **Arrest and Judgment DEMOTED (no vacant lower slot) both resolve to a
  permanent EXILED-equivalent removal** — the schema's `CharState` enum
  (ACTIVE/DEAD/EXILED) has no state for "temporarily absent" or "active but
  slot-less" (invariant I6 forbids the latter). Both are judgment calls
  under time pressure, not canon answers — see QUESTIONS.md.
- **Dig scoped to the belief's ACTOR field only** — `E.Field` has no MOTIVE
  value and nothing populates INSTRUMENT; ACTOR is what design_doc.md calls
  "the crux of the entire design", so Dig resolves/corroborates/collapses/
  false-resolves a belief's ACTOR claim and nothing else.
- **`Beliefs.pick_plausible_suspect` extracted from `_mutate_claim`** — the
  "who looks guilty" motive-weighted pool/pick logic is identical between
  passive gossip mutation/speculation and Dig's false-resolve (the doc says
  so explicitly: "same mutation logic as rumor transmission"), so it's one
  function now, called from both `beliefs.gd` and `dig.gd`.
- **`ESCALATION_LADDER` extended to `assign_job -> sabotage_job -> kill`**,
  with a second dict entry keyed by `sabotage_job` pointing at the same
  array — `Planner._try_escalate` looks the ladder up by the plan's
  CURRENT `goal_action`, not its original starting action, so every rung
  except the last needs its own key or an already-escalated plan can never
  climb again (this was fine before by accident: the old 2-rung ladder never
  needed a second key since sabotage_job had nowhere further to go).
- **Only Rival Hit and Arrest built** of doc 3 §3's 8 exogenous event kinds
  — doc 5 phase 6 task 7 explicitly says to prioritise these two; the other
  six are BACKLOG.md.
- **Expansion/Contraction (doc 3 §2) not built** — design_doc.md's "Demo
  scope" section is explicit: "Rank change: one mechanism only — Removal ->
  contest." Only the contest exists; slot count is fixed for the whole run.

## 2026-08-15 — Phase 4 (validated)

- **`JOBS_PER_TURN` raised 3→5.** The phase-4 scorer replaced the phase-2
  scaffold's assignment policy — which had an explicit longest-idle
  anti-starvation tiebreak — with deterministic goal-driven best-fit choice.
  Under the scorer, the same low-fit rank-3 characters (fewest eligible job
  kinds, per doc 3's rank bands, and the largest population) kept losing the
  same jobs to the same competitors every turn; at `JOBS_PER_TURN=3`, 11/20
  seeds had a character idle 20+ consecutive turns. `5` clears it in all 20.
  Judgment call, not a canon value — see thoughts/phase_4_scorer.md.
- **`test_phase4.gd`'s vengeance-hit-rate counters fixed**: GDScript lambdas
  capture value-type locals (int/float/bool) by value, not by reference: a
  closure incrementing an outer `int` mutates its own snapshot only. Counters
  now live in a Dictionary (a reference type) so mutations are visible
  outside the closure. This was a test-authoring bug, not a scorer bug — the
  vengeance-driven assignment mechanic was correct throughout; the test just
  never reported the real number (76% grudge-target hit rate once fixed).

## 2026-08-14 — Phase 3

- **Trace decay is subtractive** (detectability − 0.06/turn): traces die in
  ~8 turns, which is the urgency the design wants ("cold cases go cold");
  multiplicative decay would keep them alive ~50 turns.
- **Speculation added to actor mutation**: a transmitted claim with NO actor
  field can grow one (ACTOR_SPECULATION_CHANCE, motive-weighted). Without
  it, no misattribution can exist before Dig (phase 6) — canon's "rumors
  drift toward whoever already looks guilty" is the license.
- **Siblings start with known_motive 0.3** — doc 2 derives known_motive from
  public hostile events, which don't exist at bootstrap; sibling rivalry is
  structurally public. Gives motive-biased mutation something to bite on.
- **Trace template lookup lives in `Traces.templates_for` until phase 4**,
  then moves onto Action classes per the contract.
- **All belief updates funnel through `Beliefs._merge`** — corroboration
  (same name, different source: +0.1) and conflict (higher confidence wins,
  −0.05 certainty) live in exactly one place.
- **Expired traces are physically removed** (dict + traces_by_event) rather
  than flagged — deterministic, keeps state small; `destroyed` stays for the
  future Destroy Evidence action.
- **mean_belief_accuracy has no phase-3 gate** — doc 5's phase 3 exit list
  doesn't include it; its doc-4 band presumes Dig exists. Metrics report
  overall and hostile-only accuracy separately.

## 2026-08-14 — Phase 2

- **`heat.gd` lives in `sim/content/`** (doc 5 names the file, doc 1's layout
  omits it; doc 3 specs heat as content).
- **`JobOutcome` lives in `sim/enums.gd` (`E`)** — doc 3 defines it standalone,
  but doc 1 §2 makes `E` the single home for enums.
- **Standing mechanics in `World.add_standing`**: floor at 0; gains diminish
  linearly from STANDING_SOFT_KNEE to zero at STANDING_SOFT_CAP (doc 1
  declares a soft cap without a mechanism); losses scale with
  standing/knee (floored at 0.25) so one bad job can't erase a nobody.
  Without the loss scaling the cast median collapses and doc 4's runaway
  band is unmeetable.
- **`standing_runaway` is an end-of-run metric** (doc 4 §2: metrics computed
  from the end-state); the worst transient ratio ships in metrics.json as
  `runaway_ratio_max_transient` for diagnostics.
- **Smoke-test bands follow doc 4 §7**: statistical bands must hold in ≥90%
  of seeds (doc says >80%); structural checks (determinism, leaks,
  invariants, inert) hold in 100%.
- **Tuning deltas from doc-4 defaults**, each with a rationale comment in
  tuning.gd: JOBS_PER_TURN 2→3, COMPETENCE_WEIGHT 0.6→1.0, PARTIAL standing
  0.5×. Job expiry penalizes the boss (canon silent on "responsible
  superior").
- **Scaffold selection policy** (pre-scorer): superiors assign at 0.8
  probability, weighted by crew idleness × job fit (squared); contested
  takes go to the longest-idle. Replaced wholesale by the scorer in phase 4.

## 2026-08-14 — Phase 1

- **Test scripts run `godot --headless --import` before executing.** Global
  `class_name` resolution depends on `.godot/global_script_class_cache.cfg`,
  which headless runs do not regenerate on their own — without the import
  step, freshly added classes fail to resolve. Every phase exit-test script
  starts with it.
- **`Config` is a minimal placeholder** (`{name}`): doc 1 §3 types
  `WorldState.config: Config` but never defines the struct. Tunables stay in
  the static `Tuning` class; `Config` will grow run parameters with the
  sweep harness (phase 7).
- **Invariants I3/I4 are execution-time contracts**, enforced where actions
  execute and score (phases 4+) — they are not decidable from a state
  snapshot, so `World.check_invariants` covers the eight that are.
- **JSON-safe serialization:** int dict keys and int values are normalized
  back by `from_dict` (JSON makes them strings/doubles); the RNG state is
  serialized as a string because it is a 64-bit int and JSON numbers are
  doubles.

## 2026-08-14 — Phase 0

- **CI grep matches *global* RNG calls only.** The regex flags `randf(` etc. when not preceded by `.`, so `rng.randf_range(...)` on the explicit `RandomNumberGenerator` stays legal — the Rng helpers couldn't exist otherwise. `func` definition lines are filtered so `Rng.randfn` can be declared. Array's banned methods are matched by their zero-arg signature (`.shuffle()`), which distinguishes them from `Rng.shuffle(arr, rng)`. Known gap: a global call on the same line as a `func` definition would slip through; accepted as unrealistic.
- **Headless entry via `SceneTree` script.** `main.gd` extends `SceneTree`, run as `godot --headless --script main.gd -- <args>`; args read from `OS.get_cmdline_user_args()`. The `./gangs` wrapper resolves the engine binary: `$GODOT` env var → `godot` on PATH → `/Applications/Godot.app` (Gustaf's machine).
- **`config_hash`** = first 12 hex chars of sha256 over the sorted-key JSON of `tuning.gd`'s constant map, loaded by path (not class_name) so a stale global-class cache can't break it. Any tuning edit changes the hash, which is what makes `(seed, config_hash)` identify a run.
- **Unimplemented CLI paths exit nonzero** (usage errors → 2, not-yet-built features → 3) instead of silently no-opping — per "assertions over silent clamping". Today only `--turns 0` with `--config default` runs.
- **`Rng.weighted_pick(arr, weights, rng)` returns the element**, taking a parallel weights array; asserts on size mismatch, negative weights, and zero total.
- **Added `sim/trace_template.gd`** for `TraceTemplate`: doc 1 §5 defines the class but §4's file layout doesn't name a file for it. One class per file, next to the other structs.
