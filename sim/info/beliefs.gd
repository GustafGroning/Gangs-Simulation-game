class_name Beliefs
extends RefCounted
# doc 5 phase 3 / gangs-design.md §3. Belief creation, merging, transmission
# (with actor mutation), and upward reporting. This module reads ground truth
# because it implements perception; nothing under ai/ ever may.

const HOSTILE_ACTIONS: Array[StringName] = [&"sabotage_job", &"kill", &"frame", &"rival_hit"]


# ---- Acquisition ----

# The actor of an event knows what they did; an assignment's target knows
# they were told. Nobody else gets free knowledge.
static func grant_first_hand(ws: WorldState, e: Event) -> void:
	# actor_id == -1 marks an exogenous "outsider" event (phase 6, doc 3 §3,
	# e.g. Rival Hit) — nobody in the tree "did" it, so there is no first-hand
	# claimant.
	if e.actor_id == -1:
		return
	var claim := {E.Field.ACTOR: e.actor_id, E.Field.ACTION: e.action}
	if e.target_id != -1:
		claim[E.Field.TARGET] = e.target_id
	_merge(ws, ws.characters[e.actor_id], e.id, claim, Tuning.FIRSTHAND_ACTOR_CONFIDENCE, -1, 0, null)
	if e.action == &"assign_job" and e.target_id != -1:
		_merge(ws, ws.characters[e.target_id], e.id, claim.duplicate(), Tuning.FIRSTHAND_ACTOR_CONFIDENCE, -1, 0, null)


# A deliberate broadcast (Judgment verdicts; doc 3 §4 calls it "the one
# reliable broadcast channel in the game") — grants holder a belief directly,
# bypassing detection/transmission. source_id -1 / hops 0, same as first-hand.
static func grant_public(ws: WorldState, holder: Character, event_id: int, claim: Dictionary, conf: float, chron: Chronicle = null) -> void:
	_merge(ws, holder, event_id, claim.duplicate(), conf, -1, 0, chron)


# ---- Deliberate delivery (SpreadRumor, phase 6) ----

# Unlike passive transmission (which rolls per-neighbor every turn), this is
# a chosen act: the sender picked the recipient and the belief. Same
# mutation logic as passive gossip (a deliberate telling can still drift),
# but a gentler hop-confidence decay — a direct telling is clearer than an
# overheard rumor chain — and scaled by the sender's credibility.
static func deliver_chosen(ws: WorldState, sender: Character, recipient: Character, b: Belief) -> void:
	var claim := _mutate_claim(ws, b.claim, int(b.claim.get(E.Field.TARGET, -1)), sender.id)
	var conf: float = b.confidence * (1.0 - Tuning.SPREAD_RUMOR_HOP_DECAY) * sender.credibility
	_merge(ws, recipient, b.event_id, claim, conf, sender.id, b.hops + 1, null)


# A found trace produces a belief holding ONLY what the trace reveals.
# A trace revealing ACTION and TARGET yields a belief with no ACTOR claim —
# this is the crux of the entire design.
static func acquire_from_trace(ws: WorldState, c: Character, t: Trace, e: Event, chron: Chronicle) -> void:
	var claim := {}
	for field in t.reveals:
		match field:
			E.Field.ACTOR:
				claim[E.Field.ACTOR] = t.points_to_id  # who it IMPLICATES — may be wrong
			E.Field.ACTION:
				claim[E.Field.ACTION] = e.action
			E.Field.TARGET:
				claim[E.Field.TARGET] = e.target_id
			E.Field.INSTRUMENT:
				claim[E.Field.INSTRUMENT] = e.instrument_id
	var conf: float = Tuning.TRACE_KIND_CONFIDENCE[t.kind]
	_merge(ws, c, e.id, claim, conf, -1, 0, chron)


# ---- Merge (all belief updates funnel through here) ----

static func _merge(ws: WorldState, holder: Character, event_id: int, claim: Dictionary,
		conf: float, source_id: int, hops: int, chron: Chronicle) -> void:
	var existing: Belief = holder.beliefs.get(event_id)
	if existing == null:
		var b := Belief.new()
		b.holder_id = holder.id
		b.event_id = event_id
		b.claim = claim
		b.confidence = clampf(conf, 0.0, 1.0)
		b.source_id = source_id
		b.hops = hops
		b.turn_acquired = ws.turn
		holder.beliefs[event_id] = b
		_log_actor_claim(ws, holder, b, chron)
		return
	var had_actor := existing.claim.has(E.Field.ACTOR)
	var old_actor = existing.claim.get(E.Field.ACTOR)
	# Fill fields the holder didn't have.
	for field in claim:
		if not existing.claim.has(field):
			existing.claim[field] = claim[field]
	if claim.has(E.Field.ACTOR) and had_actor:
		if int(claim[E.Field.ACTOR]) == int(old_actor):
			# Corroboration — a different source repeating the same name
			# hardens it. This is how confident falsehoods are born.
			if source_id != existing.source_id:
				existing.confidence = clampf(existing.confidence + Tuning.CORROBORATION_BUMP, 0.0, 1.0)
		else:
			# Conflict: higher confidence wins the name; certainty erodes.
			if conf > existing.confidence:
				existing.claim[E.Field.ACTOR] = claim[E.Field.ACTOR]
				existing.source_id = source_id
				existing.hops = hops
				existing.confidence = conf
			existing.confidence = clampf(existing.confidence - Tuning.CONFLICT_PENALTY, 0.0, 1.0)
	elif conf > existing.confidence:
		existing.confidence = clampf(conf, 0.0, 1.0)
		existing.source_id = source_id
		existing.hops = hops
	existing.turn_acquired = ws.turn
	if existing.claim.has(E.Field.ACTOR) and (not had_actor or int(existing.claim[E.Field.ACTOR]) != int(old_actor)):
		_log_actor_claim(ws, holder, existing, chron)


