class_name Tuning
# Doc 4 §1 — every tunable number in the sim. No magic numbers anywhere else;
# if a value you need is missing, add it HERE with a comment, don't inline it.
# The CI grep in ci/ enforces determinism, review enforces this.
#
# Tune in this order (doc 4): RISK_SCALE → GAMMA / CONTINUATION_BONUS →
# goal weight variance → temperature. Later knobs are meaningless if the
# earlier ones are wrong.

# ---- Scoring ----
const GAMMA: float = 0.85                    # plan step discount per remaining step
const CONTINUATION_BONUS: float = 0.15       # applied to current plan's next step
const MAX_PLAN_DEPTH: int = 4                # deeper reads as inhuman
const DEFAULT_PATIENCE: int = 8              # turns before a plan is abandoned
const FRUSTRATION_THRESHOLD: int = 3         # failures before escalate-or-abandon
const SOFTMAX_TOP_N: int = 5                 # candidates entering selection
const REPETITION_PENALTY: float = 0.12       # same action+target as last turn
const RISK_SCALE: float = 1.0                # global multiplier on perceived_risk
const RISK_CAP: float = 0.9                  # max risk contribution — prevents total paralysis
const AFFINITY_BONUS: float = 0.10           # per matching trait tag

# ---- Attention ----
const ATTENTION_SIZE: int = 6
const ATTENTION_PARANOID_BONUS: int = 3
const ATTENTION_RANDOM_SLOTS: int = 1
const BELIEF_RECENCY_WINDOW: int = 6

# ---- Trait distortions ----
const CRAVEN_SEVERITY_MULT: float = 1.8
const RECKLESS_DETECT_MULT: float = 0.5
const PARANOID_THREAT_MULT: float = 1.6
const PARANOID_CONF_THRESHOLD: float = 0.25  # Paranoid acts on beliefs this confident
const DEFAULT_CONF_THRESHOLD: float = 0.5
const OBSERVANT_DETECT_ACCURACY: float = 0.85  # estimate error reduction
const SLY_ATTRIB_ACCURACY: float = 0.85
const CALCULATING_TEMP_MULT: float = 0.5
const RECKLESS_TEMP_MULT: float = 1.6

# ---- Weight dynamics ----
const WEIGHT_DECAY_RATE: float = 0.03        # per turn, toward goal_baseline
const VENGEANCE_SATISFY_MULT: float = 0.4    # multiplier after acting successfully
const PASSED_OVER_AMBITION: float = 0.20
const PASSED_OVER_VENGEANCE: float = 0.30
const PATRON_KILLED_VENGEANCE: float = 0.50
const SURVIVED_ATTEMPT_SECURITY: float = 0.40
const PROMOTED_AMBITION: float = -0.15
const DEBT_WEALTH: float = 0.30
const FAVOR_LOYALTY: float = 0.10

# ---- Information layer ----
const TRACE_DECAY_RATE: float = 0.06         # per turn on detectability
const TRACE_MIN_DETECT: float = 0.02         # floor before removal
const HOP_CONFIDENCE_DECAY: float = 0.15     # per transmission hop
const ACTOR_MUTATION_CHANCE: float = 0.18    # tune this FIRST if misattribution is absent
const MUTATION_MOTIVE_BIAS: float = 0.7      # how strongly mutation prefers known-motive suspects
const DIG_BASE_SUCCESS: float = 0.45
const DIG_FALSE_RESOLVE_CHANCE: float = 0.15
const DIG_TRACE_DETECTABILITY: float = 0.35  # digging is visible
const REPORT_BASE_CHANCE: float = 0.5
const REPORT_SELF_IMPLICATION_MULT: float = 0.1
const ATTENTION_BUDGET_SUPERIOR: int = 4     # reports processed per turn

# ---- Economy, contest, judgment, heat ----
# Doc 4 default was 2; raised to 3 for the 16-character bootstrap cast in
# phase 2 (see thoughts/phase_2 report) — but that was under the phase-2
# *scaffold* selection policy, which had an explicit "contested takes go to
# the longest-idle" anti-starvation rule. The phase-4 scorer replaced that
# wholesale with goal-driven best-fit choice and no such tiebreak, so the
# same supply that was enough for the scaffold under-serves the
# lowest-rank tier again: rank-3 characters have the smallest eligible job
# menu (locked out of heist/negotiation, doc 3 §1 rank bands) and the
# largest population competing over it, and under the scorer's
# deterministic best-fit ranking, the same low-fit individuals keep losing
# every turn instead of the scaffold's rotation. Raised to 5 — at 3-4,
# 2-11/20 seeds (of tests/test_phase4.gd's 20) still had characters idle
# 20+ consecutive turns; at 5 none did. See thoughts/phase_4 report.
const JOBS_PER_TURN: int = 5
const JOB_LIFETIME: int = 4
const JOB_EXPIRY_PENALTY: float = 2.0
# Doc 4 default was 0.6; at 0.6 the outcome value distribution is too narrow
# for the doc-3 bands (SUCCESS ~14%, DISASTER ~0%) — 1.0 spreads outcomes by
# competence-vs-difficulty, which is also what makes assignment matter.
const COMPETENCE_WEIGHT: float = 1.0

