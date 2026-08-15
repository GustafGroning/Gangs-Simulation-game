class_name Judgment
extends RefCounted
# doc 3 §4 / design_doc.md. Adjudicates Denounce cases queued onto
# WorldState.pending_judgments (turn step 9, "any Denounce triggered this
# turn is adjudicated"). Reads the JUDGE's own belief state for case
# strength — "whether the accused was actually guilty is never checked...
# the single most important line in this document." This module lives under
# sim/content/, like Job/Heat — it is allowed to read WorldState (it is
# adjudicating on top of belief state, not acting as a character's AI), but
# guilt itself is never consulted; only see that this file never reads
# ws.events[...].actor_id.
#
# Protect (which would apply PROTECTION_WEIGHT) is not a demo verb, so
# "protected" is always false here — see BACKLOG.md.


static func process_all(ws: WorldState, chron: Chronicle, metrics: Metrics) -> void:
	var cases: Array = ws.pending_judgments
	ws.pending_judgments = []
	for case in cases:
		_adjudicate(ws, case, chron, metrics)


static func _adjudicate(ws: WorldState, case: Dictionary, chron: Chronicle, metrics: Metrics) -> void:
	var accuser: Character = ws.characters.get(int(case["accuser_id"]))
	var accused: Character = ws.characters.get(int(case["accused_id"]))
	if accuser == null or accused == null or accuser.state != E.CharState.ACTIVE or accused.state != E.CharState.ACTIVE:
		return  # either party no longer around (e.g. killed first this turn) — case is moot
	var event_id: int = int(case["event_id"])
	var judge_id := _select_judge(ws, accuser.id, accused.id)
	if judge_id == -1:
		return  # nobody eligible to judge (extremely small casts only)
	var judge: Character = ws.characters[judge_id]

	var judge_belief: Belief = judge.beliefs.get(event_id)
	var judge_conf := 0.0
	if judge_belief != null and int(judge_belief.claim.get(E.Field.ACTOR, -1)) == accused.id:
		judge_conf = judge_belief.confidence

	var corroborating := 0
	for cid: int in ws.characters:
		if cid == judge_id:
			continue
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE:
			continue
		var b: Belief = c.beliefs.get(event_id)
		if b != null and int(b.claim.get(E.Field.ACTOR, -1)) == accused.id:
			corroborating += 1

	var strength := clampf(
		judge_conf
		+ Tuning.CORROBORATION_WEIGHT * corroborating
		+ Tuning.ACCUSER_STANDING_WEIGHT * (accuser.standing / 100.0)
		- Tuning.ACCUSED_STANDING_WEIGHT * (accused.standing / 100.0)
		+ Rng.randfn(0.0, Tuning.JUDGMENT_NOISE, ws.rng),
		0.0, 1.0)

	var verdict: int
	if strength < 0.25:
		verdict = E.Verdict.DISMISSED
	elif strength < 0.5:
		verdict = E.Verdict.DEMOTED
	elif strength < 0.75:
		verdict = E.Verdict.EXILED
	else:
		verdict = E.Verdict.KILLED

	var e := Event.new()
	e.turn = ws.turn
	e.actor_id = judge_id
	e.action = &"judgment"
	e.target_id = accused.id
	e.visibility = E.Visibility.OPEN
	e.outcome = {"verdict": verdict, "accuser_id": accuser.id, "case_strength": strength, "denounced_event_id": event_id}
	ws.add_event(e)
	metrics.judgment_rendered(verdict)

	var verdict_name: String = E.Verdict.keys()[verdict]
	chron.line("⚖ Judgment (%s presides): %s accuses %s — %s (strength %.2f, %d corroborating)" % [
		judge.name, accuser.name, accused.name, verdict_name, strength, corroborating])

	match verdict:
		E.Verdict.DISMISSED:
			World.add_standing(ws, accuser.id, -Tuning.JUDGMENT_DISMISS_ACCUSER_STANDING)
			accused.vengeance[accuser.id] = clampf(float(accused.vengeance.get(accuser.id, 0.0)) + Tuning.JUDGMENT_DISMISS_VENGEANCE, 0.0, 1.0)
			accuser.credibility = clampf(accuser.credibility - Tuning.DIG_COLLAPSE_CREDIBILITY_HIT, 0.0, 1.0)
		E.Verdict.DEMOTED:
			_demote(ws, accused, chron)
		E.Verdict.EXILED:
			_remove(ws, accused, E.CharState.EXILED, chron)
		E.Verdict.KILLED:
			_remove(ws, accused, E.CharState.DEAD, chron)
			Heat.add(ws, Tuning.HEAT_KILL)

	# The verdict is a public Event — "the one reliable broadcast channel".
	var public_claim := {E.Field.ACTOR: judge_id, E.Field.ACTION: &"judgment", E.Field.TARGET: accused.id}
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.state == E.CharState.ACTIVE:
			Beliefs.grant_public(ws, c, e.id, public_claim, Tuning.JUDGMENT_PUBLIC_CONFIDENCE)


