# Gangs — State Schema & Conventions

**Document 1 of 5.** This is the contract. Every other document and every
implementation task references the names defined here. Nothing else may invent
a data structure.

Target: **Godot 4 / GDScript**, headless (`--headless`, no scene tree
dependency in the sim layer).

Companions: `gangs-gdd.md` · `gangs-design.md` · `gangs-action-choice.md`

---

## 0. Glossary

These words are used interchangeably in casual speech and mean different things
here. Do not substitute them.

| Term | Meaning |
|---|---|
| **Standing** | A character's reputation score. Continuous float. |
| **Rank** | Discrete depth in the tree. Changes only via a rank-change mechanism. |
| **Slot** | A position in the tree. May be occupied or vacant. |
| **Opinion** | Directed feeling of A toward B. A scalar on a relationship. |
| **Loyalty** | A *goal weight* indexed by target. Drives protective behaviour. Not opinion. |
| **Vengeance** | A *goal weight* indexed by target. Drives hostile behaviour. Not negative opinion. |
| **Patron** | The character directly above you in the tree. |
| **Crew** | The characters directly below you. |
| **Event** | Ground truth. Something that actually happened. |
| **Trace** | Evidence emitted by an event. The only channel for learning. |
| **Belief** | One character's claim about an event. May be wrong. |
| **Heat** | Organization-wide suspicion level. Suppresses plots. |
| **Attention set** | The ~6 characters a given character is considering this turn. |

Note the deliberate split: **opinion is how I feel about you; loyalty and
vengeance are what I am willing to do about it.** A character can dislike their
patron (low opinion) and still be structurally loyal (high `Loyalty[patron]`).

---

## 1. Conventions

### Language and structure

- All sim classes extend `RefCounted`, not `Node`. The simulation must run with
  no scene tree.
- **Typed fields everywhere.** `var standing: float = 0.0`, not `var standing`.
- Core structs are **classes, not Dictionaries**. Dictionaries only for
  id-keyed collections.
- All cross-references are by **integer id**, never object reference. This
  keeps serialization trivial and avoids cycles.
- `class_name` on every core type.

### Identity

- Ids are monotonically increasing `int`, assigned by `WorldState` counters.
- `id == -1` means null/none. Never use `null` for a missing id.
- Ids are never reused, including after a character dies.

### Determinism — non-negotiable

The sim must be exactly reproducible from a seed. This is what makes tuning
possible: without it you cannot tell whether a change helped or you got a
different roll.

Rules:

1. **One `RandomNumberGenerator` instance**, owned by `WorldState`, seeded once
   at startup. Passed explicitly to anything that needs randomness.
2. **`randi()`, `randf()`, `randi_range()` and friends are banned.** They use
   the global RNG. Add a CI grep for them.
3. **`Array.shuffle()` and `Array.pick_random()` are banned** — same reason.
   Use `Rng.shuffle(arr, rng)` and `Rng.pick(arr, rng)` helpers.
4. **`sort_custom` is not stable in Godot.** Every comparator must break ties
   on `id` so ordering is total and deterministic.
5. **Dictionary iteration is insertion-ordered in GDScript** and therefore
   safe — but do not rely on it for anything semantically meaningful. If order
   matters, sort explicitly.
6. **No `Time`, no `OS.get_ticks_*`, no frame counts** anywhere in sim logic.
7. Turn number is the only clock.

A run is identified by `(seed, config_hash)`. Print both in the log header.

### Numeric ranges

| Quantity | Range | Notes |
|---|---|---|
| Opinion | −1.0 .. 1.0 | Clamped |
| Goal weights | 0.0 .. 1.0 | Clamped |
| Confidence | 0.0 .. 1.0 | |
| Standing | 0.0 .. ~100.0 | Unbounded above in principle, soft-capped |
| Utility magnitudes | −1.0 .. 1.0 | **Enforced.** See action contract. |
| Money | int, may be negative | |
| Heat | 0.0 .. 1.0 | |

---

## 2. Enums