# Job content (doc 3 §1). Kind table: base difficulty/payouts, rank band
# (max_rank = highest position, min_rank = lowest), generation weight,
# whether working it is a violent act (heat).
const JOB_KINDS := {
	&"collection":  {"difficulty": 0.2,  "money": 25,  "standing": 1.5, "max_rank": 2, "min_rank": 3, "weight": 0.20, "violent": false},
	&"delivery":    {"difficulty": 0.3,  "money": 50,  "standing": 1.5, "max_rank": 2, "min_rank": 3, "weight": 0.20, "violent": false},
	&"shakedown":   {"difficulty": 0.45, "money": 50,  "standing": 3.0, "max_rank": 1, "min_rank": 3, "weight": 0.20, "violent": false},
	&"heist":       {"difficulty": 0.7,  "money": 110, "standing": 6.0, "max_rank": 1, "min_rank": 2, "weight": 0.10, "violent": false},
	&"negotiation": {"difficulty": 0.5,  "money": 25,  "standing": 6.0, "max_rank": 0, "min_rank": 2, "weight": 0.15, "violent": false},
	&"enforcement": {"difficulty": 0.65, "money": 25,  "standing": 6.0, "max_rank": 1, "min_rank": 3, "weight": 0.15, "violent": true},
}
const JOB_BOARD_MAX: int = 8
const JOBS_PER_TURN_JITTER: int = 1
const JOB_JITTER: float = 0.2                # ±fraction on difficulty and payouts
const JOB_RESOLVE_NOISE: float = 0.12        # randfn dev in the resolution formula (doc 3)
const JOB_RANK_BONUS_PER_LEVEL: float = 0.03 # doc 3 names rank_bonus without a value
const JOB_PARTIAL_STANDING_MULT: float = 0.5 # "small" standing on PARTIAL; at 0.3 the median character net-drains
const JOB_FAIL_STANDING_MULT: float = 0.8    # doc 3 outcome table
const JOB_DISASTER_STANDING_MULT: float = 1.5
const JOB_FAIL_HEAT: float = 0.02            # "+small"
const JOB_DISASTER_HEAT: float = 0.08        # "+large"
const HEAT_ENFORCEMENT: float = 0.05         # doc 3 §5: violent job worked

# Standing soft cap (doc 1 §1 declares standing soft-capped without a
# mechanism): positive gains scale down linearly from the knee, bottoming
# at the min multiplier by the cap.
const STANDING_SOFT_KNEE: float = 50.0
const STANDING_SOFT_CAP: float = 85.0
const STANDING_SOFT_MIN_MULT: float = 0.0
const STANDING_LOSS_MIN_MULT: float = 0.25   # losses scale with standing/knee, floored here

# Phase-2 scaffold policy (random action selection until the scorer lands).
# Assign leans high so superiors mostly direct work instead of hoarding
# high-standing jobs themselves.
const SCAFFOLD_ASSIGN_PROB: float = 0.8

# ---- Generation (doc 2; full generator lands in phase 7) ----
const STANDING_BY_RANK := [60.0, 40.0, 25.0, 12.0]
const STANDING_NOISE: float = 4.0
const MONEY_BY_RANK := [200, 120, 60, 30]    # doc 2 names it without values
const MONEY_NOISE: float = 15.0
const TRAIT_COUNT_WEIGHTS := {1: 0.25, 2: 0.50, 3: 0.25}
const TEMPERATURE_MEAN: float = 0.30
const TEMPERATURE_DEV: float = 0.10
const TEMPERATURE_MIN: float = 0.10
const TEMPERATURE_MAX: float = 0.60
const COMPETENCE_MEAN: float = 0.50
const COMPETENCE_DEV: float = 0.18
const COMPETENCE_MIN: float = 0.10
const COMPETENCE_MAX: float = 0.95
const COMPETENCE_RANK_CORR: float = 0.05     # + per rank above soldier
const GOAL_BASE_MEAN: float = 0.45
const GOAL_BASE_DEV: float = 0.22
const GOAL_POLARIZE_UP: float = 0.30
const GOAL_POLARIZE_DOWN: float = 0.25
const OPINION_CHEMISTRY_DEV: float = 0.15
const OPINION_PATRON_TO_CREW: float = 0.10
const OPINION_CREW_TO_PATRON: float = 0.05
const OPINION_SIBLING: float = -0.15

