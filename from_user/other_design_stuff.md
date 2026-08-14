# Gangs — Core Design Notes

A sandbox, turn-based social simulation. The player is a member of a criminal
organization, rendered as a tree of nodes. The only goal is to climb the ranks
and then keep your place. No map, no economy layer, no combat system — the tree
is the entire game.

[[Gangs - design document]]

[[Gangs - loop and actions]]

[[Gangs - action-choice logic]]

---

## 1. Is it enough to be fun?

Yes, but for a narrower reason than it first appears.

**The fun is not in the actions. It is in the reads.**

Diplomacy has two verbs — move and support — and nobody calls it samey, because
the state you reason about is other people's intentions. Gangs is chasing the
same pleasure:

> *Marco resents Vito because Vito was promoted over him last winter. If I feed
> Marco the right rumor, he'll do the thing I want done, and my hands stay clean.*

That is a puzzle whose pieces are people, and it regenerates every playthrough
because the people are procedural.

**Corollary:** you don't need many verbs. You need the *available* verbs to
change constantly.

### Four mechanisms against sameness

1. **Gate actions on social state, not cooldowns.**
   You cannot blackmail without a secret. You cannot recruit a co-conspirator
   without sufficient opinion. You cannot frame someone unless a plausible
   motive already exists in the fiction. This is the single most important
   design decision in the game: the menu is different every turn *because the
   graph is different*, and the player plays the people rather than the buttons.

2. **Make the good stuff consumable.**
   Secrets get spent. Favors get cashed. The strongest plays are always finite,
   so you are perpetually reinvesting in relationships to reload.

3. **Change the verb set by rank.**
   This gives the three-act arc for free:
   - *Bottom* — no authority. Earn, gossip, attach yourself to a patron.
   - *Middle* — you can **assign jobs**. Give your rival the job you know will
     fail.
   - *Top* — the game inverts. Subordinates' ambition is now the threat, and
     every promotion you grant creates a future problem.

   "Climb, then hold" is two distinct games, not one loop.

4. **Exogenous shocks.**
   Even with no map, the organization needs external input: a bust, a hit from
   another crew, a big score that needs allocating, someone's brother arrested.
   Without it the social graph settles into equilibrium and the late game goes
   flat. Cheap to author, reshuffles everything.

Add a **paranoia / heat** value. After a murder everyone is watching, plots are
harder, and the correct play is to be boring for three turns. Rhythm is the
antidote to sameness.

---

## 2. Build order

Design the information model **first**. Actions write to it, NPC logic reads
from it. Designing it last means rewriting everything else.

```
information model  →  5 actions  →  scorer + 3 traits  →  run headless
```

---

## 3. The information model

Three separate types. The whole design hinges on keeping them apart.

### Event — ground truth, immutable, append-only

```
Event {
  id, turn,
  actor, action, target,
  instrument?,      // third party used, if any
  outcome
}
```

### Trace — evidence an event emitted

The **only** channel by which anyone learns anything.

```
Trace {
  event_id,
  kind,           // eyewitness | physical | hearsay | motive | absence
  reveals,        // which fields it exposes — often NOT actor
  points_to,      // who it implicates: usually the real actor, sometimes not
  detectability   // base chance of being found
}
```

**Critical:** most traces reveal `action` and `target` but *not* `actor`.
Everyone knows Vito's shipment burned. Nobody knows who lit it. That gap is
where the entire game lives.

### Belief — a character's claim about an event

```
Belief {
  holder, event_id,
  claim: { actor?, action?, target? },   // partial, possibly wrong
  confidence: 0..1,
  source, hops
}
```

### The grounding invariant

> **No belief may exist without either a backing Event or a deliberate
> Fabricate action.**

Never spawn rumors from a random table. This one rule is what makes the world
feel causal.

Fabrication then becomes an interesting verb rather than a cheat: it creates a
belief with no supporting trace. Investigation looks for traces matching a
claim; finding none collapses confidence *and* damages the credibility of
whoever spread it. Lying works, but is structurally fragile in a way truth
isn't — emergent, not hardcoded.

### Transmission and misattribution

When A tells B:

- confidence decays per hop
- the `actor` field has a mutation chance, weighted toward **plausible**
  suspects — people with known motive against the target

Rumors drift toward whoever already looks guilty. Realistic, and exactly the
exploit the player should discover.

### Scope warning

You will be tempted to model "does A know that B knows." Keep it to one level,
and only for beliefs about the holder themselves — `I suspect Marco suspects
me`. Recursive theory of mind is a tarpit and is not needed for the fantasy to
land.

---

## 4. Actions

One schema, data-driven, no special cases.

```
Action {
  requires: [predicates],
  cost:     { standing, favor, secret, exposure },
  effects:  [deltas],
  emits:    [trace templates],
  serves:   { ambition, security, wealth, vengeance, ... }
}
```

### Gate types

`requires` is where standing enters. Four flavors; mixing them is what keeps
the menu changing.

| Gate type | Example |
|---|---|
| Rank | `Assign Job` needs rank > target's |
| Rank *differential* | `Denounce Openly` fails if you're 2+ ranks below — nobody listens |
| Relationship | `Recruit Conspirator` needs opinion(X→you) high **and** opinion(X→target) low |
| Belief | `Blackmail` needs a held secret above a confidence threshold |

Belief-gated actions are the important ones: available verbs become a function
of what you have *learned*, so investigation isn't a chore — it's how you
unlock the good stuff.

### The verb set

- **Earn** — Take Job, Volunteer (high variance), Claim Credit, Skim
- **Court** — Do Favor, Call In Favor, Share Secret (buys trust, spends
  leverage), Broker Peace, Pledge Loyalty
- **Learn** — Tail, Investigate Event, Interrogate, Cultivate Informant
- **Whisper** — Spread Rumor, Fabricate, Plant Evidence, Leak To Rival (tell
  the truth to the person it will hurt most)
- **Strike** — Sabotage Job, Frame, Blackmail, Denounce, Intimidate, Kill
- **Cover** — Buy Alibi, Lie Low, Destroy Evidence, Confess Small Thing
- **Command** *(rank-gated)* — Assign Job, Protect, Take Tribute, Promote, Demote

### The two multipliers

Every action takes:

- **visibility** — open / private / anonymous / attributed-to-X
- **instrument** — do it yourself, or get someone else to

These roughly quadruple the effective action space without adding a verb, and
they are where all the interesting plays are. "Sabotage" and "get Marco to
sabotage, believing it was Vito's idea" are the same verb and completely
different plays.

Targeting a **relationship** rather than a person is likewise a large source of
variety for free.

---

## 5. The NPC decision loop

Per character, per turn:

1. **Enumerate legal actions against their belief state, not ground truth.**
   Non-negotiable. An NPC who blackmails you over a secret they don't actually
   hold has broken the whole game.
2. Score each candidate.
3. **Softmax over the top handful — never argmax.** Deterministic utility AI
   produces characters who feel like spreadsheets and a world that replays
   identically from identical starts.

### Scoring

```
score = Σ_goals ( weight[g] × expected_delta[g] )
      − perceived_risk
      + trait_affinity
```

**Goals** (six is plenty): Ambition, Security, Wealth, Loyalty(→person),
Vengeance(→person), Standing.

Randomize weights at generation, and let events *change* them — being passed
over should spike Ambition and Vengeance toward whoever took the slot.

**Perceived risk:**

```
perceived_risk = P(detected) × P(attributed to me) × severity
```

All three estimated *by that character*.

### Traits

Traits do their best work by distorting the **estimate**, not the outcome.

| Trait | Effect |
|---|---|
| Craven | Inflates severity — avoids anything traceable |
| Reckless | Underestimates detectability — gets caught constantly |
| Paranoid | Acts on beliefs at low confidence — generates false accusations |
| Observant | Bonus to trace detection |
| Brutal / Sly | Affinity bonus to violence / deception verbs |
| Loyal | Hard veto on hostile actions against their patron; huge Vengeance spike if the patron is harmed |

Traits that change *perception* produce far better stories than traits that
change stats. Paranoid alone will generate half the best incidents.

### Plans

