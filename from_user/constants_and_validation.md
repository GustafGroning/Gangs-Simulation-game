# Gangs — Tuning & Validation

**Document 4 of 5.** Every tunable number in one place, plus the harness that
tells you whether a change to any of them helped.

Depends on all prior documents. This is the file you will edit most often.

---

## Why this matters more than it looks

The falsification test in the GDD is currently *a human reads a log and decides
whether it's interesting*. That works once. It does not tell you whether
raising γ from 0.85 to 0.88 improved anything, and it does not scale to the
fifty runs you will do while tuning.

Most failures in this design are **silent**. The sim keeps running, no error is
thrown, and the output is simply boring. Metrics and assertions are how you
find those. Budget real time for this document's contents — it is not overhead
on the demo, it *is* the demo.

---

## 1. `config/tuning.gd`

One static class. No magic numbers anywhere else in the codebase — add a CI
grep for float literals in `ai/` and `info/`.

```gdscript
class_name Tuning
```

### Scoring

| Constant | Default | Notes |
|---|---|---|
| `GAMMA` | 0.85 | Plan step discount per remaining step |
| `CONTINUATION_BONUS` | 0.15 | Applied to current plan's next step |
| `MAX_PLAN_DEPTH` | 4 | Deeper reads as inhuman |
| `DEFAULT_PATIENCE` | 8 | Turns before a plan is abandoned |
| `FRUSTRATION_THRESHOLD` | 3 | Failures before escalate-or-abandon |
| `SOFTMAX_TOP_N` | 5 | Candidates entering selection |
| `REPETITION_PENALTY` | 0.12 | Same action+target as last turn |
| `RISK_SCALE` | 1.0 | Global multiplier on `perceived_risk` |
| `RISK_CAP` | 0.9 | Max risk contribution — prevents total paralysis |
| `AFFINITY_BONUS` | 0.10 | Per matching trait tag |

### Attention

| Constant | Default |
|---|---|
| `ATTENTION_SIZE` | 6 |
| `ATTENTION_PARANOID_BONUS` | 3 |
| `ATTENTION_RANDOM_SLOTS` | 1 |
| `BELIEF_RECENCY_WINDOW` | 6 |

### Trait distortions

| Constant | Default |
|---|---|
| `CRAVEN_SEVERITY_MULT` | 1.8 |
| `RECKLESS_DETECT_MULT` | 0.5 |
| `PARANOID_THREAT_MULT` | 1.6 |
| `PARANOID_CONF_THRESHOLD` | 0.25 | vs. `DEFAULT_CONF_THRESHOLD` 0.5 |
| `OBSERVANT_DETECT_ACCURACY` | 0.85 | Estimate error reduction |
| `SLY_ATTRIB_ACCURACY` | 0.85 |
| `CALCULATING_TEMP_MULT` | 0.5 |
| `RECKLESS_TEMP_MULT` | 1.6 |

### Weight dynamics

| Constant | Default |
|---|---|
| `WEIGHT_DECAY_RATE` | 0.03 | Per turn, toward `goal_baseline` |
| `VENGEANCE_SATISFY_MULT` | 0.4 | Multiplier after acting successfully |
| `PASSED_OVER_AMBITION` | 0.20 |
| `PASSED_OVER_VENGEANCE` | 0.30 |
| `PATRON_KILLED_VENGEANCE` | 0.50 |
| `SURVIVED_ATTEMPT_SECURITY` | 0.40 |
| `PROMOTED_AMBITION` | −0.15 |
| `DEBT_WEALTH` | 0.30 |
| `FAVOR_LOYALTY` | 0.10 |

### Information layer

| Constant | Default | Notes |
|---|---|---|
| `TRACE_DECAY_RATE` | 0.06 | Per turn on `detectability` |
| `TRACE_MIN_DETECT` | 0.02 | Floor before removal |
| `HOP_CONFIDENCE_DECAY` | 0.15 | Per transmission hop |
| `ACTOR_MUTATION_CHANCE` | 0.18 | **Tune this first if misattribution is absent** |
| `MUTATION_MOTIVE_BIAS` | 0.7 | How strongly mutation prefers known-motive suspects |
| `DIG_BASE_SUCCESS` | 0.45 |
| `DIG_FALSE_RESOLVE_CHANCE` | 0.15 |
| `DIG_TRACE_DETECTABILITY` | 0.35 | Digging is visible |
| `REPORT_BASE_CHANCE` | 0.5 |
| `REPORT_SELF_IMPLICATION_MULT` | 0.1 |
| `ATTENTION_BUDGET_SUPERIOR` | 4 | Reports processed per turn |