Defined in `sim/enums.gd` as a single autoload-free static class.

```gdscript
class_name E

enum Goal { AMBITION, SECURITY, WEALTH, STANDING, LOYALTY, VENGEANCE }
# LOYALTY and VENGEANCE are target-indexed; the others are scalars.

enum Trait {
    RECKLESS, PARANOID, OBSERVANT, CRAVEN, BRUTAL, SLY,
    LOYAL, AMBITIOUS, GREEDY, CALCULATING
}

enum ActionTag { VIOLENCE, DECEPTION, SOCIAL, ECONOMIC, INVESTIGATIVE, PUBLIC }

enum Visibility { OPEN, PRIVATE, ANONYMOUS, ATTRIBUTED }

enum TraceKind { EYEWITNESS, PHYSICAL, HEARSAY, MOTIVE, ABSENCE }

enum Field { ACTOR, ACTION, TARGET, INSTRUMENT }

enum Verdict { DISMISSED, DEMOTED, EXILED, KILLED }

enum CharState { ACTIVE, DEAD, EXILED }
```

Action identity is a **StringName** (`&"kill"`, `&"take_job"`), not an enum, so
actions can be registered as data without recompiling the enum. The registry is
the source of truth.

---

## 3. Core structs

### Character

```gdscript
class_name Character extends RefCounted

var id: int = -1
var name: String = ""
var state: int = E.CharState.ACTIVE

# Position
var rank: int = 0                    # 0 = boss, higher = lower in tree
var patron_id: int = -1
var crew_ids: Array[int] = []        # derived; kept in sync by Tree

# Resources
var standing: float = 0.0
var money: int = 0

# Personality — fixed at generation
var traits: Array[int] = []          # E.Trait
var temperature: float = 0.3         # softmax τ
var competence: float = 0.5          # 0..1, affects job outcomes and fidelity

# Goals — mutable, decay toward baseline
var goals: Dictionary = {}           # E.Goal -> float   (scalar goals)
var loyalty: Dictionary = {}         # char_id -> float
var vengeance: Dictionary = {}       # char_id -> float
var goal_baseline: Dictionary = {}   # E.Goal -> float, generated

# Cognition
var beliefs: Dictionary = {}         # event_id -> Belief
var plan: Plan = null
var attention: Array[int] = []       # recomputed each turn

# Bookkeeping
var last_action: StringName = &""
var last_target: int = -1
var favors: Dictionary = {}          # char_id -> int (tokens they owe me)
var purchased_opinion: Dictionary = {}  # char_id -> float, brittle channel
```

`goals` holds only the scalar goals (AMBITION, SECURITY, WEALTH, STANDING).
LOYALTY and VENGEANCE live in their own target-indexed dictionaries and are
never present in `goals`.

### Relationship

Stored on `WorldState`, not on Character, because it is directed and pairwise.

```gdscript
class_name Relationship extends RefCounted

var from_id: int = -1
var to_id: int = -1
var opinion: float = 0.0             # earned opinion, −1..1
var known_motive: float = 0.0        # 0..1 — how publicly known the grudge is
var interactions: int = 0
```

Storage: `WorldState.relationships: Dictionary` keyed by
`_pair_key(from_id, to_id) -> int` (`from_id * 10000 + to_id`). Helper
accessors only; never index it raw from game logic.

**Effective opinion** = `opinion + purchased_opinion[x] * brittleness_factor`,
where the purchased channel collapses under pressure (see GDD, Money).
Always read through `World.opinion_of(a, b)`, never the raw field.

### Event

```gdscript
class_name Event extends RefCounted

var id: int = -1
var turn: int = 0
var actor_id: int = -1
var action: StringName = &""
var target_id: int = -1
var instrument_id: int = -1          # -1 if acted directly
var visibility: int = E.Visibility.PRIVATE
var attributed_to_id: int = -1       # only when visibility == ATTRIBUTED
var outcome: Dictionary = {}         # action-specific result payload
```

Immutable after creation. Append-only into `WorldState.events`.

