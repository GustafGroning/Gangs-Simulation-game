class_name Traces
extends RefCounted
# doc 5 phase 3 / gangs-design.md §3. Trace emission, decay and detection.
# Traces are emitted BY THE TURN LOOP from templates — never by actions.
# The template lookup lives here until the Action contract lands in phase 4,
# at which point templates move onto Action classes (see DECISIONS.md).
#
# This module reads ground truth (it implements perception itself); nothing
# under ai/ may ever call into WorldState.events.


# ---- Templates ----

# Returns Array of template dicts: {kind, reveals, detect, points_to_id}.
# Registered actions provide their own trace_specs (from their authored
# templates); the fallback map covers scripted events for actions that are
# not registered yet (sabotage until phase 6).
static func templates_for(ws: WorldState, e: Event) -> Array:
	if ActionRegistry.has_action(e.action):
		return ActionRegistry.get_action(e.action).trace_specs(ws, e)
	if e.action == &"sabotage_job":
		# The crux of the design: the physical trace says WHAT happened and
		# to WHOM — never who did it (most traces must not reveal ACTOR).
		return [{
			"kind": E.TraceKind.PHYSICAL,
			"reveals": [E.Field.ACTION, E.Field.TARGET],
			"detect": Tuning.SABOTAGE_TRACE_DETECT,
			"points_to_id": e.actor_id,
		}]
	return []


# ---- Emission (turn step 5) ----

# Emit traces for every event created this turn, and give actors their
# first-hand beliefs (you know what you did; an assignee knows they were told).
static func emit_for_turn(ws: WorldState) -> void:
	var evs: Array = ws.events
	for idx in range(evs.size() - 1, -1, -1):
		var e: Event = evs[idx]
		if e.turn != ws.turn:
			break
		for t in templates_for(ws, e):
			var tr := Trace.new()
			tr.event_id = e.id
			tr.turn_created = ws.turn
			tr.kind = int(t["kind"])
			tr.reveals = World.int_array(t["reveals"])
			tr.points_to_id = int(t["points_to_id"])
			tr.detectability = float(t["detect"])
			ws.add_trace(tr)
		Beliefs.grant_first_hand(ws, e)


# ---- Decay (turn step 1) ----

static func decay_all(ws: WorldState) -> void:
	var dead: Array[int] = []
	var tids := ws.traces.keys()
	tids.sort()
	for tid in tids:
		var t: Trace = ws.traces[tid]
		t.detectability -= Tuning.TRACE_DECAY_RATE
		if t.detectability < Tuning.TRACE_MIN_DETECT or t.destroyed:
			dead.append(tid)
	for tid in dead:
		var t: Trace = ws.traces[tid]
		(ws.traces_by_event[t.event_id] as Array).erase(tid)
		if (ws.traces_by_event[t.event_id] as Array).is_empty():
			ws.traces_by_event.erase(t.event_id)
		ws.traces.erase(tid)


# ---- Detection (turn step 6) ----

# P(find) = detectability × observer_density(tree proximity to the event's
# participants) × (1 + heat), × OBSERVANT bonus. Rolls in sorted order for
# determinism.
static func detection(ws: WorldState, chron: Chronicle) -> void:
	var dist := World.tree_distances(ws)
	var char_ids := ws.characters.keys()
	char_ids.sort()
	var tids := ws.traces.keys()
	tids.sort()
	for tid in tids:
		var t: Trace = ws.traces[tid]
		var e: Event = ws.events[t.event_id]
		for cid in char_ids:
			var c: Character = ws.characters[cid]
			if c.state != E.CharState.ACTIVE or cid == e.actor_id or cid in t.found_by:
				continue
			var prox := 0.0
			for participant in [e.actor_id, e.target_id]:
				if participant == -1 or not dist.has(cid):
					continue
				var d: int = dist[cid].get(participant, 99)
				prox = maxf(prox, Tuning.PROX_BY_DIST[mini(d, Tuning.PROX_BY_DIST.size() - 1)])
			var p := t.detectability * prox * (1.0 + ws.heat)
			if c.has_trait(E.Trait.OBSERVANT):
				p *= Tuning.OBSERVANT_DETECT_MULT
			if ws.rng.randf() < clampf(p, 0.0, Tuning.DETECT_CAP):
				t.found_by.append(cid)
				Beliefs.acquire_from_trace(ws, c, t, e, chron)
