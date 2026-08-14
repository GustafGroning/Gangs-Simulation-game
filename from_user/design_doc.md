# Gangs — Game Design Document

Living document. Covers game flow, progression, and the action list.
The information/simulation model (Events, Traces, Beliefs, the NPC scorer)
lives in `gangs-design.md`.

---

## Core loop

A sandbox, turn-based social simulation. The player is a member of a criminal
organization rendered as a tree of nodes. The only goal is to climb the ranks
and then keep your place. No map, no economy layer, no combat system — the tree
is the entire game.

Each turn every character, player included, picks one action from the same
rule set. NPCs choose via a utility scorer reading their own **belief state**,
not ground truth.

---

## Resources

| Resource | Nature | Notes |
|---|---|---|
| **Standing** | Continuous float, per character | Reputation. Rises/falls constantly from many small sources. |
| **Rank** | Discrete position in the tree | Changes rarely, only via a rank-change mechanism. |
| **Money** | Integer, can go negative | Buys the *removal of consequences*, never standing directly. |
| **Favor tokens** | Per-pair, consumable | Earned by Do Favor, spent by Call In Favor. |
| **Beliefs** | See `gangs-design.md` | Gate the strongest actions. Consumable when spent as leverage. |
| **Heat** | Global or per-character | Rises after violence. Suppresses plots for several turns. |

### Money design rules

- **Money buys the removal of consequences, never the creation of standing.**
  It converts quiet turns into capability, but cannot purchase what only the
  social graph can give.
- **Wealth is traceable.** Sudden unexplained money emits a trace — *"where did
  Marco get the money for that?"* — with `points_to` on whatever actually
  earned it. Skimming funds your plots and simultaneously builds the case
  against you. This is what makes slow legitimate earning a real option.
- **Debt is social.** Balances may go negative. Borrowing from another member
  creates a hook they hold over you; an unpaid debt is a motive that enters
  everyone's plausibility weighting when something happens to the lender.
- **Purchased opinion is brittle.** Track it on a separate channel from earned
  opinion, and collapse it under pressure. Bought loyalty should fail exactly
  when you need it.

---

## Game flow

### Turn resolution order

1. **Upkeep** — recurring costs (informants, tribute), heat decay, trace decay,
   goal-weight decay.
2. **Job board** — new jobs generated and made available for assignment.
3. **Action selection** — every character, simultaneously, selects one action
   against their own belief state. Player included.
4. **Resolution** — actions resolve in a fixed priority order (see below).
   Events are written to the ledger.
5. **Trace emission** — each Event emits its traces into the world.
6. **Detection** — characters roll to find traces, weighted by graph proximity,
   traits, active investigations, and heat.
7. **Transmission** — beliefs spread along the graph. Confidence decays per hop;
   `actor` fields mutate toward plausible suspects.
8. **Upward reporting** — subordinates roll to pass new beliefs to superiors.
9. **Judgment** — any Denounce triggered this turn is adjudicated.
10. **Rank changes** — vacancies contested, promotions applied, tree redrawn.
11. **Goal update** — weights adjust in response to what happened.
12. **Report** — the end-of-turn log is written.

### Resolution priority

Cover actions resolve before Strike actions (an alibi bought this turn protects
against a strike this turn). Learn actions resolve after Strike actions, so
investigation sees the turn's new traces. Command actions resolve first, since
assignments shape everything else.

```
Command → Cover → Earn → Strike → Court → Whisper → Learn
```

### Upward reporting

At end of turn, each character rolls per newly-acquired belief:

```
P(report) = f( loyalty(→superior), value_to_superior, traits, self_implication )
```

- **Nobody reports what hurts them.** A belief implicating the holder, their
  patron, or a close friend is heavily suppressed regardless of loyalty.
  Loyalty and honesty are separate axes.
- **Low loyalty redirects rather than blocks.** The roll picks a *recipient*,
  not pass/fail. A disloyal underling reports to a rival superior, or sells the
  belief. Neglecting subordinates is an active leak, not just a lost sensor.
