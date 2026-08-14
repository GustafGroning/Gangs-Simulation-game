# Gangs — Content Spec

**Document 3 of 5.** The things the simulation acts *on*: jobs, the slot
economy, and the shocks that come from outside the tree.

Depends on `gangs-state-schema.md`. Constants live in `config/tuning.gd`.

---

## Why this document exists

Several actions in the GDD have `requires: job available` and several outcomes
depend on a vacancy existing, but neither jobs nor slot dynamics were ever
specified. Without them the demo has nothing to *do* between plots.

Jobs also serve a subtler purpose: **they are the game's honest clock.** They
generate standing, money, traces, and — critically — assignments, which is what
gives Assign Job and Sabotage Job something to bite on. A world with no jobs
degenerates into pure social manoeuvring with no substrate.

---

## 1. Jobs

### Structure

```gdscript
class_name Job extends RefCounted

var id: int = -1
var kind: StringName = &""
var turn_posted: int = 0
var expires_turn: int = 0
var difficulty: float = 0.5          # 0..1
var payout_money: int = 0
var payout_standing: float = 0.0
var assigned_to_id: int = -1         # -1 = unassigned
var assigned_by_id: int = -1         # -1 = self-selected
var resolved: bool = false
var outcome: int = JobOutcome.PENDING
var sabotaged_by_id: int = -1        # ground truth, never read by AI
var min_rank: int = 3
var max_rank: int = 0
```

```gdscript
enum JobOutcome { PENDING, SUCCESS, PARTIAL, FAILURE, DISASTER }
```

### Job kinds

Six is plenty. Each is a different risk/reward/trace profile, which is what
makes assignment a meaningful choice.

| Kind | Difficulty | Money | Standing | Trace profile | Rank band |
|---|---|---|---|---|---|
| **Collection** | 0.2 | Low | Low | Minimal | 2–3 |
| **Delivery** | 0.3 | Med | Low | Physical, low detectability | 2–3 |
| **Shakedown** | 0.45 | Med | Med | Eyewitness, moderate | 1–3 |
| **Heist** | 0.7 | High | High | Physical + eyewitness, high | 1–2 |
| **Negotiation** | 0.5 | Low | High | Public, no incriminating trace | 0–2 |
| **Enforcement** | 0.65 | Low | High | Violent, generates heat | 1–3 |

**Negotiation is deliberately the standing-per-risk bargain.** It's how a
patient character climbs without exposure — the mechanical expression of "slow
down and build up." Heist is its opposite: the fastest climb and the biggest
trail. If those two feel meaningfully different to play, jobs are tuned right.

### Generation

```gdscript
JOBS_PER_TURN        = 2      # ±1 jitter
JOB_LIFETIME         = 4      # turns before expiry
JOB_BOARD_MAX        = 8
```

Draw kind by weighted pick, then jitter difficulty and payouts ±20%. Scale
payouts by difficulty so high-risk jobs are genuinely worth it — otherwise
everyone takes Collections forever and the tension drains out.

**Unfilled jobs matter.** A job that expires unassigned costs the responsible
superior standing (`−JOB_EXPIRY_PENALTY`). This is what makes Assign Job a
duty and not just a weapon: a superior who spends every assignment sabotaging
a rival is neglecting the board, and it shows in their own standing.

### Assignment

Two paths:

- **Self-selection** — `Take Job` / `Volunteer`, gated on rank band. First
  come, resolved in the turn's action order.
- **Directed** — `Assign Job` by a superior. Overrides self-selection and sets
  `assigned_by_id`.

Directed assignment is where the good evil lives. Give the difficult job to the
rival; give the safe one to your favourite. The scorer picks this up for free
because `AssignJob.evaluate` reads `vengeance[target]` against expected failure
probability.

### Resolution

```gdscript
p_success = clamp(
    0.5
    + (competence - difficulty) * COMPETENCE_WEIGHT
    + rank_bonus
    - sabotage_penalty
    + rng.randfn(0, 0.12),
    0.05, 0.95)
```

Outcome bands: `>0.75 SUCCESS` · `0.45–0.75 PARTIAL` · `0.15–0.45 FAILURE` ·
`<0.15 DISASTER`.

