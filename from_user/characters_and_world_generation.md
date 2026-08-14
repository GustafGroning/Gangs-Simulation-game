# Gangs — Character & World Generation

**Document 2 of 5.** How a starting world is built: the tree, the people in it,
and the history they already share.

Depends on `gangs-state-schema.md` for all type names. All constants named here
live in `config/tuning.gd` (doc 4) — the values below are starting points, not
literals to inline.

---

## Design goals

Generation has one job: **produce a world that already has tension in it on
turn 0.** A cast of identical neutral strangers takes 40 turns to become
interesting, which wastes most of a 100-turn falsification run.

Three principles:

1. **Differentiate hard.** Weak randomization is the most likely cause of the
   "monoculture" failure mode. If every character has goal weights near 0.5,
   they will all pick the same action. Sample from wide distributions and push
   toward the extremes.
2. **Generate history, not just state.** Relationships should exist because
   something happened, and the sim should know what. Pre-seed real Events.
3. **Plant hooks.** A handful of deliberate structural tensions — a passed-over
   rival, a loyal enforcer, an unresolved killing — give the first twenty turns
   something to work with.

---

## 1. World generation order

```
1. build_tree(config)              → slots
2. generate_characters(n)          → personalities, no positions
3. assign_to_slots()               → rank, patron, crew
4. generate_history()              → prior Events, traces, beliefs
5. derive_relationships()          → opinions from history + noise
6. plant_hooks()                   → deliberate structural tensions
7. seed_initial_beliefs()          → who knows what on turn 0
8. assert_invariants()
```

Steps 4–7 are what make this more than a character sheet generator.

---

## 2. Tree topology

```gdscript
# tuning
TREE_RANKS          = 4        # 0 = boss .. 3 = soldiers
TREE_BRANCHING      = [1, 3, 3, 2]   # slots created per parent at each rank
TREE_TARGET_SIZE    = 18
```

Rank 0 has one slot. Each rank-N slot spawns `TREE_BRANCHING[N]` children,
with ±1 jitter so the tree is not symmetric. Asymmetry matters: a lieutenant
with five subordinates and one with two are in visibly different positions, and
that asymmetry is free strategic texture.

Target **15–20 characters**. Below 12 the social graph is too sparse for rumour
transmission to do anything interesting; above ~25 the log becomes unreadable
and you lose the "cast you have opinions about" quality that makes the nemesis
comparison work.

Start with **one vacancy at rank 2**, pre-existing. It gives ambitious
characters something legal to compete over before anyone resorts to violence,
which is a much better opening than everyone reaching for Kill.

---

## 3. Character generation

### Names

A fixed list of ~60 first names plus ~40 surnames, drawn without replacement
via `Rng.pick`. Names must be **short and visually distinct** — you will be
reading them in a log at speed. Avoid two characters whose names share a first
letter where possible.

Store a `short_name` (first name only) for log lines, falling back to
`first + last initial` on collision.

### Traits

```gdscript
TRAIT_COUNT_WEIGHTS = { 1: 0.25, 2: 0.50, 3: 0.25 }
```

Draw 1–3 traits without replacement from `E.Trait`.

**Exclusion pairs** — never co-assign:

| A | B | Reason |
|---|---|---|
| RECKLESS | CRAVEN | Opposed risk perception |
| RECKLESS | CALCULATING | Opposed temperature |
| PARANOID | ~~— | (Paranoid pairs freely; it's the best trait) |
| LOYAL | AMBITIOUS | Opposed core drive — allow only rarely (5%) as a deliberate tragic figure |

**Distribution targets** across the cast, enforced by resampling if a run
misses them badly:

- At least 2 RECKLESS (they generate the incidents)
- At least 2 PARANOID (they generate the false accusations)
- At least 1 OBSERVANT (someone has to actually catch things)
- At least 1 LOYAL attached to a mid-rank patron (creates a bodyguard dynamic)
- No more than 40% of the cast sharing any single trait

These floors matter more than they look. Both PARANOID and RECKLESS are
misattribution engines, and the falsification test depends on misattribution
appearing.

### Temperature

```gdscript
temperature = clamp(rng.randfn(0.30, 0.10), 0.10, 0.60)
```

Then trait overrides: `CALCULATING → ×0.5`, `RECKLESS → ×1.6`.

Temperature is doing real characterisation work — it separates "unpredictable"
from "differently motivated" — so do not let it collapse toward the mean.

### Competence

```gdscript
competence = clamp(rng.randfn(0.50, 0.18), 0.10, 0.95)
```

Affects job outcome rolls, trace detection, and **transmission fidelity** — a
low-competence character garbles what they pass on. Correlate mildly with rank
(`+0.05 per rank above soldier`) so the tree isn't obviously meritocratic but
isn't random either.

### Goal weights

This is the most important distribution in the document.

```gdscript
# Per character, per scalar goal:
base = rng.randfn(0.45, 0.22)
```

Then apply **polarization**: pick one goal at random to be that character's
dominant drive and push it up, and one to suppress.

```gdscript
dominant  = pick(scalar_goals)
recessive = pick(scalar_goals except dominant)
goals[dominant]  = clamp(goals[dominant] + 0.30, 0, 1)
goals[recessive] = clamp(goals[recessive] - 0.25, 0, 1)
```

Trait modifiers on top:

| Trait | Modifier |
|---|---|
| AMBITIOUS | AMBITION +0.30 |
| CRAVEN | SECURITY +0.30, AMBITION −0.20 |
| GREEDY | WEALTH +0.30 |
| BRUTAL | SECURITY −0.15 |
| LOYAL | AMBITION −0.25 |
| PARANOID | SECURITY +0.20 |

Store the result as `goal_baseline` **and** copy it into `goals`. Decay in
`weights.gd` pulls `goals` back toward `goal_baseline`, not toward a global
mean — that is what makes a character's personality persistent across the
emotional swings of a run.

### What is *not* generated

`loyalty` and `vengeance` start **empty**. They are earned. The only exceptions
are those planted in step 6, and each of those must have a backing Event.

---

## 4. Slot assignment

Not random. Sort characters by a soft "who would plausibly have gotten here"
score:

```gdscript
fitness = 0.5*competence + 0.3*goals[AMBITION] + 0.2*rng.randf()
```

Assign top-fitness to rank 0, descending. The random term keeps it from being
strictly meritocratic — you want at least one obviously underqualified person
holding a senior slot, because they're a target and everyone below them can see
it.

Then **starting standing**:

```gdscript
standing = STANDING_BY_RANK[rank] + rng.randfn(0, 4.0)
```

with `STANDING_BY_RANK = [60, 40, 25, 12]`. The noise is deliberate and
important: it should be possible for a rank-3 character to already out-stand a
rank-2 one, because that is a Challenge waiting to happen on turn 1.

Starting money: `MONEY_BY_RANK[rank] + noise`, with GREEDY characters starting
slightly richer and one character deliberately generated **in debt** (see
hooks).

---

## 5. History generation

Run a lightweight pre-simulation of `HISTORY_TURNS = 15` before turn 0.

Two options, and I recommend the second:

**Option A — synthetic history.** Fabricate 20–30 plausible past Events
directly (jobs completed, a promotion, a falling-out) without running the
scorer.

**Option B — actually run the sim.** Run the real turn loop for 15 turns with
`Kill` and `Denounce` disabled and heat suppressed, then declare turn 0.

Option B is strictly better and nearly free once the loop exists: the history
is guaranteed self-consistent, every relationship has a real Event behind it,
beliefs are already distributed unevenly across the cast, and traces are
already decaying. It also serves as a smoke test of the loop every time you
generate a world.

Use Option A only as a bootstrap while the turn loop is incomplete.

Regardless of option, history must produce:

- 10–20 completed jobs with varied outcomes
- 1–2 rank changes (at least one promotion someone else wanted)
- at least one **unattributed** hostile event — a sabotage nobody has pinned
  down. This is the game's opening mystery and several characters should hold
  partial, conflicting beliefs about it.

---

## 6. Relationship derivation

For every ordered pair within `RELATIONSHIP_RADIUS` of each other in the tree
(patron/crew, siblings, and grandparent links — not the full N² graph):

```gdscript
opinion = 0.0
opinion += history_derived_delta(a, b)     # from generated Events
opinion += rng.randfn(0.0, 0.15)           # personal chemistry
opinion += structural_bias(a, b)
```

`structural_bias`:

- patron → crew: +0.10 (mild default goodwill)
- crew → patron: +0.05
- **siblings (same patron): −0.15** — they are competing for the same
  advocacy, and this single bias generates a large share of the game's conflict
- grandparent links: 0.0

Pairs outside the radius get a lazily-created neutral relationship on first
interaction. Do not pre-populate N² — it is wasted memory and it implies
familiarity that shouldn't exist.

`known_motive` is derived, not generated: it rises when a hostile Event between
the pair was publicly visible. After history generation, recompute it for all
pairs.

---

## 7. Planted hooks

Six deliberate structural tensions, each backed by a real Event from history.
These are the only place generation touches `loyalty`/`vengeance` directly, and
even here the weight must have a corresponding Event.

| Hook | Construction | Purpose |
|---|---|---|
| **The passed-over** | Two rank-2 siblings; one was promoted in history. Loser gets `Vengeance[winner] = 0.45`, AMBITION +0.2 | An active grudge on turn 0 |
| **The enforcer** | A LOYAL rank-3 attached to a rank-1 patron, `Loyalty[patron] = 0.7` | Tests the bodyguard dynamic and the veto rule |
| **The open case** | An unattributed sabotage from history. 3–4 characters hold partial beliefs; at least one names the **wrong** actor | Seeds misattribution immediately |
| **The debtor** | One character with negative money and a `Relationship` to their lender | Tests debt-as-motive and the Wealth goal |
| **The unqualified** | A rank-1 with competence < 0.3, and two subordinates who know it | A legible, obvious target |
| **The rising soldier** | A rank-3 with standing above their rank-2 patron | A Challenge available on turn 1 |

Six hooks in an 18-character cast means a third of the world starts with a
reason to act. That is roughly the right density — enough that turn 1 is not
inert, sparse enough that emergent conflicts still dominate by turn 30.

---

## 8. Initial belief distribution

Do not give everyone the same beliefs. Distribution is where the information
game starts.

For each historical Event, for each character, roll acquisition using the
normal detection path (graph proximity × trait × trace detectability), then
apply the normal transmission pass. The outcome you want on turn 0:

- the boss knows about ~60% of events, mostly at low confidence and high hops
- soldiers know their local neighbourhood well and the rest of the tree barely
- **at least three characters hold a belief whose `claim[ACTOR]` is wrong**
- at least one belief exists at confidence > 0.6 that is factually incorrect

That last one is the single best predictor of whether the run will produce a
good story. If the belief layer cannot generate a confident falsehood during
15 turns of history, it will not generate one during 100 turns of play, and
that is worth knowing before you build anything else.

---

## 9. Generation config

```gdscript
class_name GenConfig extends RefCounted

var seed: int = 0
var cast_size: int = 18
var tree_ranks: int = 4
var branching: Array[int] = [1, 3, 3, 2]
var history_turns: int = 15
var history_mode: String = "simulate"   # "simulate" | "synthetic"
var hooks_enabled: bool = true
var relationship_radius: int = 2
```

`config_hash` (from doc 1) is computed over this plus `tuning.gd`, so a run is
fully identified by `(seed, config_hash)`.

---

## 10. Generation smoke test

After generation, before turn 1, assert:

1. All invariants from doc 1 pass.
2. Every character occupies exactly one slot; exactly one slot is vacant.
3. No trait exclusion pair was co-assigned.
4. Trait distribution floors met.
5. Goal weight variance across the cast > `MIN_GOAL_VARIANCE` — **fails loudly
   if the cast is homogeneous.** This catches the monoculture failure at
   generation time instead of 100 turns later.
6. At least 3 incorrect `claim[ACTOR]` beliefs exist.
7. Every non-empty `vengeance`/`loyalty` entry has a corresponding Event.
8. The generated world serializes and deserializes to an identical state.

Print a one-page **world summary** on generation: tree diagram, each character
with traits, dominant goal, standing, and any hook they're part of. You will
read this before every log, and it is what makes the chronicle comprehensible.

---

**Next:** Document 3 — Content Spec (jobs, slots, exogenous events).