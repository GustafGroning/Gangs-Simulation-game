class_name Job
extends RefCounted
# doc 3 §1. The Job struct plus board generation, expiry and resolution.
# Jobs are the game's honest clock: they generate standing, money and
# assignments — the substrate Assign Job and Sabotage Job bite on.

var id: int = -1
var kind: StringName = &""
var turn_posted: int = 0
var expires_turn: int = 0
var difficulty: float = 0.5          # 0..1
var payout_money: int = 0
var payout_standing: float = 0.0
var assigned_to_id: int = -1         # -1 = unassigned
var assigned_by_id: int = -1         # -1 = self-selected
# Turn assignment happened; -1 = unassigned. Not in doc 3's Job struct —
# added in phase 5 so a job spends exactly one turn "in progress" (assigned,
# unresolved) before Job.resolve() runs, per doc 4/5 turn.gd's
# assigned_turn < ws.turn filter. Without a gap, SabotageJob (doc 3 §1: "job
# fails, target −standing", requiring "know target's assignment") would have
# no legal target — same-turn assignment+resolution left no turn where a job
# was assigned but not yet resolved for anyone to intervene on. See
# DECISIONS.md and thoughts/phase_5_planner.md.
var assigned_turn: int = -1
var resolved: bool = false
var outcome: int = E.JobOutcome.PENDING
var sabotaged_by_id: int = -1        # ground truth, never read by AI
var min_rank: int = 3                # lowest tree level allowed (largest number)
var max_rank: int = 0                # highest tree level allowed (smallest number)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"kind": String(kind),
		"turn_posted": turn_posted,
		"expires_turn": expires_turn,
		"difficulty": difficulty,
		"payout_money": payout_money,
		"payout_standing": payout_standing,
		"assigned_to_id": assigned_to_id,
		"assigned_by_id": assigned_by_id,
		"assigned_turn": assigned_turn,
		"resolved": resolved,
		"outcome": outcome,
		"sabotaged_by_id": sabotaged_by_id,
		"min_rank": min_rank,
		"max_rank": max_rank,
	}


static func from_dict(d: Dictionary) -> Job:
	var j := Job.new()
	j.id = int(d["id"])
	j.kind = StringName(str(d["kind"]))
	j.turn_posted = int(d["turn_posted"])
	j.expires_turn = int(d["expires_turn"])
	j.difficulty = float(d["difficulty"])
	j.payout_money = int(d["payout_money"])
	j.payout_standing = float(d["payout_standing"])
	j.assigned_to_id = int(d["assigned_to_id"])
	j.assigned_by_id = int(d["assigned_by_id"])
	j.assigned_turn = int(d.get("assigned_turn", -1))
	j.resolved = bool(d["resolved"])
	j.outcome = int(d["outcome"])
	j.sabotaged_by_id = int(d["sabotaged_by_id"])
	j.min_rank = int(d["min_rank"])
	j.max_rank = int(d["max_rank"])
	return j


func is_open(turn: int) -> bool:
	return not resolved and turn <= expires_turn


func rank_eligible(rank: int) -> bool:
	return rank >= max_rank and rank <= min_rank


# ---- Board ----

# The job this character is currently set to work, if any.
static func assigned_open_job(ws: WorldState, char_id: int) -> Job:
	for j: Job in ws.jobs:
		if j.assigned_to_id == char_id and not j.resolved:
			return j
	return null


# Deterministic success estimate (the resolution value sans noise). Reads the
# worker's competence — treated as public knowledge (work history is visible
# to the whole organization).
static func success_estimate(worker: Character, j: Job) -> float:
	return clampf(
		0.5 + (worker.competence - j.difficulty) * Tuning.COMPETENCE_WEIGHT
		+ (3 - worker.rank) * Tuning.JOB_RANK_BONUS_PER_LEVEL,
		0.05, 0.95)


static func fit(c: Character, j: Job) -> float:
	var base := clampf(0.5 + c.competence - j.difficulty, 0.05, 1.5)
	return base * base


