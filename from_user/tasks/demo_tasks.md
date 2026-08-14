# Gangs — Implementation Tasks

**Document 5 of 5.** The build plan. Written to be handed to an agent one phase
at a time.

Depends on: `gangs-state-schema.md` (1) · `gangs-character-gen.md` (2) ·
`gangs-content.md` (3) · `gangs-tuning-validation.md` (4) ·
`gangs-gdd.md` · `gangs-design.md` · `gangs-action-choice.md`

---

## How to use this document

**Do not hand the agent all seven documents and this task list at once.** Give
it the schema doc, the architectural rules, and *one phase*. Each phase has an
exit test; do not advance until it passes.

The reason is specific to this project: most failures here are silent. A phase
that "works" but quietly violates the belief-state boundary will look fine and
poison every measurement afterward. Small phases with hard exit tests are how
you catch that at the point it happens.

Phases 0–6 build a running simulation. **Phase 7 is the decision point.**
Phases 8+ only make sense if phase 7 says yes.

---

## Phase 0 — Skeleton and conventions

**Goal:** the project runs headless, deterministically, and does nothing.

Tasks:

1. `sim/` module structure per doc 1 §4. Empty files with `class_name`
   declarations.
2. `sim/enums.gd` — all enums from doc 1 §2.
3. `sim/rng.gd` — `Rng.shuffle`, `Rng.pick`, `Rng.weighted_pick`,
   `Rng.randfn`, all taking an explicit `RandomNumberGenerator`.
4. `config/tuning.gd` — every constant from doc 4 §1, with defaults.
5. `main.gd` headless entry point with CLI arg parsing:
   `--seed --turns --config --out --sweep --vary`.
6. `CLAUDE.md` at repo root containing doc 1 §4 "Hard architectural rules"
   **verbatim**, plus the determinism rules from doc 1 §1.
7. CI grep script: fails the build on `randi(`, `randf(`, `randi_range(`,
   `.shuffle()`, `.pick_random()`, `OS.get_ticks`, `Time.` anywhere under
   `sim/`.

**Exit test:** `gangs --seed 1 --turns 0` runs headless and exits clean. The CI
grep passes.

---

## Phase 1 — State and invariants

**Goal:** the world can be represented and validated. Still no behaviour.

Tasks:

1. All core structs from doc 1 §3: `Character`, `Relationship`, `Event`,
   `Trace`, `Belief`, `Plan`, `PlanStep`, `ActionCandidate`, `Slot`,
   `WorldState`.
2. `to_dict()` / `from_dict()` on every struct.
3. `world.gd` accessors: `opinion_of(a,b)`, `patron_of(c)`, `crew_of(c)`,
   `slot_of(c)`, `resync_tree()`, `pair_key()`. **All relationship and tree
   access goes through these** — no raw dictionary indexing in game logic.
4. `World.assert_invariants()` — all ten from doc 1 §6.
5. Debug access flag on `WorldState.events` (doc 4 §3): set on read, with
   `assert_ai_clean()` to check and reset.
6. Hand-build a 5-character fixture world in a test.

**Exit test:** fixture world passes all invariants; serializes and deserializes
to an identical state; deliberately corrupting each invariant makes exactly one
assertion fire.

---

## Phase 2 — Turn loop and the job economy

**Goal:** a world that runs, with jobs but no politics and no AI. This is the
content smoke test from doc 3 §6.

Tasks:

1. `turn.gd` — the 12-step resolution order from the GDD, with steps that have
   no implementation yet stubbed and clearly marked.
2. Resolution priority ordering: `Command → Cover → Earn → Strike → Court →
   Whisper → Learn`.
3. `content/jobs.gd` — `Job` struct, six kinds, generation, expiry,
   resolution per doc 3 §1.
4. Two actions only: `TakeJob`, `AssignJob`. Assignment is random at this stage,
   not chosen.
5. Standing and money effects; job expiry penalties.
6. `heat.gd` — accumulation and decay per doc 3 §5.
7. `log/chronicle.gd` — basic turn output.
8. `log/metrics.gd` — economy metrics only (doc 4 §2).

**Exit test:** doc 3 §6 content smoke test passes over 20 seeds × 100 turns.
Specifically: standing does not run away, no character goes permanently inert,
job fill rate > 0.8, all jobs resolve or expire.

