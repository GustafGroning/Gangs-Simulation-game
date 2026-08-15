class_name Contest
extends RefCounted
# doc 3 §2 / design_doc.md's "one rank-change mechanism only — Removal ->
# contest". Runs at end of turn (turn step 10) for every currently-vacant
# slot, including the deliberate starting vacancy (there is no Advocate
# action in the demo's 7-verb scope, so the automatic end-of-turn contest is
# the ONLY way any vacancy — starting or earned — ever fills). Expansion/
# Contraction (doc 3 §2) are explicitly out of the demo's one-mechanism
# scope — see DECISIONS.md.


static func run_all(ws: WorldState, chron: Chronicle, metrics: Metrics) -> void:
	var sids := ws.slots.keys()
	sids.sort()
	for sid in sids:
		var s: Slot = ws.slots[sid]
		if s.occupant_id == -1:
			_contest_one(ws, s, chron, metrics)


# Eligible: exactly one rank below the vacant slot (promotion), plus
# same-rank characters (a lateral move — doc 3 §2 gates these by standing
# proximity via LATERAL_THRESHOLD; approximated here by letting claim_score
# itself, which is standing-led, decide, since ADVOCACY_WEIGHT's term is
# always 0 in the demo — no Advocate action exists to feed it).
static func _contest_one(ws: WorldState, s: Slot, chron: Chronicle, metrics: Metrics) -> void:
	var eligible: Array[int] = []
	var ids := ws.characters.keys()
	ids.sort()
	for cid in ids:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE:
			continue
		if c.rank == s.rank + 1 or c.rank == s.rank:
			eligible.append(cid)
	if eligible.is_empty():
		return

	var scores := {}
	for cid in eligible:
		var c: Character = ws.characters[cid]
		var proximity := Tuning.PROXIMITY_BONUS if _was_subordinate(ws, s, cid) else 0.0
		scores[cid] = c.standing + proximity + Rng.randfn(0.0, Tuning.CONTEST_NOISE, ws.rng)

	var winner: int = eligible[0]
	for cid in eligible:
		if float(scores[cid]) > float(scores[winner]) or (float(scores[cid]) == float(scores[winner]) and cid < winner):
			winner = cid

	s.occupant_id = winner
	World.resync_tree(ws)

	var e := Event.new()
	e.turn = ws.turn
	e.actor_id = winner
	e.action = &"contest_win"
	e.visibility = E.Visibility.OPEN
	e.outcome = {"slot_id": s.id, "rank": s.rank}
	ws.add_event(e)
	metrics.rank_change()
	chron.line("♛ %s wins the contest for rank %d (score %.1f, %d contenders)" % [
		(ws.characters[winner] as Character).name, s.rank, float(scores[winner]), eligible.size()])

	# "Losers of a contest take Vengeance[winner] += 0.3 and AMBITION += 0.2 —
	# every promotion manufactures its own next conflict."
	for cid in eligible:
		if cid == winner:
			continue
		var loser: Character = ws.characters[cid]
		loser.vengeance[winner] = clampf(float(loser.vengeance.get(winner, 0.0)) + Tuning.CONTEST_LOSER_VENGEANCE, 0.0, 1.0)
		loser.goals[E.Goal.AMBITION] = clampf(float(loser.goals.get(E.Goal.AMBITION, 0.0)) + Tuning.CONTEST_LOSER_AMBITION, 0.0, 1.0)


static func _was_subordinate(ws: WorldState, s: Slot, cid: int) -> bool:
	var csid := World.slot_of(ws, cid)
	if csid == -1:
		return false
	return (ws.slots[csid] as Slot).parent_slot_id == s.id
