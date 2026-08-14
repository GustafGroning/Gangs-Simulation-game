# Gangs — Action-Choice Logic

Living document. Covers how a character decides what to do on a given turn.

Companions: `gangs-gdd.md` (flow, progression, action list) and
`gangs-design.md` (Events, Traces, Beliefs).

---

## Architectural rule

> **The generic machinery must never know what any specific action means.**

Every action carries its own small utility function. The scorer only does dot
products and risk math. Get this boundary right and you can add verbs forever
without touching the AI.

---

## The pipeline

```
for each character C, each turn:
    A  = attention_set(C)              # ~6 salient people, not everyone
    K  = candidates(C, A)              # legal under C's BELIEFS, not truth
    K += plan_continuations(C)
    for k in K: score(k) = utility(k) - risk(k) + affinity(k) + commitment(k)
    choose softmax(top_n(K), temperature(C))
    log(choice, top_2_contributing_terms)
```

Everything below is a detail of one of those lines.

---

## 1. Attention set

Scoring every action against every character is both too slow and wrong. People
don't think about everyone. Each turn, build a set of ~5–8 salient others:

- your patron, and their patron
- your subordinates
- anyone with `Vengeance[them] > 0` or `Loyalty[them] > 0`
- competitors for any vacancy you're eligible for
- anyone who appeared in a belief you acquired in the last N turns
- one random member (curiosity — prevents the graph from calcifying)

A performance fix that doubles as a characterisation mechanism. A Paranoid
character's attention set should be wider; an insular one narrower. A character
who genuinely hasn't noticed the threat forming three nodes over is **correct
behaviour, not a bug**.

---

## 2. Candidate generation

Order matters for cost:

1. **Hard gates first.** Evaluate `requires` against C's belief state. Cheap
   boolean predicates, kills most of the space immediately.
2. **Expand target** over the attention set only.
3. **Expand visibility/instrument last, and lazily.** Don't score all four
   visibilities. Cheap heuristic:
   - hostile action + actor has something to lose → try `anonymous` and `self`
   - a plausible third party with existing motive against the target exists →
     try `attributed-to-X`
   - instruments expand only over people who'd plausibly accept:
     `opinion(them→C) high AND opinion(them→target) low`

That last predicate does enormous work. It's the same one that gates Recruit
Conspirator, and it means the game's best plays are automatically only visible
to characters who have done the relationship work.

Always include **Lie Low** as a floor candidate, so there is a defined answer
when everything else is gated or too risky.

---

## 3. The score

```
score = Σ_g weight[C][g] × normalized_delta[g]     # utility
      − perceived_risk
      + trait_affinity
      + plan_commitment
```

### 3a. Utility — the action contract

Each action definition exposes:

```
evaluate(actor, target, world_as_believed) -> { goal: magnitude }
```

Magnitudes normalized to roughly −1..1. This is the **only** place
action-specific knowledge lives, and it's usually two or three lines:

```
Kill.evaluate(C, T):
    ambition  = blocks_advancement(C, T)      # is T between C and a slot?
    vengeance = C.vengeance[T]
    security  = threat_estimate(C, T)         # does C believe T is plotting?
    wealth    = 0
```

```
DoFavor.evaluate(C, T):
    loyalty   = 0.3
    security  = influence(T) × 0.4            # useful people are worth more
    ambition  = 0.1 × can_advocate_for(T, C)  # only if T can promote C
```

`DoFavor` scores *low* on its own. That is correct — it's the tempo problem,
solved in §4, not here. **Do not fix it by inflating the number**; that produces
characters who do favours forever and never act.

**Normalization is not optional.** If Kill returns ambition 40 and Take Job
returns standing 2, your weights are meaningless and no tuning saves it. Force
every `evaluate` onto the same scale.

### 3b. Risk — derived, never authored

Computed from the action's trace templates, so it stays automatically correct
as you add verbs:

```
perceived_risk = P_detected × P_attributed × severity
```

**P_detected** — for each emitted trace:
`detectability × observer_density(target's graph neighbourhood) × heat_multiplier`,
combined as `1 − Π(1 − p)`.

**P_attributed** — given detection, does it land on C?

- does any trace reveal `actor`? (the visibility parameter)
- does C have **known motive** against the target? — the crucial one: public
  grudges make you the default suspect
- alibi purchased?
- how many alternative plausible suspects exist? More people with motive
  against the target = safer for everyone. Perverse, and emerges for free.

**severity** — expected Judgment outcome × the accuser's power to enforce it.
Killing a well-protected superior is dangerous mainly because their patron will
act.

All three are estimated **by C**. This is where traits do their best work —
they distort perception, not outcomes:

| Trait | Distortion |
|---|---|
| Craven | severity × 1.8 |
| Reckless | P_detected × 0.5 |
| Paranoid | inflates `threat_estimate` of others; acts on beliefs at low confidence |
| Observant | better P_detected estimate (accurate, not biased) |
| Sly | better P_attributed estimate |