# ---- Metrics thresholds (doc 4 §2) ----
const INERT_TURNS: int = 20
const RUNAWAY_STANDING_RATIO: float = 3.0

# ---- Information layer: perception (added in phase 3; doc 4 §1 has the
# decay/mutation core, these fill the unspecified pieces — see DECISIONS) ----
# First-hand confidence when you found the trace yourself, by trace kind.
const TRACE_KIND_CONFIDENCE := {
	E.TraceKind.EYEWITNESS: 0.8, E.TraceKind.PHYSICAL: 0.6,
	E.TraceKind.HEARSAY: 0.4, E.TraceKind.MOTIVE: 0.35, E.TraceKind.ABSENCE: 0.3,
}
const FIRSTHAND_ACTOR_CONFIDENCE: float = 0.95  # you know what you did
const CORROBORATION_BUMP: float = 0.1        # same claim from a second source
const CONFLICT_PENALTY: float = 0.05         # competing actor claims shave confidence
const OBSERVANT_DETECT_MULT: float = 1.5     # doc 5 phase 3: detection "modified by OBSERVANT"
const DETECT_CAP: float = 0.95
# Observer density by tree distance (0 = self, 1 = patron/crew, ...).
const PROX_BY_DIST := [1.0, 0.6, 0.45, 0.3, 0.15]
# Per-kind eyewitness detectability of worked jobs (doc 3 trace profiles).
const JOB_TRACE_DETECT := {
	&"collection": 0.2, &"delivery": 0.3, &"shakedown": 0.5,
	&"heist": 0.65, &"negotiation": 0.8, &"enforcement": 0.6,
}
const JOB_FAILURE_DETECT_BONUS: float = 0.15 # failures are conspicuous
const ASSIGN_TRACE_DETECT: float = 0.5
# Flat risk-estimate detectability TakeJob uses for the actor's OWN perceived
# risk (Risk.perceived reads action.trace_templates) — deliberately not
# per-kind like JOB_TRACE_DETECT, which governs actual trace emission at
# resolution. See QUESTIONS.md: flat-estimate-vs-actual-detectability gap.
const TAKEJOB_RISK_DETECT_ESTIMATE: float = 0.4
const SABOTAGE_TRACE_DETECT: float = 0.5

# ---- Information layer: gossip and speculation ----
const GOSSIP_BASE_CHANCE: float = 0.3        # per neighbor per recent belief
const GOSSIP_OPINION_WEIGHT: float = 0.5     # like someone → talk to them more
# A rumor with no actor grows one: speculation hardening into attribution.
# Without this no misattribution can exist before Dig lands (phase 6).
const ACTOR_SPECULATION_CHANCE: float = 0.25
const MUTATION_BASE_WEIGHT: float = 0.15     # uniform floor in suspect weighting
# Sibling rivalry is public knowledge — bootstrap known_motive for siblings.
const SIBLING_KNOWN_MOTIVE: float = 0.3

# ---- Scorer (phase 4; doc 4 §1 has the core, these fill unspecified pieces) ----
const TAKEJOB_STANDING_NORM: float = 6.0     # payout normalization for evaluate
const TAKEJOB_MONEY_NORM: float = 110.0
const ASSIGN_DUTY_STANDING: float = 0.25     # duty magnitude for a likely-success assignment
# Risk severity by action tag — severity is DERIVED (from tags + templates),
# never authored per action (hard rule 4).
const RISK_SEVERITY_BY_TAG := {
	E.ActionTag.VIOLENCE: 0.8, E.ActionTag.DECEPTION: 0.4,
	E.ActionTag.INVESTIGATIVE: 0.15, E.ActionTag.PUBLIC: 0.1,
	E.ActionTag.SOCIAL: 0.05, E.ActionTag.ECONOMIC: 0.05,
}
const P_ATTR_ACTOR_REVEALED: float = 0.9     # some template reveals ACTOR
const P_ATTR_BASE: float = 0.2               # anonymous baseline suspicion
const P_ATTR_MOTIVE_WEIGHT: float = 0.3      # public grudge makes you the default suspect
const P_ATTR_ALT_RELIEF: float = 0.05        # per alternative known-motive suspect
# Trait → action-tag affinities (doc: Brutal +violence, Sly +deception).
const TRAIT_TAG_AFFINITY := {
	E.Trait.BRUTAL: [E.ActionTag.VIOLENCE],
	E.Trait.SLY: [E.ActionTag.DECEPTION],
	E.Trait.GREEDY: [E.ActionTag.ECONOMIC],
	E.Trait.OBSERVANT: [E.ActionTag.INVESTIGATIVE],
}
const LOYAL_VETO_SCORE: float = -100.0       # hard veto on hostile acts vs patron
const RISK_HEAT_SEVERITY_MULT: float = 0.5   # perceived severity scales up with heat
const CONTRIBUTION_DISPLAY_THRESHOLD: float = 0.001  # min |term| to surface on the chronicle