# Best open job for this worker: eligibility-gated, deterministic argmax of
# fit × payout, ties broken on id.
static func best_for(ws: WorldState, worker: Character) -> Job:
	var best: Job = null
	var best_score := -1.0
	for j: Job in open_unassigned(ws):
		if not j.rank_eligible(worker.rank):
			continue
		var score := fit(worker, j) * (0.5 + 0.5 * (j.payout_standing / Tuning.TAKEJOB_STANDING_NORM + float(j.payout_money) / Tuning.TAKEJOB_MONEY_NORM))
		if score > best_score or (score == best_score and best != null and j.id < best.id):
			best = j
			best_score = score
	return best


static func open_unassigned(ws: WorldState) -> Array:
	var out := []
	for j: Job in ws.jobs:
		if j.assigned_to_id == -1 and j.is_open(ws.turn):
			out.append(j)
	return out


static func generate_board(ws: WorldState, chron: Chronicle, metrics: Metrics) -> void:
	var count := Tuning.JOBS_PER_TURN + ws.rng.randi_range(-Tuning.JOBS_PER_TURN_JITTER, Tuning.JOBS_PER_TURN_JITTER)
	var kinds := Tuning.JOB_KINDS.keys()
	var weights := []
	for k in kinds:
		weights.append(float(Tuning.JOB_KINDS[k]["weight"]))
	for i in maxi(0, count):
		if open_unassigned(ws).size() >= Tuning.JOB_BOARD_MAX:
			break
		var kind: StringName = Rng.weighted_pick(kinds, weights, ws.rng)
		var spec: Dictionary = Tuning.JOB_KINDS[kind]
		var j := Job.new()
		j.kind = kind
		j.turn_posted = ws.turn
		j.expires_turn = ws.turn + Tuning.JOB_LIFETIME
		j.difficulty = clampf(float(spec["difficulty"]) * (1.0 + ws.rng.randf_range(-Tuning.JOB_JITTER, Tuning.JOB_JITTER)), 0.05, 0.95)
		j.payout_money = int(roundf(float(spec["money"]) * (1.0 + ws.rng.randf_range(-Tuning.JOB_JITTER, Tuning.JOB_JITTER))))
		j.payout_standing = float(spec["standing"]) * (1.0 + ws.rng.randf_range(-Tuning.JOB_JITTER, Tuning.JOB_JITTER))
		j.max_rank = int(spec["max_rank"])
		j.min_rank = int(spec["min_rank"])
		ws.add_job(j)
		metrics.job_posted()
		chron.line("+ job #%d posted: %s (diff %.2f, $%d, +%.1f st, ranks %d-%d, expires T%d)" % [
			j.id, kind, j.difficulty, j.payout_money, j.payout_standing, j.max_rank, j.min_rank, j.expires_turn])


# Expiry runs at end of turn: a job can still be worked on its expiry turn.
# An unassigned expiry costs the responsible superior standing — the board is
# a duty, not just a weapon. Canon is silent on WHO is responsible; we charge
# the boss (highest-ranked active character) — see DECISIONS.md.
static func expire_open(ws: WorldState, chron: Chronicle, metrics: Metrics) -> void:
	for j: Job in ws.jobs:
		if j.resolved or j.assigned_to_id != -1 or ws.turn < j.expires_turn:
			continue
		j.resolved = true
		j.outcome = E.JobOutcome.PENDING  # never worked
		metrics.job_expired()
		var boss_id := _boss_id(ws)
		if boss_id != -1:
			World.add_standing(ws, boss_id, -Tuning.JOB_EXPIRY_PENALTY)
			chron.line("· job #%d (%s) expires unassigned — %s %.1f st" % [
				j.id, j.kind, (ws.characters[boss_id] as Character).name, -Tuning.JOB_EXPIRY_PENALTY])


static func _boss_id(ws: WorldState) -> int:
	var best := -1
	var best_rank := 999
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.state == E.CharState.ACTIVE and (c.rank < best_rank or (c.rank == best_rank and cid < best)):
			best = cid
			best_rank = c.rank
	return best


# ---- Resolution (doc 3 §1) ----