| Outcome | Money | Standing | Heat | Traces |
|---|---|---|---|---|
| SUCCESS | full | full | — | kind's normal profile |
| PARTIAL | half | small | — | normal |
| FAILURE | none | `−payout_standing × 0.8` | +small | normal + a failure trace |
| DISASTER | none | `−payout_standing × 1.5` | +large | heavy, plus possible arrest |

**Attribution of failure is the interesting part.** A failed job creates an
Event whose `actor` is the assignee — but if it was sabotaged, a separate Event
exists with the saboteur as actor, and its traces may or may not surface. So
the default reading of a failure is "you're incompetent," and proving otherwise
requires investigation. That asymmetry is what makes Sabotage Job strong and
Dig valuable.

DISASTER on a violent job may trigger an arrest (see §3), removing a character
temporarily and opening a slot without anyone being blamed.

---

## 2. The slot economy

### Vacancy sources

| Source | Frequency | Blame attaches? |
|---|---|---|
| Death (Kill) | Player/NPC-driven | Yes — heavy traces |
| Exile (Judgment) | Judgment-driven | Yes — publicly |
| Demotion (Judgment / Demote) | Judgment-driven | Yes |
| Arrest (job DISASTER, heat event) | Exogenous | **No** |
| Defection | NPC-driven | Partially |
| Expansion | Exogenous, rare | No |

The **arrest** row is doing important work: it's the only vacancy source with
no culprit. Without it, every promotion in the game is downstream of somebody's
crime, and the world reads as unrelentingly murderous. Arrests give the tree
natural churn and let a patient character get promoted having done nothing
wrong — which is a legitimate strategy and should be visible in the log.

### The contest

When a slot goes vacant, at end of turn:

```gdscript
claim_score = standing
            + ADVOCACY_WEIGHT * Σ(advocacy from ranks above)
            + PROXIMITY_BONUS  if previously in that slot's crew
            + rng.randfn(0, CONTEST_NOISE)
```

Eligible: characters exactly one rank below the vacant slot, plus same-rank
characters within `LATERAL_THRESHOLD` standing (a sideways move to a better
position).

Advocacy comes from `Advocate` actions in the last N turns, weighted by the
advocate's rank. `CONTEST_NOISE` should be small but nonzero — an upset
occasionally is good, an upset usually is noise.

**Losers of a contest take `Vengeance[winner] += 0.3` and `AMBITION += 0.2`.**
Every promotion manufactures its own next conflict. This is the engine of the
mid-game and it needs no authoring.

### Expansion and contraction

- **Expansion**: on a run of organization-wide success (heat low, jobs
  succeeding), rarely create a new slot. Gives Advocate something to do without
  requiring a death.
- **Contraction**: after sustained disaster, delete a vacant slot. Prevents the
  tree from hollowing out into a stub after a bloody stretch.

Both should be rare — a few times per 200 turns. Their purpose is to keep the
tree from being strictly zero-sum, not to be a mechanic the player engages with.

---

## 3. Exogenous events

Without external input the social graph settles into equilibrium and the late
game goes flat. These are cheap to author and reshuffle everything.

```gdscript
class_name ExoEvent extends RefCounted

var kind: StringName = &""
var turn: int = 0
var affected_ids: Array[int] = []
var payload: Dictionary = {}
```

### The table

| Event | Trigger | Effect |
|---|---|---|
| **Police pressure** | Heat > 0.6 | Detection ×1.5, all violent actions' severity ×1.4 for N turns |
| **Arrest** | Heat spike or job DISASTER | Character removed for 5–15 turns or permanently; slot vacated with no blame |
| **Rival hit** | Random, low freq | A random character killed by outsiders. **Everyone suspects an insider anyway.** |
| **The big score** | Every 20–30 turns | An exceptional job; whoever gets assigned gains or loses enormously |
| **Lean times** | Random | Job payouts halved for N turns; Wealth weights spike cast-wide |
| **The informant** | Heat sustained high | Someone in the tree is leaking to police — identity unknown, generates a paranoia wave |
| **Family trouble** | Random, per character | Money demand; failure to pay spikes desperation |
| **Outside offer** | Random, per character | A rival org offers a position — enables Defection |

**Rival hit is the best one in the table.** An outsider kills a member, no
insider is responsible, and the belief system dutifully manufactures suspects
anyway because the traces point nowhere and everyone with known motive looks
guilty. It's a free misattribution cascade and a direct test of whether your
belief layer works.

