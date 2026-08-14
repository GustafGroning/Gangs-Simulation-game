class_name World
extends RefCounted
# Static accessors and invariant checks over WorldState (doc 1 §4, doc 1 §6).
# ALL relationship and tree access goes through these — no raw dictionary
# indexing in game logic.


# ---- Keys and serialization helpers ----

const PAIR_KEY_BASE := 10000


static func pair_key(from_id: int, to_id: int) -> int:
	return from_id * PAIR_KEY_BASE + to_id


static func int_array(src) -> Array[int]:
	var out: Array[int] = []
	for v in src:
		out.append(int(v))
	return out


static func int_keyed_floats(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[int(k)] = float(src[k])
	return out


static func int_keyed_ints(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[int(k)] = int(src[k])
	return out


# ---- Relationship access ----

static func relationship_of(ws: WorldState, from_id: int, to_id: int) -> Relationship:
	return ws.relationships.get(pair_key(from_id, to_id))


static func set_relationship(ws: WorldState, r: Relationship) -> void:
	ws.relationships[pair_key(r.from_id, r.to_id)] = r


# All standing changes go through here so the standing rules live in one
# place: the floor at 0 (doc 3 §6 speaks of characters AT standing 0), the
# soft cap on gains (doc 1 §1: standing "unbounded above in principle,
# soft-capped"), and its mirror on losses — reputation damage scales with the
# stature you actually have, so a nobody cannot be driven far below their
# rank's floor by one bad job.
static func add_standing(ws: WorldState, char_id: int, delta: float) -> void:
	var c: Character = ws.characters[char_id]
	var effective := delta
	if delta > 0.0 and c.standing > Tuning.STANDING_SOFT_KNEE:
		var over := (c.standing - Tuning.STANDING_SOFT_KNEE) / (Tuning.STANDING_SOFT_CAP - Tuning.STANDING_SOFT_KNEE)
		effective = delta * maxf(Tuning.STANDING_SOFT_MIN_MULT, 1.0 - over)
	elif delta < 0.0:
		effective = delta * clampf(c.standing / Tuning.STANDING_SOFT_KNEE, Tuning.STANDING_LOSS_MIN_MULT, 1.0)
	c.standing = maxf(0.0, c.standing + effective)


# Effective opinion of a toward b: earned channel plus the purchased (brittle)
# channel. Always read opinion through here, never the raw field.
static func opinion_of(ws: WorldState, a: int, b: int) -> float:
	var rel := relationship_of(ws, a, b)
	var earned: float = rel.opinion if rel != null else 0.0
	var holder: Character = ws.characters.get(a)
	var purchased: float = holder.purchased_opinion.get(b, 0.0) if holder != null else 0.0
	return earned + purchased * Tuning.PURCHASED_OPINION_MULT


# ---- Tree access ----

static func slot_of(ws: WorldState, char_id: int) -> int:
	for sid: int in ws.slots:
		if (ws.slots[sid] as Slot).occupant_id == char_id:
			return sid
	return -1


static func patron_of(ws: WorldState, char_id: int) -> int:
	var sid := slot_of(ws, char_id)
	if sid == -1:
		return -1
	var s: Slot = ws.slots[sid]
	if s.parent_slot_id == -1 or not ws.slots.has(s.parent_slot_id):
		return -1
	return (ws.slots[s.parent_slot_id] as Slot).occupant_id


static func crew_of(ws: WorldState, char_id: int) -> Array[int]:
	var crew: Array[int] = []
	var sid := slot_of(ws, char_id)
	if sid == -1:
		return crew
	for sid2: int in ws.slots:
		var s2: Slot = ws.slots[sid2]
		if s2.parent_slot_id == sid and s2.occupant_id != -1:
			crew.append(s2.occupant_id)
	crew.sort()
	return crew


# Tree distances between all active characters (patron/crew edges,
# undirected), BFS per character. Used as observer density in detection and
# risk. Cached per (world, turn) — risk queries it per candidate; call
# invalidate_distances after any tree change.
static var _dist_cache := {}

static func invalidate_distances(ws: WorldState) -> void:
	_dist_cache.erase(ws.get_instance_id())


static func tree_distances(ws: WorldState) -> Dictionary:
	var key := ws.get_instance_id()
	var cached: Dictionary = _dist_cache.get(key, {})
	if not cached.is_empty() and int(cached["turn"]) == ws.turn:
		return cached["dist"]
	var dist := _compute_tree_distances(ws)
	_dist_cache[key] = {"turn": ws.turn, "dist": dist}
	return dist


static func _compute_tree_distances(ws: WorldState) -> Dictionary:
	var adj := {}
	var ids: Array[int] = []
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE:
			continue
		ids.append(cid)
		var edges: Array[int] = []
		if c.patron_id != -1:
			edges.append(c.patron_id)
		for m in c.crew_ids:
			edges.append(m)
		adj[cid] = edges
	ids.sort()
	var out := {}
	for start in ids:
		var dist := {start: 0}
		var queue: Array[int] = [start]
		var head := 0
		while head < queue.size():
			var cur: int = queue[head]
			head += 1
			for nxt in adj.get(cur, []):
				if not dist.has(nxt):
					dist[nxt] = int(dist[cur]) + 1
					queue.append(nxt)
		out[start] = dist
	return out


# Slot occupancy is the source of truth; rank, patron_id and crew_ids on
# Character are derived. Call after ANY change to the tree.
static func resync_tree(ws: WorldState) -> void:
	invalidate_distances(ws)
	var slot_by_char := {}
	for sid: int in ws.slots:
		var s: Slot = ws.slots[sid]
		if s.occupant_id != -1:
			slot_by_char[s.occupant_id] = sid
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE or not slot_by_char.has(cid):
			continue
		var s: Slot = ws.slots[slot_by_char[cid]]
		c.rank = s.rank
		c.patron_id = -1
		if s.parent_slot_id != -1 and ws.slots.has(s.parent_slot_id):
			c.patron_id = (ws.slots[s.parent_slot_id] as Slot).occupant_id
		var crew: Array[int] = []
		for sid2: int in ws.slots:
			var s2: Slot = ws.slots[sid2]
			if s2.parent_slot_id == s.id and s2.occupant_id != -1:
				crew.append(s2.occupant_id)
		crew.sort()
		c.crew_ids = crew


# ---- Invariants (doc 1 §6) ----
#
# Returns violation messages, each prefixed with its invariant tag ("I7: ...").
# Invariants 3 (requires() held at selection) and 4 (no acting on unheld
# beliefs) are execution-time contracts — they are enforced where actions
# execute and score (phases 4+), because they are not decidable from a state
# snapshot alone. All eight state-decidable invariants are checked here.

static func check_invariants(ws: WorldState) -> Array[String]:
	var v: Array[String] = []

	# I1 + I2 — belief grounding and temporal sanity.
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		for bk in c.beliefs:
			var b: Belief = c.beliefs[bk]
			var grounded := b.event_id >= 0
			if grounded == b.fabricated:
				v.append("I1: belief held by %d has event_id %d with fabricated=%s" % [cid, b.event_id, b.fabricated])
			elif grounded:
				if b.event_id >= ws._events.size():
					v.append("I2: belief held by %d references nonexistent event %d" % [cid, b.event_id])
				elif (ws._events[b.event_id] as Event).turn > b.turn_acquired:
					v.append("I2: belief held by %d acquired T%d predates its event %d (T%d)" % [cid, b.turn_acquired, b.event_id, (ws._events[b.event_id] as Event).turn])

	# I5 + I6 — tree consistency.
	var occupant_seen := {}
	for sid: int in ws.slots:
		var s: Slot = ws.slots[sid]
		if s.occupant_id == -1:
			continue
		if not ws.characters.has(s.occupant_id):
			v.append("I6: slot %d occupied by nonexistent character %d" % [sid, s.occupant_id])
			continue
		if (ws.characters[s.occupant_id] as Character).state != E.CharState.ACTIVE:
			v.append("I6: slot %d occupied by non-active character %d" % [sid, s.occupant_id])
		if occupant_seen.has(s.occupant_id):
			v.append("I6: character %d occupies more than one slot" % s.occupant_id)
		occupant_seen[s.occupant_id] = true
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.state != E.CharState.ACTIVE:
			continue
		var sid := slot_of(ws, cid)
		if sid == -1:
			v.append("I6: active character %d occupies no slot" % cid)
			continue
		var s: Slot = ws.slots[sid]
		if c.rank != s.rank:
			v.append("I5: character %d rank %d != slot rank %d" % [cid, c.rank, s.rank])
		var expected_patron := -1
		if s.parent_slot_id != -1 and ws.slots.has(s.parent_slot_id):
			expected_patron = (ws.slots[s.parent_slot_id] as Slot).occupant_id
		if c.patron_id != expected_patron:
			v.append("I5: character %d patron %d != slot-derived %d" % [cid, c.patron_id, expected_patron])

	# I7 — declared numeric ranges.
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.standing < 0.0:
			v.append("I7: character %d standing %.2f below 0" % [cid, c.standing])
		if c.temperature < 0.0 or c.temperature > 1.0:
			v.append("I7: character %d temperature %.2f out of range" % [cid, c.temperature])
		if c.competence < 0.0 or c.competence > 1.0:
			v.append("I7: character %d competence %.2f out of range" % [cid, c.competence])
		for g in c.goals:
			if g == E.Goal.LOYALTY or g == E.Goal.VENGEANCE:
				v.append("I7: character %d has target-indexed goal %d in scalar goals" % [cid, g])
			elif c.goals[g] < 0.0 or c.goals[g] > 1.0:
				v.append("I7: character %d goal %d weight %.2f out of range" % [cid, g, c.goals[g]])
		for t in c.loyalty:
			if c.loyalty[t] < 0.0 or c.loyalty[t] > 1.0:
				v.append("I7: character %d loyalty[%d] %.2f out of range" % [cid, t, c.loyalty[t]])
		for t in c.vengeance:
			if c.vengeance[t] < 0.0 or c.vengeance[t] > 1.0:
				v.append("I7: character %d vengeance[%d] %.2f out of range" % [cid, t, c.vengeance[t]])
		for bk in c.beliefs:
			var conf: float = (c.beliefs[bk] as Belief).confidence
			if conf < 0.0 or conf > 1.0:
				v.append("I7: character %d belief %s confidence %.2f out of range" % [cid, bk, conf])
	for k: int in ws.relationships:
		var r: Relationship = ws.relationships[k]
		if r.opinion < -1.0 or r.opinion > 1.0:
			v.append("I7: relationship %d opinion %.2f out of range" % [k, r.opinion])
		if r.known_motive < 0.0 or r.known_motive > 1.0:
			v.append("I7: relationship %d known_motive %.2f out of range" % [k, r.known_motive])
	if ws.heat < 0.0 or ws.heat > 1.0:
		v.append("I7: heat %.2f out of range" % ws.heat)

	# I8 — traces_by_event consistent with traces, both directions.
	for eid: int in ws.traces_by_event:
		for tid in ws.traces_by_event[eid]:
			if not ws.traces.has(tid):
				v.append("I8: traces_by_event[%d] lists missing trace %d" % [eid, tid])
			elif (ws.traces[tid] as Trace).event_id != eid:
				v.append("I8: trace %d filed under event %d but references event %d" % [tid, eid, (ws.traces[tid] as Trace).event_id])
	for tid: int in ws.traces:
		var t: Trace = ws.traces[tid]
		if not (ws.traces_by_event.get(t.event_id, []) as Array).has(tid):
			v.append("I8: trace %d not listed under its event %d" % [tid, t.event_id])

	# I9 — relationships reference existing, non-dead characters, stored
	# under the right key.
	for k: int in ws.relationships:
		var r: Relationship = ws.relationships[k]
		for endpoint in [r.from_id, r.to_id]:
			if not ws.characters.has(endpoint):
				v.append("I9: relationship %d references nonexistent character %d" % [k, endpoint])
			elif (ws.characters[endpoint] as Character).state == E.CharState.DEAD:
				v.append("I9: relationship %d references dead character %d" % [k, endpoint])
		if k != pair_key(r.from_id, r.to_id):
			v.append("I9: relationship (%d -> %d) stored under wrong key %d" % [r.from_id, r.to_id, k])

	# I10 — event ids equal array indices.
	for i in ws._events.size():
		if (ws._events[i] as Event).id != i:
			v.append("I10: events[%d] has id %d" % [i, (ws._events[i] as Event).id])

	return v


static func assert_invariants(ws: WorldState) -> void:
	var v := check_invariants(ws)
	assert(v.is_empty(), "invariant violations: " + "; ".join(v))