# Highest-ranked uninvolved party: not accuser, not accused, not patron of
# either, active. Sorting by rank ascending and taking the first eligible
# naturally falls to the next rank down if the top rank is disqualified, and
# naturally hands the case to "the highest-ranked uninvolved subordinate" if
# the accused is the boss — no special-casing needed.
static func _select_judge(ws: WorldState, accuser_id: int, accused_id: int) -> int:
	var accuser: Character = ws.characters[accuser_id]
	var accused: Character = ws.characters[accused_id]
	var candidates: Array[int] = []
	var ids := ws.characters.keys()
	ids.sort()
	for cid in ids:
		if cid == accuser_id or cid == accused_id or cid == accuser.patron_id or cid == accused.patron_id:
			continue
		var c: Character = ws.characters[cid]
		if c.state == E.CharState.ACTIVE:
			candidates.append(cid)
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a: int, b: int):
		var ca: Character = ws.characters[a]
		var cb: Character = ws.characters[b]
		return ca.rank < cb.rank if ca.rank != cb.rank else a < b)
	return candidates[0]


# DEMOTED: accused loses rank, slot contest triggered for their old slot.
# The schema (CharState: ACTIVE/DEAD/EXILED) has no "active but slot-less"
# state and I6 forbids one — if no vacant slot exists one rank below, this
# falls back to EXILED. A judgment call; see QUESTIONS.md.
static func _demote(ws: WorldState, accused: Character, chron: Chronicle) -> void:
	var old_slot_id := World.slot_of(ws, accused.id)
	if old_slot_id == -1:
		return
	var old_slot: Slot = ws.slots[old_slot_id]
	var target_slot_id := -1
	var sids := ws.slots.keys()
	sids.sort()
	for sid in sids:
		var s: Slot = ws.slots[sid]
		if s.occupant_id == -1 and s.rank == old_slot.rank + 1:
			target_slot_id = sid
			break
	old_slot.occupant_id = -1
	if target_slot_id != -1:
		(ws.slots[target_slot_id] as Slot).occupant_id = accused.id
		World.resync_tree(ws)
		chron.line("· %s demoted to rank %d" % [accused.name, (ws.slots[target_slot_id] as Slot).rank])
	else:
		World.resync_tree(ws)
		chron.line("· %s could not be demoted (no vacant lower slot) — exiled instead" % accused.name)
		_remove(ws, accused, E.CharState.EXILED, chron)


static func _remove(ws: WorldState, c: Character, new_state: int, chron: Chronicle) -> void:
	var sid := World.slot_of(ws, c.id)
	if sid != -1:
		(ws.slots[sid] as Slot).occupant_id = -1
	if new_state == E.CharState.DEAD:
		World.scrub_relationships(ws, c.id)
	c.state = new_state
	World.resync_tree(ws)
	chron.line("· %s %s" % [c.name, "killed" if new_state == E.CharState.DEAD else "exiled"])