# Chronicle: beliefs are printed distinct from truth, misattributions flagged.
static func _log_actor_claim(ws: WorldState, holder: Character, b: Belief, chron: Chronicle) -> void:
	if chron == null or b.event_id < 0 or not b.claim.has(E.Field.ACTOR):
		return
	var e: Event = ws.events[b.event_id]
	if not (e.action in HOSTILE_ACTIONS) or b.holder_id == e.actor_id:
		return
	var claimed := int(b.claim[E.Field.ACTOR])
	var mark := "✓" if claimed == e.actor_id else "✗ WRONG"
	var target_name: String = (ws.characters[e.target_id] as Character).name if e.target_id != -1 else "?"
	chron.line("▸ %s believes %s %s'd %s (conf %.2f, hops %d) %s" % [
		holder.name, (ws.characters[claimed] as Character).name, e.action,
		target_name, b.confidence, b.hops, mark])


# ---- Transmission (turn step 7) ----

# One hop per turn: recent beliefs spread to graph neighbors. Confidence
# decays per hop; the actor field mutates toward plausible suspects — and a
# nameless rumor may grow a name (speculation hardening into attribution).
static func transmission(ws: WorldState, chron: Chronicle) -> void:
	var deliveries := []
	var char_ids := ws.characters.keys()
	char_ids.sort()
	for cid in char_ids:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE:
			continue
		var neighbors := _neighbors(ws, cid)
		var bkeys := c.beliefs.keys()
		bkeys.sort()
		for bk in bkeys:
			var b: Belief = c.beliefs[bk]
			if ws.turn - b.turn_acquired > Tuning.BELIEF_RECENCY_WINDOW or b.event_id < 0:
				continue
			# Nobody gossips their own crimes.
			if int(b.claim.get(E.Field.ACTOR, -1)) == cid and ws.events[b.event_id].actor_id == cid:
				continue
			for n in neighbors:
				var p := Tuning.GOSSIP_BASE_CHANCE * (1.0 + Tuning.GOSSIP_OPINION_WEIGHT * World.opinion_of(ws, cid, n))
				if ws.rng.randf() >= clampf(p, 0.0, 0.9):
					continue
				var claim := _mutate_claim(ws, b.claim, int(b.claim.get(E.Field.TARGET, -1)), cid)
				deliveries.append({
					"to": n, "event_id": b.event_id, "claim": claim,
					# credibility (phase 6, doc 3 §4): a discredited gossip
					# lands softer — see Character.credibility.
					"conf": b.confidence * (1.0 - Tuning.HOP_CONFIDENCE_DECAY) * c.credibility,
					"source": cid, "hops": b.hops + 1,
				})
	for d in deliveries:
		_merge(ws, ws.characters[d["to"]], d["event_id"], d["claim"], d["conf"], d["source"], d["hops"], chron)


static func _neighbors(ws: WorldState, cid: int) -> Array[int]:
	var out: Array[int] = []
	var c: Character = ws.characters[cid]
	if c.patron_id != -1:
		out.append(c.patron_id)
	for m in c.crew_ids:
		out.append(m)
	if c.patron_id != -1:
		for sib in World.crew_of(ws, c.patron_id):
			if sib != cid and not (sib in out):
				out.append(sib)
	out.sort()
	return out


# Actor mutation (doc: weighted toward plausible suspects — people with known
# motive against the target). Speculation fills an absent actor the same way.
static func _mutate_claim(ws: WorldState, claim: Dictionary, target_id: int, sender_id: int) -> Dictionary:
	var out := claim.duplicate()
	if target_id == -1:
		return out
	var has_actor := out.has(E.Field.ACTOR)
	var roll_chance := Tuning.ACTOR_MUTATION_CHANCE if has_actor else Tuning.ACTOR_SPECULATION_CHANCE
	if ws.rng.randf() >= roll_chance:
		return out
	var current := int(out.get(E.Field.ACTOR, -1))
	var suspect := pick_plausible_suspect(ws, target_id, [current, sender_id])
	if suspect != -1:
		out[E.Field.ACTOR] = suspect
	return out