- **Reports run through the transmission pipeline.** Decay and actor-mutation
  apply, with fidelity scaled by loyalty. Your intelligence network is only as
  accurate as it is loyal.
- **The player is on both ends.** You receive from underlings and leak to your
  patron. A loyal subordinate may dutifully pass your own murder trace straight
  up past you.
- **Counterplay:** feed a fabricated belief to a rival's least loyal
  subordinate and let their own reporting chain deliver it. The rival then acts
  on false intelligence, publicly, with their name on it.

**Balance valve:** information concentrates at the top, and an omniscient boss
breaks the endgame. Three pushbacks — per-hop decay makes high-rank beliefs
stale and garbled; superiors have a **limited attention budget** (process N
reports per turn, drop the rest); and the top of the tree is where the most
people have reason to lie.

---

## Progression

### Standing vs. rank

Standing is what you accumulate. Rank is what you spend it on. Most turns you
move a number; occasionally the tree changes shape.

### The critical rule

> A vacancy is filled by the **candidate with the highest
> (standing + advocacy from above) among eligible subordinates.**

Removal creates a *contest*, not an automatic promotion. Violence only pays if
the social work is already done — ten quiet turns of building standing and
courting your patron's patron, and only then open the slot.

### Rank-change mechanisms

| Mechanism | How | Requires | Signature |
|---|---|---|---|
| **Removal** | Superior killed, exiled, demoted, or arrested → contest | Opportunity + prior standing | Violent, high heat, heavy traces |
| **Advocacy** | A superior elevates you into an existing or created slot | High opinion from them + standing | Relational, slow, safe |
| **Challenge** | Public claim that you deserve their position | Standing within threshold of theirs + public credit | Loud, binary, loser demoted |
| **Succession** | Your patron falls; their crew redistributes and you absorb it | Being well-positioned when it happens | Passive — rewards patience and placement |
| **Defection** | Move laterally to a superior who values you more | An interested patron elsewhere + acceptable standing | Trades accumulated relationships for position |

Each is mechanically distinct: violence, relationships, public reputation,
positioning, mobility. A Craven character never Challenges but happily waits
for Succession. A Brutal one goes straight for Removal and usually loses the
contest afterward.

### Judgment

Exile is not an action — it is an outcome. A public accusation (`Denounce`) is
adjudicated by the **highest-ranked uninvolved party**, using *their* belief
state, weighted by the accuser's and accused's standing.

Verdicts: **dismissed** (accuser loses standing) · **demoted** · **exiled** ·
**killed**.

Judgment is where the information system cashes out in public.

### Verb set by rank

- **Bottom** — no authority. Earn, gossip, attach yourself to a patron.
- **Middle** — Assign Job unlocks. Give your rival the job you know will fail.
- **Top** — the game inverts. Subordinates' ambition is the threat, and every
  promotion granted creates a future problem.

"Climb, then hold" is two distinct games.

---

## Emergent goals

Minor goals are **not authored**. They are a side effect of the scorer. Four
mechanisms produce them:

1. **Vengeance and Loyalty are vectors, not scalars.** Indexed by target.
   `Vengeance[Vito] = 0.8` is a goal in all but name — it makes every action
   harming Vito score highly for as long as it stays high.

2. **Weights move in response to events.** Being passed over spikes Ambition
   and Vengeance toward whoever took the slot. A patron's death spikes
   Vengeance at the killer and Security. Losing money spikes Wealth. Nothing is
   written as "Marco now wants revenge" — a number went up.

3. **Weights satisfy and decay.** Acting on Vengeance drains it; a successful
   strike drains it a lot. Without this, characters lock into permanent
   obsessions. With it, arcs *end* — which is what makes them read as stories.

4. **Plans give persistence.** The commitment bonus turns a temporarily
   dominant weight into a multi-turn sequence. A "minor goal" is just
   *dominant weight + active plan*, and it shows up in the log as intent.