> If standing runs away here, stop. No amount of AI tuning will fix an unstable
> economy, and every measurement you take afterward will be contaminated.

---

## Phase 3 — Information layer

**Goal:** events emit traces, traces are found, beliefs spread and mutate.
Still no decision-making.

This is the highest-risk phase and the one to review most carefully.

Tasks:

1. `TraceTemplate` and emission — traces are emitted by the turn loop from
   `action.trace_templates`, **never by actions themselves**.
2. Trace decay and removal (`TRACE_DECAY_RATE`, `TRACE_MIN_DETECT`).
3. `info/traces.gd` — detection roll: `detectability × observer_density ×
   heat_multiplier`, modified by `OBSERVANT`.
4. `info/beliefs.gd` — belief creation from found traces. **Traces revealing
   only ACTION and TARGET must produce a belief with no ACTOR claim.** Verify
   this explicitly; it is the crux of the entire design.
5. Transmission: hop decay, `ACTOR_MUTATION_CHANCE`, motive-biased mutation
   toward plausible suspects.
6. Upward reporting per GDD: recipient selection (not pass/fail),
   self-implication suppression, superior attention budget.
7. Belief-layer invariants from doc 4 §3.

**Exit test:** with random job assignment and one scripted sabotage per 10
turns, over 20 seeds:

- beliefs about the sabotages exist and are unevenly distributed
- `misattribution_rate` > 0.15
- at least 3 confident falsehoods per 100 turns
- no belief exists without a backing event or `fabricated`
- a disloyal subordinate's report demonstrably reaches a rival rather than
  their patron

> This exit test is the real gate on the project. If the belief layer cannot
> manufacture confident false attributions from scripted inputs, it will not do
> it from emergent ones, and the design needs revisiting before any AI work.

---

## Phase 4 — Scorer

**Goal:** characters choose actions. Still only the phase-2 verbs.

Tasks:

1. `actions/action.gd` — the contract from doc 1 §5.
2. `actions/registry.gd` — id → Action, asserts on unknown ids.
3. `ai/attention.gd` — attention set construction per action-choice doc §1.
4. `ai/candidates.gd` — gate-first generation, lazy visibility/instrument
   expansion.
5. `ai/risk.gd` — `P_detected × P_attributed × severity`, **derived from trace
   templates**. Trait distortions applied here.
6. `ai/scorer.gd` — utility from `evaluate()`, plus risk, affinity. Populates
   `contributions`. **Hard error on any magnitude outside −1..1.**
7. `ai/selection.gd` — softmax over top N, per-character temperature,
   repetition penalty.
8. `ai/weights.gd` — weight dynamics table and decay toward `goal_baseline`.
9. Chronicle emits the top two contributing terms per action.

**Exit test:** with only TakeJob and AssignJob, characters differentiate —
`action_entropy` > 1.0, assignment choices correlate with `vengeance`, and
`assert_ai_clean()` never fires.

---

## Phase 5 — Planner

**Goal:** characters invest across turns.

Tasks:

1. `ai/planner.gd` — plan generation from gated terminal actions, backward
   chaining to preconditions, `MAX_PLAN_DEPTH`.
2. Discounted step scoring: `γ^steps_remaining × terminal_score`.
3. Continuation bonus, abort conditions, patience.
4. Frustration counter and the escalation ladder
   (`Sabotage → Frame → Kill`).
5. Chronicle prints active plans and their step index.

**Exit test:** `mean_plan_length_at_execution` > 1.8; `plan_completion_rate`
between 0.25 and 0.6; a chronicle shows at least one multi-turn plot whose
steps are legible in sequence.

---

## Phase 6 — The demo verb set

**Goal:** the full falsification demo.

Add the remaining five actions, in this order:

1. `SabotageJob` — the first hostile action. Verify traces and the
   failure-attribution asymmetry from doc 3 §1.
2. `Dig` — four outcomes including false-resolve; **emits its own trace**.
3. `SpreadRumor` — transmission with chosen targets.
4. `Denounce` + Judgment per doc 3 §4. **Judgment reads the judge's beliefs and
   never checks actual guilt.**
