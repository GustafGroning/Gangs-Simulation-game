# Gangs! — a social simulation

## The game in five lines
1. A sandbox, turn-based social simulation. The player is a member of a criminal organization rendered as a tree of nodes. The only goal: climb the ranks, then keep your place. No map, no economy layer, no combat — the tree is the entire game.
2. Core design: the **information model**. Events (ground truth) emit Traces (evidence); characters hold Beliefs (partial, possibly wrong claims). Most traces reveal *what* happened but not *who* — that gap is where the entire game lives. **All AI acts on beliefs, never ground truth.**
3. Every character, player included, picks one action per turn from the same rule set. NPCs choose via a utility scorer (goals × action.evaluate − perceived risk + traits + plan commitment, softmax never argmax). Actions gate on social state, not cooldowns.
4. The fun is in the *reads*, not the verbs — feed Marco the right rumor and he does your dirty work. Misattribution is a feature: `misattribution_rate > 0.15` is the single most important metric.
5. Current scope: the **falsification demo** — headless, no graphics, no player. Seven verbs, 12–20 characters, 100–200 turns, a readable chronicle. Built in phases 0–7 per `from_user/tasks/demo_tasks.md`; **phase 7 is the decision point**. Everything beyond (player input, full verb set, UI) waits until it passes.

## Canonical documents (read as needed)
All design docs live in `from_user/` — **DESIGN CANON**, edits need Gustaf's sign-off. They cross-reference each other by their original names; the mapping:

| File | Referenced as | Contents |
|---|---|---|
| `from_user/design_doc.md` | `gangs-gdd.md` | Game flow, turn resolution order, resources, progression, the full action list |
| `from_user/other_design_stuff.md` | `gangs-design.md` | Core design notes: the information model (Events/Traces/Beliefs), grounding invariant, prior art |
| `from_user/npc_action_logic.md` | `gangs-action-choice.md` | The scorer pipeline: attention sets, candidates, risk, plans, selection, weight dynamics, failure modes |
| `from_user/schema_and_conventions.md` | doc 1, `gangs-state-schema.md` | **THE CONTRACT.** Every struct, enum, module boundary, invariant. Nothing else may invent a data structure. Read first. |
| `from_user/characters_and_world_generation.md` | doc 2, `gangs-character-gen.md` | Tree topology, character gen, history simulation, planted hooks |
| `from_user/jobs_slots_and-exogenous-events.md` | doc 3, `gangs-content.md` | Jobs, the slot economy, exogenous events, Judgment, heat |
| `from_user/constants_and_validation.md` | doc 4, `gangs-tuning-validation.md` | Every tunable constant, metrics, runtime assertions, the sweep harness, ablations |
| `from_user/tasks/demo_tasks.md` | doc 5 | **The build plan.** Phases 0–7, each with a hard exit test. Includes the 10 standing instructions — follow them every phase. |

Per doc 5: don't hold all seven documents in your head at once — work from the schema doc, this file, and the *current phase*, pulling the others as the phase references them.

Living files at repo root (create on first use):
- `DECISIONS.md` — technical decisions with rationale. `BACKLOG.md` — side findings + everything out of scope.
- `QUESTIONS.md` — the **single place for questions awaiting Gustaf**. If canon is genuinely silent, implement the closest reading, record the assumption, log the question — never invent canon, never idle waiting for an answer. When an answer lands, harvest it into DECISIONS.md/canon/code and delete the entry. Check it before starting substantial work.
- The design docs are drafts and several numbers are guesses — **when a document and your judgment conflict, say so rather than silently resolving it.** A flagged disagreement is useful; a silent deviation is not.
- `thoughts/` — research notes, plans, and per-phase reports. Scale depth to the task, but leave a record.

## Language
All documents, code comments, commit messages, and identifiers are written in **English**. Gustaf may write to you in Swedish — reply as usual, but everything written to the repo is English.

## Godot conventions
- **Godot 4.7, GDScript, static typing everywhere** (`var standing: float = 0.0`). File names in snake_case, `class_name` on every core type.
- **The sim layer is headless.** All sim classes extend `RefCounted`, not `Node` — the simulation must run under `--headless` with no scene tree dependency. Module layout per doc 1 §4 (`sim/`, `sim/actions/`, `sim/ai/`, `sim/info/`, `sim/gen/`, `sim/content/`, `sim/log/`, `sim/config/`).
- Core structs are **classes, not Dictionaries**; Dictionaries only for id-keyed collections. All cross-references by **integer id** (`-1` = none, never `null`), never object reference. Ids never reused.
- Every struct implements `to_dict()` / `static from_dict()` — snapshot testing and replay depend on it.
- **Assertions over silent clamping.** Out-of-range values are bugs to surface, not values to fix quietly. `World.assert_invariants()` runs every turn in debug.
- No autoloads in the sim layer. No magic numbers: **every tunable value lives in `config/tuning.gd`** — if a number you need isn't there, add it there with a comment, don't inline it.