static func resolve(ws: WorldState, j: Job, chron: Chronicle, metrics: Metrics, chosen_note: String = "") -> Event:
	var worker: Character = ws.characters[j.assigned_to_id]
	# Phase 6: the worker may have been killed/exiled/arrested THIS turn by a
	# higher-priority action or Judgment before their in-flight job reached
	# resolution (jobs.assigned one turn earlier always resolve one turn
	# later — see Job.assigned_turn). Nobody to credit or blame; the job is
	# simply abandoned rather than crediting/penalizing a no-longer-active
	# character.
	if worker.state != E.CharState.ACTIVE:
		j.resolved = true
		j.outcome = E.JobOutcome.PENDING
		var e_abandon := Event.new()
		e_abandon.turn = ws.turn
		e_abandon.actor_id = worker.id
		e_abandon.action = &"take_job"
		e_abandon.visibility = E.Visibility.OPEN
		e_abandon.outcome = {"job_id": j.id, "kind": String(j.kind), "outcome": j.outcome, "abandoned": true}
		ws.add_event(e_abandon)
		metrics.job_abandoned()
		chron.line("· job #%d (%s) abandoned — %s is no longer active" % [j.id, j.kind, worker.name])
		return e_abandon
	var rank_bonus := (3 - worker.rank) * Tuning.JOB_RANK_BONUS_PER_LEVEL
	var sabotage_penalty := Tuning.SABOTAGE_PENALTY if j.sabotaged_by_id != -1 else 0.0
	var value := clampf(
		0.5
		+ (worker.competence - j.difficulty) * Tuning.COMPETENCE_WEIGHT
		+ rank_bonus
		- sabotage_penalty
		+ Rng.randfn(0.0, Tuning.JOB_RESOLVE_NOISE, ws.rng),
		0.05, 0.95)

	var money := 0
	var standing_delta := 0.0
	if value > 0.75:
		j.outcome = E.JobOutcome.SUCCESS
		money = j.payout_money
		standing_delta = j.payout_standing
	elif value >= 0.45:
		j.outcome = E.JobOutcome.PARTIAL
		money = j.payout_money / 2
		standing_delta = j.payout_standing * Tuning.JOB_PARTIAL_STANDING_MULT
	elif value >= 0.15:
		j.outcome = E.JobOutcome.FAILURE
		standing_delta = -j.payout_standing * Tuning.JOB_FAIL_STANDING_MULT
		Heat.add(ws, Tuning.JOB_FAIL_HEAT)
	else:
		j.outcome = E.JobOutcome.DISASTER
		standing_delta = -j.payout_standing * Tuning.JOB_DISASTER_STANDING_MULT
		Heat.add(ws, Tuning.JOB_DISASTER_HEAT)
		# Possible arrest on violent DISASTERs: turn.gd calls
		# Exogenous.maybe_arrest_from_disaster right after this resolves,
		# since j.outcome/j.kind need to be checked post-resolution.
	if bool(Tuning.JOB_KINDS[j.kind]["violent"]):
		Heat.add(ws, Tuning.HEAT_ENFORCEMENT)

	j.resolved = true
	worker.money += money
	World.add_standing(ws, worker.id, standing_delta)
	metrics.job_outcome(j.outcome)

	var e := Event.new()
	e.turn = ws.turn
	e.actor_id = worker.id
	e.action = &"take_job"
	e.visibility = E.Visibility.OPEN
	e.outcome = {
		"job_id": j.id, "kind": String(j.kind), "outcome": j.outcome,
		"money": money, "standing_delta": standing_delta,
		"assigned_by_id": j.assigned_by_id,
	}
	ws.add_event(e)

	var outcome_names := ["PENDING", "SUCCESS", "PARTIAL", "FAILURE", "DISASTER"]
	var note := "  (%s)" % chosen_note if chosen_note != "" else ""
	chron.line("%s works %s #%d — %s (+$%d, %+.1f st)%s" % [
		worker.name, j.kind, j.id, outcome_names[j.outcome], money, standing_delta, note])
	return e