**The informant** is the strongest paranoia generator: a true fact (someone is
leaking) with no discoverable actor, which sends every PARANOID character into
investigation and accusation. Cap its frequency — it's potent enough to
dominate a run.

### Pacing

```gdscript
EXO_BASE_CHANCE      = 0.15   # per turn
EXO_COOLDOWN         = 3      # turns between exogenous events
EXO_HEAT_SCALING     = true   # pressure events more likely at high heat
```

Roughly one shock every 6–8 turns. Frequent enough that equilibrium never
sets in, rare enough that emergent conflict still dominates.

---

## 4. Judgment

The adjudication procedure for `Denounce`. This is where the information system
cashes out in public, so it deserves precise rules.

### Judge selection

The highest-ranked character who is:

1. not the accuser, not the accused
2. not the patron of either (too invested)
3. active

If none qualifies, fall to the next rank down. If the accused *is* the boss,
the highest-ranked uninvolved subordinate judges — a genuinely dangerous
proposition for everyone involved, which is correct.

### Adjudication

```gdscript
case_strength = judge_belief_confidence
              + CORROBORATION_WEIGHT * n_corroborating_holders
              + ACCUSER_STANDING_WEIGHT * (accuser.standing / 100.0)
              - ACCUSED_STANDING_WEIGHT * (accused.standing / 100.0)
              - PROTECTION_WEIGHT       if accused is Protected
              + rng.randfn(0, JUDGMENT_NOISE)
```

**The judge uses their own belief state.** If the judge doesn't hold a belief
about the alleged event, `judge_belief_confidence` is 0 and the case rests
entirely on the accuser's standing — which is exactly right. A powerful person
can get a weak case through; a nobody with the truth often cannot.

Verdict bands:

| case_strength | Verdict | Consequences |
|---|---|---|
| < 0.25 | DISMISSED | Accuser −standing, accused `Vengeance[accuser] += 0.4` |
| 0.25–0.5 | DEMOTED | Accused loses rank, slot contest triggered |
| 0.5–0.75 | EXILED | Removed from tree, slot vacated |
| > 0.75 | KILLED | Removed, slot vacated, heat +large |

### Judgment side effects

- The verdict is a **public Event**: everyone acquires a belief about it at
  high confidence. Judgment is the one reliable broadcast channel in the game.
- Whether the accused was *actually* guilty is never checked. The system
  adjudicates beliefs. This is the single most important line in this document.
- A DISMISSED verdict damages the accuser's credibility, reducing the weight of
  their future beliefs during transmission. Serial accusers become ignorable —
  which is both realistic and a real cost on the Denounce action.
- `Protect` by a superior applies `PROTECTION_WEIGHT` and costs the protector
  standing if the verdict lands anyway.

---

## 5. Heat

One organization-wide float, 0..1.

**Rises:** violent Events (+0.15 for a kill, +0.05 for enforcement), job
DISASTERs, arrests, Judgment verdicts of KILLED.

**Falls:** `HEAT_DECAY = 0.04`/turn, plus an extra decrement for each character
who spent the turn on `Lie Low`.

**Effects at high heat:** detection probability ×`(1 + heat)`, severity
estimates ×`(1 + heat × 0.5)`, higher chance of police-pressure exogenous
events, arrests more likely.

Heat is the rhythm mechanism. After a murder everyone is watching, plots are
harder, and the correct play is to be boring for three turns. That enforced
lull is what stops the sim from being an undifferentiated stream of violence —
if the first run comes out as a bloodbath, heat scaling is the second thing to
check after risk weighting.

---

## 6. Content smoke test

Run 100 turns with only Take Job and Assign Job enabled. Assert:

1. Job board never empties for more than 2 consecutive turns, never overflows.
2. Outcome distribution roughly 30/30/30/10 across SUCCESS/PARTIAL/FAILURE/DISASTER.
3. Standing does not run away — spread across the cast stays bounded.
4. No character reaches standing 0 and becomes permanently inert.
5. Heat returns to < 0.2 within 10 turns of the last violent event.
6. Exogenous events fire at roughly the configured rate.
7. All jobs eventually resolve or expire; none leak.

If standing runs away in this test, no amount of AI tuning will save the full
sim — the economy has to be stable before the politics sit on top of it.

---

**Next:** Document 4 — Tuning Constants & Validation Harness.