### Trace

```gdscript
class_name Trace extends RefCounted

var id: int = -1
var event_id: int = -1
var turn_created: int = 0
var kind: int = E.TraceKind.PHYSICAL
var reveals: Array[int] = []         # E.Field — which fields it exposes
var points_to_id: int = -1           # who it implicates (may be wrong)
var detectability: float = 0.5       # current, decays each turn
var found_by: Array[int] = []        # char_ids who have found it
var destroyed: bool = false
```

**Most traces must not include `E.Field.ACTOR` in `reveals`.** That gap is the
game. A trace revealing only ACTION and TARGET says "the shipment burned" and
nothing about who.

### Belief

```gdscript
class_name Belief extends RefCounted

var holder_id: int = -1
var event_id: int = -1               # -1 only for fabrications
var claim: Dictionary = {}           # E.Field -> value; partial
var confidence: float = 0.0
var source_id: int = -1              # who told me; -1 if first-hand
var hops: int = 0
var turn_acquired: int = 0
var fabricated: bool = false         # true if no backing event exists
var spent: bool = false              # consumed as leverage
```

**Invariant:** `event_id >= 0` XOR `fabricated == true`. A belief with neither
is a bug and must assert.

`claim` is partial by design. A belief may know ACTION and TARGET but not
ACTOR — that is the normal case and the whole point of `Dig`.

### Plan

```gdscript
class_name Plan extends RefCounted

var goal_action: StringName = &""
var target_id: int = -1
var steps: Array = []                # Array[PlanStep]
var step_index: int = 0
var patience: int = 0                # turns remaining before abandon
var frustration: int = 0
var terminal_score: float = 0.0      # cached at creation
```

```gdscript
class_name PlanStep extends RefCounted

var action: StringName = &""
var target_id: int = -1
var instrument_id: int = -1
var visibility: int = E.Visibility.PRIVATE
```

### ActionCandidate

The unit the scorer operates on. Transient — never stored.

```gdscript
class_name ActionCandidate extends RefCounted

var action: StringName = &""
var actor_id: int = -1
var target_id: int = -1
var instrument_id: int = -1
var visibility: int = E.Visibility.PRIVATE

var utility: float = 0.0
var risk: float = 0.0
var affinity: float = 0.0
var commitment: float = 0.0
var score: float = 0.0

var contributions: Dictionary = {}   # String -> float, for the log
```

`contributions` is what produces the two explanatory terms in every log line.
Populate it during scoring, not after.

### Slot and Tree

```gdscript
class_name Slot extends RefCounted

var id: int = -1
var rank: int = 0
var parent_slot_id: int = -1
var occupant_id: int = -1            # -1 = vacant
```

The tree is a list of slots, not a nested structure. `Character.rank` and
`patron_id` are **derived from slot occupancy** and resynced whenever the tree
changes. Never set them directly.

### WorldState

```gdscript
class_name WorldState extends RefCounted

var seed: int = 0
var rng: RandomNumberGenerator = null
var turn: int = 0
var heat: float = 0.0

var characters: Dictionary = {}      # id -> Character
var slots: Dictionary = {}           # id -> Slot
var relationships: Dictionary = {}   # pair_key -> Relationship
var events: Array = []               # Array[Event], append-only, index == id
var traces: Dictionary = {}          # id -> Trace
var traces_by_event: Dictionary = {} # event_id -> Array[int]
var jobs: Array = []                 # Array[Job], see doc 3
var pending_judgments: Array = []    # Array[Denouncement]
var config: Config = null

var _next_char_id: int = 0
var _next_trace_id: int = 0
var _next_slot_id: int = 0
```

---

## 4. Module boundaries

