# Technical decisions

Newest first. Each entry: what was decided, and why.

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