## Hard architectural rules (doc 1 §4 — verbatim, non-negotiable)
1. **Actions never reference other actions by name.** No `if action == &"kill"` inside another action.
2. **The scorer never branches on action identity.** It calls `action.evaluate()` and does arithmetic. If you find yourself writing `match action:` in `scorer.gd`, the design has leaked.
3. **All AI reads belief state, never ground truth.** `WorldState.events` is off-limits to anything under `ai/`. Enforce with a review rule and, if feasible, an assertion in the scorer that it only touched `character.beliefs`.
4. **Risk is derived from trace templates, never authored per action.**
5. **All tunable numbers live in `config/tuning.gd`.** No magic floats in logic files.
6. **Every randomness call goes through `world.rng`.**

Rule 3 is the one an agent is most likely to break, because reading ground truth makes the AI "smarter" and every symptom of the violation looks like an improvement. If a decision seems to require ground truth, the decision is wrong — flag it rather than working around it.

## Determinism (doc 1 §1 — non-negotiable)
The sim must be exactly reproducible from a seed; a run is identified by `(seed, config_hash)`.
1. **One `RandomNumberGenerator` instance**, owned by `WorldState`, seeded once at startup. Passed explicitly to anything that needs randomness.
2. **`randi()`, `randf()`, `randi_range()` and friends are banned.** They use the global RNG. Add a CI grep for them.
3. **`Array.shuffle()` and `Array.pick_random()` are banned** — same reason. Use `Rng.shuffle(arr, rng)` and `Rng.pick(arr, rng)` helpers.
4. **`sort_custom` is not stable in Godot.** Every comparator must break ties on `id` so ordering is total and deterministic.
5. **Dictionary iteration is insertion-ordered in GDScript** and therefore safe — but do not rely on it for anything semantically meaningful. If order matters, sort explicitly.
6. **No `Time`, no `OS.get_ticks_*`, no frame counts** anywhere in sim logic.
7. Turn number is the only clock.

CI: the grep script (bans the calls above under `sim/`) plus the same-seed → identical-event-ledger-hash check on every commit.

## Running & validating
No scenes — validation is running the sim headless and reading the numbers: CLI + asserts + metrics. The `gdai-mcp` editor plugin (in `addons/`, registered in `.mcp.json`) can inspect the editor when it's open on Gustaf's machine, but the sim never depends on it — all exit tests must pass from the CLI alone.

- Single run: `--seed N --turns N --config default --out runs/` → `chronicle.txt`, `metrics.json`, `events.jsonl`, `world_summary.txt`, `final_state.json`.
- Sweeps: `--sweep --seeds 1..50` and `--vary CONSTANT=a,b,c` (doc 4 §4). Tune against the *fraction of runs failing each target band*, not the mean. Golden-file regression on three fixed seeds.
- **Every phase has an exit test (doc 5). Write it before the implementation. Do not advance phases — stop at the exit test and report.** Most failures here are silent: the sim keeps running and the output is just boring. The exit tests and doc 4's metrics/assertions exist to catch exactly that.
- The chronicle is the game's core output and Gustaf's manual-test surface — every line names its top two contributing terms, beliefs are printed distinct from ground truth, misattributions are flagged. If reading it is a chore, the game will be too.

## Work modes
- **Default to shipping — within the current phase.** A task is a request to build it: research, plan, implement, validate against the exit test, then report. Don't ask "should I start?", don't stop after the plan. The phase gate is the one hard stop: passing an exit test ends the run; the next phase is a new go from Gustaf. He'll say "just research this" or "plan only" when he wants a partial run — and asking is still right when a choice would send the work down materially different paths, or when an action is destructive or hard to reverse.
- **Document every task regardless.** `thoughts/` files, `DECISIONS.md`, `BACKLOG.md`, `QUESTIONS.md`. Scale the depth to the task's size, but leave a record.
- **Local sessions (Gustaf at the computer) are the primary mode.** Headless sim means cloud/CI agents can validate almost everything too — but exit-test verdicts and chronicle readability calls stay with local sessions and Gustaf.
- **GitHub issues + @claude are the away mode** — self-contained fixes Gustaf files for when he's not at the computer. Nothing runs until he mentions @claude; the PR is where review happens.