A trait that makes you *wrong* generates far better stories than one that makes
you stronger. Reckless characters get caught constantly; Paranoid ones start
feuds over nothing.

### 3c. Trait affinity

Flat bonus per action tag: Brutal `+violence`, Sly `+deception`, Loyal a **hard
veto** on hostile actions against their patron.

Keep this small — it should colour choices, not dominate them. If Brutal makes
Kill win outright, you've built an archetype, not a personality.

---

## 4. Plans — and the tempo problem

Without this, characters never invest. Take Job scores 0.2, Kill scores 0.9, so
everyone murders on turn one and the game is a bloodbath.

**This is the single most likely way the first run fails.**

The fix: **plan steps inherit discounted terminal value.**

```
Plan { goal_action, target, steps[], step_index, patience, frustration }
```

When a high-value terminal action is *gated* (missing belief, standing, money),
don't discard it — generate a plan that reaches its preconditions:

```
Kill(Vito) blocked: need instrument
  → step 1: DoFavor(Marco)        # Marco dislikes Vito
  → step 2: DoFavor(Marco)
  → step 3: Kill(Vito, instrument=Marco)

step_score = γ^(steps_remaining) × terminal_score,   γ ≈ 0.85
```

DoFavor now scores 0.9 × 0.85² ≈ 0.65 — competitive, and *for a legible reason
the log can print*. This is what makes patient characters possible and what
makes quiet turns meaningful.

**Continuation bonus** on the current plan's next step (~+0.15) so characters
don't flip-flop. Re-score every turn regardless; the bonus biases, it doesn't
lock.

**Abort conditions:** target dead or exiled · preconditions became impossible ·
another goal now dominates by a wide margin · patience exhausted.

**Frustration** — increment on repeated failure. Past a threshold, either
escalate the terminal action along a severity ladder
(`Sabotage → Frame → Kill`) or abandon and re-plan. Escalation under
frustration will produce most of the best incidents.

**Cap plan depth at 3–4 steps.** Deeper planning is expensive and reads as
inhuman.

---

## 5. Selection

**Softmax over the top ~5, never argmax.** Argmax gives spreadsheet characters
and identical replays from identical seeds.

```
P(k) ∝ exp(score(k) / τ)
```

Vary **τ per character**:

- Reckless / Impulsive — high (~0.5), erratic
- Calculating — low (~0.15), near-optimal

Temperature is an underrated characterisation tool. It's the difference between
someone unpredictable and someone merely different.

Add a small **repetition penalty** on the same action+target as last turn,
unless it's an active plan step. Prevents visible loops.

---

## 6. Weight dynamics

Goals: Ambition · Security · Wealth · Standing · `Loyalty[x]` · `Vengeance[x]`

| Trigger | Effect |
|---|---|
| Passed over for a slot | Ambition +0.2, `Vengeance[winner]` +0.3 |
| Believe you were harmed by X | `Vengeance[X]` += severity × confidence |
| Patron killed | `Vengeance[believed killer]` +0.5, Security +0.3 |
| Survived an attempt | Security +0.4, Ambition −0.2 |
| Successfully acted on Vengeance[X] | `Vengeance[X]` × 0.4 |
| Promoted | Ambition −0.15, Security +0.15 |
| Money below zero | Wealth +0.3 |
| Favour received | `Loyalty[giver]` +0.1 |

Two rules matter more than the numbers:

- **Vengeance scales with `confidence`, not truth.** A belief at 0.4 confidence
  produces weak, hesitant hostility. This is what gives rumours physical weight
  in the world.
- **Everything decays toward baseline** (~3%/turn). Without decay: permanent
  grudges and characters who never move on. With it: arcs that resolve, which
  is what reads as narrative.

---

## 7. Failure modes

The first headless run will land in one of these. Knowing them in advance saves
days.

| Symptom | Cause | Fix |
|---|---|---|
| **Bloodbath** — everyone kills immediately | Risk underweighted, or plan discounting not wired up | Raise severity, check γ |
| **Stasis** — everyone Lies Low forever | Risk overweighted; floor action beats everything | Cap `perceived_risk` contribution, or make Lie Low cost standing |
| **Monoculture** — all 20 pick the same action | Traits not differentiating, or τ too low | Widen weight randomization at generation *first* |
| **Random walk** — plausible choices, no readable arcs | Plans not persisting | Raise continuation bonus and patience |
| **No misattribution** — half the game missing | Belief layer not producing false attributions | Check mutation rates in transmission, and the false-resolve branch on Dig |

**Tune in this order:**

```
risk scale  →  γ and continuation  →  weight variance  →  τ
```

Later knobs are meaningless if the earlier ones are wrong.

---

## Summary

The AI has no goals, no scripts, and no knowledge of what a gang is. It has
weights, an estimate of what it can get away with, and a habit of finishing
what it started.

Everything you'd call motivation is those three things meeting a social graph.