```
sim/
  enums.gd                E
  world_state.gd          WorldState
  character.gd            Character
  ...structs...
  rng.gd                  Rng — shuffle, pick, weighted_pick
  world.gd                World — accessors, invariant assertions
  turn.gd                 Turn — the 12-step resolution order
  actions/
    action.gd             Action base contract
    registry.gd           ActionRegistry
    take_job.gd, kill.gd, dig.gd, ...
  ai/
    attention.gd
    candidates.gd
    scorer.gd
    risk.gd
    planner.gd
    selection.gd
    weights.gd            weight dynamics + decay
  info/
    traces.gd             emission, decay, detection
    beliefs.gd            transmission, mutation, reporting
  gen/
    character_gen.gd      see doc 2
    world_gen.gd
  content/
    jobs.gd, events.gd    see doc 3
  log/
    chronicle.gd
    metrics.gd            see doc 4
  config/
    tuning.gd             all constants, see doc 4
```

### Hard architectural rules

State these in `CLAUDE.md` verbatim.

1. **Actions never reference other actions by name.** No `if action == &"kill"`
   inside another action.
2. **The scorer never branches on action identity.** It calls
   `action.evaluate()` and does arithmetic. If you find yourself writing
   `match action:` in `scorer.gd`, the design has leaked.
3. **All AI reads belief state, never ground truth.** `WorldState.events` is
   off-limits to anything under `ai/`. Enforce with a review rule and, if
   feasible, an assertion in the scorer that it only touched
   `character.beliefs`.
4. **Risk is derived from trace templates, never authored per action.**
5. **All tunable numbers live in `config/tuning.gd`.** No magic floats in logic
   files.
6. **Every randomness call goes through `world.rng`.**

---

## 5. The Action contract

```gdscript
class_name Action extends RefCounted

var id: StringName = &""
var tags: Array[int] = []                    # E.ActionTag
var trace_templates: Array = []              # Array[TraceTemplate]

# Is this action legal for actor→target, given ONLY the actor's beliefs?
func requires(world: WorldState, actor: Character, target: Character) -> bool:
    return true

# Returns { E.Goal: magnitude }, magnitudes in −1..1.
func evaluate(world: WorldState, actor: Character, target: Character) -> Dictionary:
    return {}

# Apply effects, return the Event. Traces are emitted by the caller
# from trace_templates — actions do not emit their own.
func execute(world: WorldState, cand: ActionCandidate) -> Event:
    return null
```

```gdscript
class_name TraceTemplate extends RefCounted

var kind: int = E.TraceKind.PHYSICAL
var reveals: Array[int] = []
var base_detectability: float = 0.4
var points_to: StringName = &"actor"   # "actor" | "instrument" | "attributed"
var delay_turns: int = 0               # e.g. Skim surfaces late
```

`evaluate` is the **only** place action-specific knowledge lives. Keep it to a
few lines. Magnitude normalization is enforced by an assertion in the scorer:
any magnitude outside −1..1 is a hard error, not a clamp.

---

## 6. Invariants

Implement as `World.assert_invariants()`, run every turn in debug builds. These
will catch more bugs than anything else, because most failures here are silent —
the sim keeps running and just produces boring output.

1. Every `Belief` has `event_id >= 0` XOR `fabricated == true`.
2. No character holds a belief about an event that occurred after
   `belief.turn_acquired`.
3. Every executed action's `requires()` returned true at selection time.
4. No character acted on a belief they do not hold (checked via
   `contributions` provenance).
5. `Character.rank` and `patron_id` match slot occupancy for every active
   character.
6. Every occupied slot has exactly one occupant; every active character
   occupies exactly one slot.
7. All goal weights, opinions, confidences within their declared ranges.
8. `traces_by_event` is consistent with `traces`.
9. No `Relationship` references a nonexistent or dead character.
10. Events array indices equal event ids.

---

## 7. Serialization

Every struct implements `to_dict()` / `static from_dict()`. Two uses:

- **Snapshot testing** — run 50 turns, dump, compare against a golden file.
  Catches unintended behaviour changes from tuning edits.
- **Replay** — a run is `(seed, config)`; a snapshot is the assertion that
  replay still produces it.

No save-game requirement for the demo, but the schema should not make it
impossible later. Integer ids and no object references are what buy this.

---

**Next:** Document 2 — Character & World Generation.