### Economy, contest, judgment, heat

| Constant | Default |
|---|---|
| `JOBS_PER_TURN` | 2 |
| `JOB_LIFETIME` | 4 |
| `JOB_EXPIRY_PENALTY` | 2.0 |
| `COMPETENCE_WEIGHT` | 0.6 |
| `ADVOCACY_WEIGHT` | 8.0 |
| `CONTEST_NOISE` | 3.0 |
| `LATERAL_THRESHOLD` | 10.0 |
| `HEAT_DECAY` | 0.04 |
| `HEAT_KILL` | 0.15 |
| `LIE_LOW_HEAT_RELIEF` | 0.01 |
| `JUDGMENT_NOISE` | 0.08 |
| `CORROBORATION_WEIGHT` | 0.12 |
| `ACCUSER_STANDING_WEIGHT` | 0.3 |
| `ACCUSED_STANDING_WEIGHT` | 0.25 |
| `PROTECTION_WEIGHT` | 0.25 |

### Tuning order

Stated in the action-choice doc, repeated here because it is the thing most
often ignored:

```
RISK_SCALE  →  GAMMA / CONTINUATION_BONUS  →  goal weight variance  →  temperature
```

Later knobs are meaningless if the earlier ones are wrong. A monoculture caused
by risk paralysis will not be fixed by raising temperature — it will just
become a *random* monoculture.

---

## 2. Metrics

Emitted per run as a single JSON blob alongside the chronicle. All are
computable from the event ledger and end-state.

### Health metrics — is the sim alive?

| Metric | Target | Failure meaning |
|---|---|---|
| `action_entropy` | > 2.0 bits | Monoculture — cast is homogeneous |
| `unique_actions_used` | ≥ 80% of enabled | Some verbs are dead weight |
| `actions_per_char_variance` | > 0 | Everyone behaving identically |
| `lie_low_fraction` | < 0.25 | Stasis — risk overweighted |
| `deaths_per_100_turns` | 2–6 | > 10 bloodbath, 0 stasis |
| `rank_changes_per_100_turns` | 4–12 | 0 means the tree is frozen |

### Story metrics — is it interesting?

| Metric | Target | Notes |
|---|---|---|
| `misattribution_rate` | > 0.15 | **The single most important number.** Fraction of hostile events where the plurality belief names the wrong actor |
| `confident_falsehoods` | ≥ 3 per 100 turns | Beliefs at confidence > 0.6 that are factually wrong |
| `mean_belief_accuracy` | 0.5–0.8 | 1.0 = no information game; < 0.4 = noise |
| `plan_completion_rate` | 0.25–0.6 | Low = plans never persist; high = no interference |
| `mean_plan_length_at_execution` | > 1.8 | 1.0 means planning isn't happening |
| `escalation_events` | > 0 | Frustration ladder firing |
| `feuds` | ≥ 2 | Pairs with sustained mutual vengeance > 0.4 for 10+ turns |
| `judgments_per_100_turns` | 2–8 | 0 means Denounce is never worth it |
| `dismissed_verdict_fraction` | 0.2–0.5 | All-dismissed = accusations are toothless |

`misattribution_rate` is the falsification test made numeric. If it is near
zero, the belief layer is decorative and the game is a utility-AI brawl with
extra steps. Check `ACTOR_MUTATION_CHANCE`, `DIG_FALSE_RESOLVE_CHANCE`, and
whether traces are wrongly revealing `ACTOR`.

### Economy metrics

| Metric | Target |
|---|---|
| `standing_gini` | 0.2–0.5 |
| `standing_runaway` | false — no character > 3× median |
| `job_fill_rate` | > 0.8 |
| `mean_heat` | 0.15–0.45 |
| `inert_characters` | 0 — nobody stuck doing nothing for 20+ turns |

---

## 3. Runtime assertions

Run every turn in debug. These catch the silent failures.

**Schema invariants** — all ten from doc 1.

**Belief-layer invariants:**

- No belief references an event from a future turn.
- No belief exists without a backing event or `fabricated == true`.
- Confidence never exceeds 1.0 or increases without a corroborating source.
- A fabricated belief that survives a successful `Dig` is a bug.

**AI invariants — the important ones:**