# ---- Weight dynamics (phase 4) ----
# Vengeance from believed harm: += severity × confidence × rate, per turn the
# belief updates. Severity by believed action.
const VENGEANCE_HARM_SEVERITY := {
	&"sabotage_job": 0.3, &"kill": 0.8, &"frame": 0.4, &"denounce": 0.3,
}
const VENGEANCE_BELIEF_RATE: float = 0.5

# ---- Information layer: upward reporting ----
const REPORT_VALUE_FLOOR: float = 0.4        # P scales 0.4..1.0 with confidence
const REPORT_PATRON_BASE: float = 0.45       # recipient weight bases
const REPORT_RIVAL_BASE: float = 0.08
const REPORT_OPINION_WEIGHT: float = 0.5
const REPORT_FIDELITY_FLOOR: float = 0.6     # confidence × (floor + span×loyalty)
const REPORT_FIDELITY_SPAN: float = 0.4
const ADVOCACY_WEIGHT: float = 8.0
const CONTEST_NOISE: float = 3.0
const LATERAL_THRESHOLD: float = 10.0
const HEAT_DECAY: float = 0.04
const HEAT_KILL: float = 0.15
const LIE_LOW_HEAT_RELIEF: float = 0.01
const JUDGMENT_NOISE: float = 0.08
const CORROBORATION_WEIGHT: float = 0.12
const ACCUSER_STANDING_WEIGHT: float = 0.3
const ACCUSED_STANDING_WEIGHT: float = 0.25
const PROTECTION_WEIGHT: float = 0.25

# ---- Added during implementation (needed, not in doc 4 §1) ----
# Multiplier on the purchased-opinion channel when computing effective opinion
# (World.opinion_of). Collapse-under-pressure logic lands with the Court
# actions; until then purchased opinion counts at face value.
const PURCHASED_OPINION_MULT: float = 1.0

# ---- Planner (phase 5) ----
# GAMMA, CONTINUATION_BONUS, MAX_PLAN_DEPTH, DEFAULT_PATIENCE and
# FRUSTRATION_THRESHOLD are declared above under Scoring (doc 4 §1 names
# them there). The demo's verb set at phase 5 is still only TakeJob/AssignJob
# (demo_tasks.md phase 5 Goal line) — neither has an actor-achievable
# multi-step precondition chain (no money/standing/rank gate; AssignJob's
# only failing requires() clause, once rank/crew hold, is "no eligible open
# job exists for the target right now", which clears itself via job-board
# refresh, not via another action). True backward-chaining through an
# intermediate action (the doc's DoFavor→Kill example) needs verbs outside
# the 7-verb demo scope (DoFavor is post-demo; Sabotage/Kill are phase 6) —
# see QUESTIONS.md and thoughts/phase_5_planner.md. Plans this phase are
# single-step and gated purely on that job-availability condition, scored
# via Action.plan_value()/gated_recoverably(), persisting across turns via
# DEFAULT_PATIENCE the same way a longer chain would.
# Minimum weighted terminal value (Scorer.weighted_utility) to bother
# forming a plan at all — keeps every job-hungry character from opening a
# plan on every gated target in their attention set.
const PLAN_MIN_TERMINAL_SCORE: float = 0.15
# Assumed job difficulty AssignJob's plan_value() uses to estimate the value
# of assigning a currently-nonexistent job (mean of JOB_KINDS difficulty).
const PLAN_ASSUMED_JOB_DIFFICULTY: float = 0.45
# Goal -> ordered list of action ids, most to least severe: on repeated
# frustration, the planner escalates to the next entry instead of abandoning.
# assign_job escalates to sabotage_job (design_doc.md's "sabotage → frame →
# kill" ladder, truncated to the demo's 7-verb scope — Frame isn't a demo
# verb and Kill is still phase 6). sabotage_job plans have no ladder entry
# of their own, so a frustrated one always abandons — gangs-action-choice.md
# §4's other valid branch, not a fallback of last resort.
const ESCALATION_LADDER := {
	&"assign_job": [&"assign_job", &"sabotage_job"],
}

# ---- SabotageJob (pulled forward from phase 6 — see DECISIONS.md) ----
# Flat Ambition contribution: a rival's stumble is a small win regardless of
# vengeance (design_doc.md: "Serves: Ambition, Vengeance").
const SABOTAGE_AMBITION_MAG: float = 0.15
# Subtracted from the job resolution formula's success value (doc 3 §1's
# `sabotage_penalty` term) when Job.sabotaged_by_id is set — large enough
# that sabotage reliably flips a likely SUCCESS/PARTIAL into FAILURE/
# DISASTER, matching "job fails" in the doc's effect column.
const SABOTAGE_PENALTY: float = 0.35