# Shared "who looks guilty" weighting: motive-biased toward whoever has
# public known_motive against target_id (doc: mutation "weighted toward
# plausible suspects"). Used by gossip mutation/speculation above and by
# Dig's false-resolve (phase 6, sim/actions/dig.gd) — same logic, doc calls
# it out explicitly as identical ("same mutation logic as rumor transmission").
# Returns -1 if no eligible suspect exists.
static func pick_plausible_suspect(ws: WorldState, target_id: int, exclude_ids: Array) -> int:
	var pool: Array = []
	var weights: Array = []
	var char_ids := ws.characters.keys()
	char_ids.sort()
	for sid in char_ids:
		var s: Character = ws.characters[sid]
		if s.state != E.CharState.ACTIVE or sid == target_id or sid in exclude_ids:
			continue
		var motive := 0.0
		var rel := World.relationship_of(ws, sid, target_id)
		if rel != null:
			motive = rel.known_motive
		pool.append(sid)
		weights.append(Tuning.MUTATION_BASE_WEIGHT + Tuning.MUTATION_MOTIVE_BIAS * motive)
	if pool.is_empty():
		return -1
	return int(Rng.weighted_pick(pool, weights, ws.rng))


# ---- Upward reporting (turn step 8) ----

# Per newly-acquired belief: roll whether it moves up, pick a RECIPIENT
# (low loyalty redirects rather than blocks), run it through the transmission
# pipeline, and cap what each superior can absorb per turn.
static func upward_reporting(ws: WorldState, metrics: Metrics, chron: Chronicle) -> void:
	var proposals := []  # {recipient, sender, event_id, claim, conf, hops, sort_conf}
	var char_ids := ws.characters.keys()
	char_ids.sort()
	for cid in char_ids:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE or c.rank == 0:
			continue
		var superiors: Array[int] = []
		for sid in char_ids:
			var s: Character = ws.characters[sid]
			if s.state == E.CharState.ACTIVE and s.rank < c.rank:
				superiors.append(sid)
		if superiors.is_empty():
			continue
		var bkeys := c.beliefs.keys()
		bkeys.sort()
		for bk in bkeys:
			var b: Belief = c.beliefs[bk]
			if b.turn_acquired != ws.turn or b.event_id < 0:
				continue
			var p := Tuning.REPORT_BASE_CHANCE * (Tuning.REPORT_VALUE_FLOOR + (1.0 - Tuning.REPORT_VALUE_FLOOR) * b.confidence)
			# Nobody reports what hurts them — or their patron, or a friend.
			var claimed := int(b.claim.get(E.Field.ACTOR, -1))
			if claimed == cid or (claimed != -1 and claimed == c.patron_id) \
					or (claimed != -1 and float(c.loyalty.get(claimed, 0.0)) > 0.5):
				p *= Tuning.REPORT_SELF_IMPLICATION_MULT
			if ws.rng.randf() >= p:
				continue
			# Recipient selection — the roll picks WHO, not pass/fail.
			var weights := []
			for sid in superiors:
				var base := Tuning.REPORT_PATRON_BASE if sid == c.patron_id else Tuning.REPORT_RIVAL_BASE
				weights.append(clampf(base + Tuning.REPORT_OPINION_WEIGHT * World.opinion_of(ws, cid, sid)
					+ float(c.loyalty.get(sid, 0.0)), 0.01, 3.0))
			var recipient := int(Rng.weighted_pick(superiors, weights, ws.rng))
			var fidelity := clampf(Tuning.REPORT_FIDELITY_FLOOR
				+ Tuning.REPORT_FIDELITY_SPAN * (float(c.loyalty.get(recipient, 0.0)) + maxf(0.0, World.opinion_of(ws, cid, recipient)) * 0.5),
				0.3, 1.0)
			var claim := _mutate_claim(ws, b.claim, int(b.claim.get(E.Field.TARGET, -1)), cid)
			proposals.append({
				"recipient": recipient, "sender": cid, "event_id": b.event_id,
				"claim": claim,
				# credibility (phase 6, doc 3 §4): see Character.credibility.
				"conf": b.confidence * (1.0 - Tuning.HOP_CONFIDENCE_DECAY) * fidelity * c.credibility,
				"hops": b.hops + 1,
			})
	# Superior attention budget: process the N most confident, drop the rest.
	proposals.sort_custom(func(a, b):
		if a["recipient"] != b["recipient"]:
			return a["recipient"] < b["recipient"]
		if a["conf"] != b["conf"]:
			return a["conf"] > b["conf"]
		return a["sender"] < b["sender"])
	var taken := {}
	for pr in proposals:
		var r: int = pr["recipient"]
		taken[r] = int(taken.get(r, 0)) + 1
		if taken[r] > Tuning.ATTENTION_BUDGET_SUPERIOR:
			continue
		_merge(ws, ws.characters[r], pr["event_id"], pr["claim"], pr["conf"], pr["sender"], pr["hops"], chron)
		if metrics != null:
			var sender: Character = ws.characters[pr["sender"]]
			metrics.report_delivered(pr["sender"], r, r == sender.patron_id,
				World.opinion_of(ws, pr["sender"], sender.patron_id))