- `requires()` returned true for every executed action, re-checked at execution.
- Every candidate's `contributions` dictionary is non-empty.
- **No code under `ai/` touched `world.events`.** Enforce with a debug-mode
  access flag on `WorldState`: set on read, asserted clear after each scorer
  call. This is the rule an agent is most likely to break, because reading
  ground truth makes the AI "smarter" and every symptom of the violation looks
  like an improvement.
- Every utility magnitude from `evaluate()` is within −1..1. **Hard error, not
  a clamp** — silent clamping hides an unnormalized action forever.
- The scorer never branches on action identity (review rule; not
  machine-checkable).

**Determinism:**

- Same seed + same config → identical event ledger hash. Run this in CI on
  every commit; it catches accidental global RNG use immediately.

---

## 4. The harness

### Single run

```
gangs --seed 1234 --turns 200 --config default --out runs/
```

Outputs: `chronicle.txt` (human-readable), `metrics.json`, `events.jsonl`,
`world_summary.txt`, `final_state.json`.

### Sweep

```
gangs --sweep --seeds 1..50 --turns 200 --out sweeps/
```

Aggregates metrics across seeds: mean, stddev, and **fraction of runs failing
each target band**. That last one is what you actually tune against — a
configuration where 40% of runs come out as bloodbaths is broken even if the
mean looks fine.

### Parameter sweep

```
gangs --sweep --seeds 1..20 --vary RISK_SCALE=0.6,0.8,1.0,1.2,1.4
```

Prints a table of metric means per value. This is how `RISK_SCALE` gets set in
twenty minutes instead of a week of guessing.

### Golden-file regression

Store the event-ledger hash for three fixed seeds. Any tuning change that alters
them is *expected* to; the point is that a **code** change that alters them
without a tuning change is a bug. Keep the two commits separate so the diff is
attributable.

---

## 5. The chronicle

The human-readable output, and the shipped end-of-turn report. Format from the
action-choice doc:

```
── TURN 14 ─────────────────────────────────  heat 0.31

  Marco sabotages Vito's shipment (anonymous)
    ambition 0.62 · vengeance[Vito] 0.44 — passed over T9
    risk judged 0.11 (Reckless: detection ×0.5)
    → traces: physical @ warehouse (det 0.5)

  Sal digs into the T9 promotion
    → false resolve: believes Rosa arranged it (conf 0.55)

  Vito's shipment job FAILS. standing −6.4
    → belief spreads: 4 holders, 1 names Marco, 2 name nobody

  ▸ Rosa acquires Vengeance[Marco] 0.3 (rumour, conf 0.4)
```

Design rules for the chronicle:

- **Every line names its two top contributing terms.** This is the debugger.
- **Print beliefs, not truth**, when reporting what characters think. Mark
  ground truth with a distinct sigil so you can see the divergence at a glance.
- **Flag divergence explicitly**: when the plurality belief about an event
  differs from the truth, print a marker. Those markers are the misattributions,
  and skimming for them is how you evaluate a run in thirty seconds.
- A per-character **arc summary** at the end of the run: standing over time,
  rank changes, plots attempted and completed, who they ended up hating.

If reading the chronicle is a chore, the game will be too — the chronicle *is*
the game's core output, just without a UI on it yet.

---

## 6. Ablation tests

Once the sim runs, these tell you which systems are earning their place. Run
each for 20 seeds and compare metrics against baseline.

| Ablation | Expected effect if the system matters |
|---|---|
| Disable belief layer (AI reads truth) | `misattribution_rate` → 0; if other metrics barely move, **the information model is decorative and needs rework** |
| Disable plans | `mean_plan_length` → 1, expect bloodbath |
| Disable traits (all identical) | `action_entropy` collapse |
| Disable exogenous events | Metrics flatten after ~turn 60 |
| Disable heat | Deaths per 100 turns spikes |
| Disable planted hooks | First 20 turns go inert |

The first row is the real experiment. If the sim is just as interesting with
the AI reading ground truth, then all the machinery in `gangs-design.md` is
elaborate decoration, and that is the most valuable negative result you could
get — worth knowing in week one rather than month six.

---

## 7. What "it works" looks like

A run passes when, across 20 seeds at 200 turns:

1. All health metrics in band in > 80% of runs.
2. `misattribution_rate` > 0.15 in > 80% of runs.
3. Reading three chronicles at random, you can reconstruct **why** each major
   event happened.
4. At least one run contains an event that surprises you.

Point 4 is not measurable and is the actual bar. The metrics exist to get you
to a state where point 4 becomes likely.

---

**Next:** Document 5 — Implementation Tasks.