Per-turn scoring alone makes characters flip-flop and never build an arc. Give
each NPC a current **Plan**: a target, an intended sequence, an abort
condition, a patience budget. Re-evaluate each turn but apply a commitment
bonus to continuing.

Now Marco spends five turns working toward something, and you can watch it
coming.

### Private ambitions

Each NPC gets a randomized private ambition — climb, protect their patron,
avenge X, just survive — so they run their own plots that the player can
observe, hijack, or ride.

---

## 6. Detection, and getting caught

- Every action emits traces with a detection probability, weighted by graph
  proximity, the observer's traits, and whether they're actively investigating.
- Evidence points at a suspect with a confidence value. NPCs accumulate it and
  act past a threshold.
- **False positives are a feature.** The suspicion system should sometimes
  finger the wrong person. That is simultaneously what makes framing possible
  and what generates the best emergent stories.

When an NPC catches you, **branch, don't punish**. The interesting response to
"I know you tried to have me killed" isn't reporting you to the boss — it's
blackmailing you into working for them. Getting caught should open gameplay,
not close it.

---

## 7. Instrumented logging

Have the scorer emit its top two contributing terms with every chosen action:

```
T14 — Marco sabotages Vito's shipment, anonymously.
      (ambition 0.6 · resentment: passed over T9 · judged risk low — Reckless)
      Traces: physical evidence at the warehouse (found T16 by Sal),
              motive known to 3.
```

This is the debugger and the shipped end-of-turn report in one artifact — a
good sign about the design.

---

## 8. The falsification test

Build the simulation with **no player at all**. Pure code, no graphics.

```
events + traces + beliefs + transmission
  → 5 actions: Take Job, Sabotage, Investigate, Spread Rumor, Kill
  → scorer + 3 traits
  → 12–20 characters, 100–200 turns
  → print the log
```

Read the chronicle and ask:

1. Can you reconstruct **why** things happened?
2. Does at least one **misattribution cascade** appear — someone punished for
   something they didn't do?

If both, within 100 turns from five verbs, the engine works and everything
after is content and UI.

If the log reads as a random walk, the problem is in the **belief layer**, not
the action count. Adding verbs will only hide it.

A week of work to find out, instead of six months.

---

## Appendix — prior art worth studying

Most gang games are about **external** competition: your gang vs. rival gangs,
territory, economy. Gangs is about **internal** politics within one
organization, which is rare as a standalone game. That's the gap.

**Structure — a literal tree of characters you climb**

- *Middle-earth: Shadow of War* — the army screen is the closest visual match.
  Node hierarchy of named orcs with traits; killing or shaming opens a slot and
  promotions cascade.
- *Kremlin* (board game, 1986) — pyramid of Politburo officials; advance by
  discrediting, purging, and outliving rivals.
- *Intrigue* (Dorra) — pure bribery and betrayal for positions in a hierarchy.

**Simulation — traits, loyalties, rivalries, AI on the same rules as the player**

- *Crusader Kings II / III* — schemes as multi-turn projects with recruited
  co-conspirators; secrets and hooks as currency; opinion as a scalar with
  decaying itemized modifiers; traits as AI weights.
- *Star Dynasties* (2021) — CK stripped down to *just* character politics.
  Probably the closest existing game to this pitch.
- *Romance of the Three Kingdoms* / *Nobunaga's Ambition* — "sow discord"
  commands that manipulate loyalty between enemy officers to trigger defections.

**Where CK is a bad model**

- Its politics are a side dish; here they're the entire meal, so they must be
  far more *readable*. In CK you often have no idea why a vassal soured on you.
  Tolerable at 300 characters, intolerable at 20.
- Scale: aim for **15–30 named members max**, so each is someone the player has
  an opinion about. Small casts are what made the nemesis system land.
- CK schemes run on continuous months and years. On discrete turns, tune
  duration so the player juggles several plots rather than waiting.

**Theme**

- *Empire of Sin* — gangsters with traits, loyalties, grudges; can defect.
- *Gangsters: Organized Crime* (1998) — the cult classic.
- Old browser mafia MMOs (Omerta, Mafia Wars) — the associate → soldier → capo
  → don ladder, with almost no simulation behind it.