5. `Kill` — removal, vacancy contest, heat.

Then:

6. Vacancy contest per doc 3 §2, including losers taking
   `Vengeance[winner]`.
7. Exogenous events per doc 3 §3 — prioritise **rival hit** and **arrest**,
   which are the two that matter most for texture.
8. Full metrics suite from doc 4 §2.

**Exit test:** all doc 4 §7 criteria across 20 seeds × 200 turns.

---

## Phase 7 — Generation and the decision point

Character generation depends on the turn loop (history via simulation), which
is why it comes here rather than at the start.

Tasks:

1. `gen/world_gen.gd` — tree topology, slot construction.
2. `gen/character_gen.gd` — names, traits with exclusions and distribution
   floors, temperature, competence, polarized goal weights.
3. Slot assignment by fitness; starting standing and money.
4. History generation via `history_mode = "simulate"` — 15 turns with Kill and
   Denounce disabled.
5. Relationship derivation, including the sibling bias.
6. The six planted hooks.
7. Generation smoke test from doc 2 §10, including the goal-variance assertion.
8. `world_summary.txt` output.

Then the harness:

9. Sweep runner, parameter sweep (`--vary`), golden-file regression.
10. **The ablation suite from doc 4 §6 — run the belief-layer ablation first.**

### The decision point

Read three chronicles at random and answer:

1. Can you reconstruct why each major event happened?
2. Did at least one misattribution cascade occur?
3. Did anything surprise you?
4. Does the belief-layer ablation show materially worse metrics than baseline?

If 1–3 are yes and 4 is yes, the design is validated and phases 8+ are worth
building.

If 4 is **no** — the sim is just as good with the AI reading ground truth —
stop and rework the information model. That is the most valuable negative
result available here, and it is cheap at this point and ruinous later.

---

## Phase 8+ — Beyond the demo

Only after phase 7 passes. Sketched, not specified.

- **8.** Player input: the same candidate generator feeding a UI instead of the
  scorer. The player must be subject to identical gates.
- **9.** The remaining ~28 actions from the GDD action list, in tag groups.
  Court and Cover first — they are what make quiet turns viable.
- **10.** Money systems: Buy Alibi, Buy Silence, debt-as-motive, traceable
  wealth.
- **11.** The remaining rank-change mechanisms: Advocacy, Challenge,
  Succession, Defection.
- **12.** Tree visualization and the end-of-turn report UI. The chronicle
  format is already the spec for this.

---

## Standing instructions for the agent

Include these with every phase.

1. **Read `CLAUDE.md` first.** The architectural rules are not negotiable and
   not subject to convenience.
2. **No magic numbers.** Every tunable value goes in `config/tuning.gd`. If a
   number is needed that isn't there, add it there with a comment, don't inline
   it.
3. **Actions never reference other actions by name.** The scorer never branches
   on action identity.
4. **All AI reads belief state.** `world.events` is off-limits under `ai/`. If
   a decision seems to require ground truth, the decision is wrong — flag it
   rather than working around it.
5. **All randomness through `world.rng`.** No exceptions.
6. **Every comparator breaks ties on `id`.** Godot's sort is not stable.
7. **Write the exit test before the implementation** for each phase.
8. **Do not advance phases.** Stop at the exit test and report.
9. **Assertions over silent clamping.** Out-of-range values are bugs to
   surface, not values to fix quietly.
10. **When a document and your judgment conflict, say so rather than
    silently resolving it.** These documents are drafts and several numbers are
    guesses; a flagged disagreement is useful, a silent deviation is not.

---

## Rough sequencing

| Phase | Content | Risk |
|---|---|---|
| 0 | Skeleton | Low |
| 1 | State | Low |
| 2 | Turn loop + jobs | Medium — economy stability |
| 3 | Information layer | **Highest — the design gate** |
| 4 | Scorer | Medium |
| 5 | Planner | Medium — tempo problem lives here |
| 6 | Demo verbs | Medium |
| 7 | Generation + decision | — |

Phases 2, 3 and 5 are where the project is most likely to go wrong, and each
has a specific known failure: runaway standing, decorative beliefs, and turn-one
bloodbath respectively. All three are called out in the exit tests because all
three are silent.