**Frustration:** if a plan fails repeatedly, either escalate
(sabotage → frame → kill) or abandon and re-score.

**Emerges without code:** revenge arcs · feuds (mutual Vengeance) · bodyguard
behaviour (high Loyalty + patron under threat) · turtling (Craven + high
Security) · kingmaking (high Loyalty, low Ambition — promotes their patron
instead of themselves) · panic (Security spiking after a near-miss).

---

## Action list

Common schema: `requires` / `cost` / `effects` / `emits` / `serves`.

Every action additionally takes:
- **visibility** — open / private / anonymous / attributed-to-X
- **instrument** — self, or a recruited third party

These are parameters, not separate verbs. ~35 actions below, but only ~14
distinct *shapes*.

**D** marks the demo subset.

### Earn

| Action | Requires | Cost | Effects | Emits | Serves |
|---|---|---|---|---|---|
| **Take Job** `D` | job available | — | +money, +standing (small) | — | Wealth, Standing |
| **Volunteer** | job available | — | high variance: ++standing or −−standing | — | Ambition |
| **Claim Credit** | belief re: another's success, true actor unknown to others | — | +standing, target −standing | hearsay → you, if witnessed | Standing |
| **Skim** | assigned to a job | — | ++money | physical, delayed | Wealth |

### Court

| Action | Requires | Cost | Effects | Emits | Serves |
|---|---|---|---|---|---|
| **Do Favor** | — | money or turn | +opinion, you gain Favor token | — | Loyalty |
| **Call In Favor** | Favor token | consumes it | target acts on your behalf next turn | — | any |
| **Share Secret** | held belief | belief spreads | ++opinion(→you) | — | Loyalty |
| **Broker Peace** | two members in mutual dislike, both neutral+ toward you | — | +opinion from both, their mutual opinion rises | — | Standing |
| **Pledge Loyalty** | rank differential | inherit their enemies; barred from acting against them | ++opinion | public | Security |
| **Gift** | — | money | +purchased opinion (brittle channel) | — | Security |
| **Pay Tribute** | patron | money | +opinion(patron) | — | Security |

### Learn

| Action | Requires | Cost | Effects | Emits | Serves |
|---|---|---|---|---|---|
| **Dig** `D` | held belief with missing/uncertain field | — | resolve / corroborate / collapse / false-resolve | hearsay: "X is asking about Y" | Ambition, Security |
| **Tail** | — | — | chance to detect target's recent traces | target may notice | Security |
| **Interrogate** | leverage or rank | −opinion | extract belief from target | witnessed | Ambition |
| **Cultivate Informant** | — | money (recurring) | passive detection in a graph region | — | Security |
| **Buy Belief** | know that target holds it | money | acquire belief; cheaper from the disloyal | seller knows you have it | Ambition |

#### Dig — resolving partial beliefs

```
Dig { target: Belief, field: actor | instrument | motive | verify(field) }
```

Success chance is a function of: surviving traces for that event, your graph
distance from people close to it, Observant, current heat, and **turns
elapsed** — traces decay, so cold cases go cold. That decay creates urgency and
makes Lie Low a real defensive option.

Four outcomes:

1. **Resolve** — true value fills in, confidence jumps
2. **Corroborate** — no new field, confidence rises
3. **Collapse** — no supporting trace exists (fabrication, or you're wrong);
   confidence craters and the credibility of whoever told you takes a hit
4. **False resolve** — a confident, plausible, *wrong* answer

Failed digs must not simply return "nothing found." Weight the false answer
toward whoever already has known motive — same mutation logic as rumor
transmission.

**Digging emits its own trace.** *"Marco has been asking about the warehouse
fire"* reaches the real culprit, who now has warning and a specific reason to
move against you. Investigation as a visible, dangerous act is one of the best
tension sources in the design.

A dig may also reveal *who else holds this belief* — the one useful level of
meta-knowledge, and what tells you whether a secret is still worth
blackmailing over.

### Whisper

| Action | Requires | Cost | Effects | Emits | Serves |
|---|---|---|---|---|---|
| **Spread Rumor** `D` | held belief | — | transmit to chosen targets | source trace at low hop count | Vengeance, Ambition |
| **Fabricate** | — | — | creates belief with no backing event | collapses under Dig | Vengeance |
| **Plant Evidence** | knowledge of an event | money | creates a **real trace** with `points_to` = your victim | survives Dig | Vengeance |
| **Leak to Rival** | belief + knowledge of a hostile pair | — | deliver belief anonymously to whoever it hurts most | — | Vengeance |

### Strike

| Action | Requires | Cost | Effects | Emits | Serves |
|---|---|---|---|---|---|
| **Sabotage Job** `D` | know target's assignment | — | job fails, target −standing | physical | Ambition, Vengeance |
| **Frame** | unattributed known event + plausible motive exists | — | belief pointing at victim | — | Vengeance, Ambition |
| **Blackmail** | held damaging belief above threshold | — | target complies / pays / abstains | target now has motive vs. you | Wealth, Ambition |
| **Denounce** | belief above threshold, rank gap not too large | standing at risk | triggers **Judgment** | public | Ambition |
| **Challenge** | standing within threshold of superior's | standing at risk | contest for their position; loser demoted | public | Ambition |
| **Intimidate** | rank/standing advantage | −opinion | target abstains against you for N turns | witnessed | Security |
| **Kill** `D` | opportunity or instrument | heat | removal → vacancy contest | heavy traces | Ambition, Vengeance |

### Cover

| Action | Requires | Cost | Effects | Emits | Serves |
|---|---|---|---|---|---|
| **Lie Low** | — | forfeits turn | accelerates trace decay, reduces heat | — | Security |
| **Buy Alibi** | — | money | reduces `P(attributed to me)` | — | Security |
| **Destroy Evidence** | know a specific trace | money | removes it | small trace | Security |
| **Buy Silence** | know someone holds a trace | money | they suppress it — and gain a secret about you | — | Security |
| **Confess Small Thing** | — | minor standing | +opinion(patron), lowers suspicion on larger matters | — | Security |

### Command *(rank-gated)*

| Action | Requires | Cost | Effects | Emits | Serves |
|---|---|---|---|---|---|
| **Assign Job** | rank > target | — | choose who succeeds or fails | — | Ambition, Vengeance |
| **Protect** | rank | standing | shield a subordinate from Judgment | public | Loyalty |
| **Advocate** | rank + vacancy | — | push a subordinate into a slot | — | Security |
| **Demote / Expel** | rank + evidence | standing | strip subordinate's rank | public | Ambition |
| **Take Tribute** | subordinates | −opinion | +money | resentment | Wealth |

---

## Demo scope

Headless. No graphics, no player. Pure code and a log.

**Actions:** Take Job, Sabotage Job, Dig, Spread Rumor, Kill, Assign Job,
Denounce.

The last two are included because they let the tree actually change shape and
give Judgment something to chew on.

**Traits:** three. Suggested — Reckless, Paranoid, Observant.

**Rank change:** one mechanism only — Removal → contest.

**Scale:** 12–20 characters, 100–200 turns.

### Falsification test

Read the chronicle and ask:

1. Can you reconstruct **why** things happened?
2. Does at least one **misattribution cascade** appear — someone punished for
   something they didn't do?

If both, within 100 turns from seven verbs, the engine works and everything
after is content and UI.

If the log reads as a random walk, the problem is in the **belief layer**, not
the action count. Adding verbs will only hide it.

### Log format

The scorer emits its top two contributing terms with every chosen action:

```
T14 — Marco sabotages Vito's shipment, anonymously.
      (ambition 0.6 · resentment: passed over T9 · judged risk low — Reckless)
      Traces: physical evidence at the warehouse (found T16 by Sal),
              motive known to 3.
```

Debugger and shipped end-of-turn report in one artifact.