extends SceneTree
# Phase 1 exit test (doc 5): a hand-built 5-character fixture world passes all
# invariants; serializes and deserializes to an identical state; deliberately
# corrupting each state-decidable invariant fires exactly that invariant.
# Run: godot --headless --script tests/test_phase1.gd

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_test_fixture_valid()
	_test_accessors()
	_test_serialization_roundtrip()
	_test_json_roundtrip()
	_test_events_access_flag()
	_test_corruptions()
	if _failures.is_empty():
		print("PHASE 1 TESTS: PASS (%d checks)" % _checks)
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: %s" % f)
		printerr("PHASE 1 TESTS: %d/%d checks failed" % [_failures.size(), _checks])
		quit(1)


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(msg)


# ---- Fixture ----

func _add_rel(ws: WorldState, from_id: int, to_id: int, opinion: float) -> void:
	var r := Relationship.new()
	r.from_id = from_id
	r.to_id = to_id
	r.opinion = opinion
	World.set_relationship(ws, r)


func _fixture() -> WorldState:
	var ws := WorldState.create(1234)
	var names := ["Rosa", "Marco", "Vito", "Sal", "Nina"]
	var standings := [60.0, 40.0, 40.0, 25.0, 25.0]
	for i in 5:
		var c := Character.new()
		c.name = names[i]
		c.standing = standings[i]
		c.money = 100
		c.goals = {
			E.Goal.AMBITION: 0.5, E.Goal.SECURITY: 0.4,
			E.Goal.WEALTH: 0.3, E.Goal.STANDING: 0.6,
		}
		c.goal_baseline = c.goals.duplicate()
		ws.add_character(c)
	(ws.characters[0] as Character).traits = [E.Trait.CALCULATING]
	(ws.characters[3] as Character).traits = [E.Trait.RECKLESS]
	(ws.characters[4] as Character).traits = [E.Trait.PARANOID, E.Trait.OBSERVANT]
	(ws.characters[3] as Character).vengeance = {4: 0.4}
	(ws.characters[1] as Character).loyalty = {0: 0.6}
	(ws.characters[3] as Character).purchased_opinion = {0: 0.1}

	# Tree: s0 boss; s1,s2 rank 1 under s0; s3,s4 rank 2 under s1; s5 vacant under s2.
	var ranks := [0, 1, 1, 2, 2, 2]
	var parents := [-1, 0, 0, 1, 1, 2]
	var occupants := [0, 1, 2, 3, 4, -1]
	for i in 6:
		var s := Slot.new()
		s.rank = ranks[i]
		s.parent_slot_id = parents[i]
		s.occupant_id = occupants[i]
		ws.add_slot(s)
	World.resync_tree(ws)

	_add_rel(ws, 1, 0, 0.4)
	_add_rel(ws, 0, 1, 0.2)
	_add_rel(ws, 3, 4, -0.3)
	_add_rel(ws, 4, 3, -0.2)

	# Events: e0 open take_job by Sal (T1); e1 anonymous sabotage by Nina vs Sal (T2).
	var e0 := Event.new()
	e0.turn = 1
	e0.actor_id = 3
	e0.action = &"take_job"
	e0.visibility = E.Visibility.OPEN
	ws.add_event(e0)
	var e1 := Event.new()
	e1.turn = 2
	e1.actor_id = 4
	e1.action = &"sabotage_job"
	e1.target_id = 3
	e1.visibility = E.Visibility.ANONYMOUS
	ws.add_event(e1)

	# One physical trace on the sabotage: reveals ACTION+TARGET, not ACTOR.
	var t := Trace.new()
	t.event_id = e1.id
	t.turn_created = 2
	t.kind = E.TraceKind.PHYSICAL
	t.reveals = [E.Field.ACTION, E.Field.TARGET]
	t.points_to_id = 4
	t.detectability = 0.5
	ws.add_trace(t)

	# Beliefs: Rosa holds a partial (actor-less) belief about the sabotage;
	# Vito holds a fabrication.
	var b := Belief.new()
	b.holder_id = 0
	b.event_id = e1.id
	b.claim = {E.Field.ACTION: &"sabotage_job", E.Field.TARGET: 3}
	b.confidence = 0.4
	b.source_id = 1
	b.hops = 1
	b.turn_acquired = 3
	(ws.characters[0] as Character).beliefs[e1.id] = b
	var fb := Belief.new()
	fb.holder_id = 2
	fb.event_id = -1
	fb.fabricated = true
	fb.claim = {E.Field.ACTOR: 3, E.Field.ACTION: &"skim"}
	fb.confidence = 0.3
	fb.turn_acquired = 2
	(ws.characters[2] as Character).beliefs[-1] = fb

	ws.turn = 3
	ws.heat = 0.1
	return ws


# ---- Tests ----

func _test_fixture_valid() -> void:
	var ws := _fixture()
	var v := World.check_invariants(ws)
	_check(v.is_empty(), "fixture should pass all invariants, got: %s" % str(v))


func _test_accessors() -> void:
	var ws := _fixture()
	_check(World.pair_key(3, 4) == 30004, "pair_key(3,4)")
	_check(absf(World.opinion_of(ws, 1, 0) - 0.4) < 0.0001, "opinion_of(1,0) earned channel")
	_check(absf(World.opinion_of(ws, 3, 0) - 0.1) < 0.0001, "opinion_of(3,0) purchased channel")
	_check(World.opinion_of(ws, 2, 4) == 0.0, "opinion_of with no relationship is neutral")
	_check(World.patron_of(ws, 3) == 1, "patron_of(3)")
	_check(World.patron_of(ws, 0) == -1, "boss has no patron")
	_check(World.crew_of(ws, 0) == Array([1, 2], TYPE_INT, "", null), "crew_of(0)")
	_check(World.crew_of(ws, 2).is_empty(), "crew_of(2) — only a vacant slot below")
	_check(World.slot_of(ws, 4) == 4, "slot_of(4)")
	_check((ws.characters[3] as Character).rank == 2, "resync_tree set rank")
	_check((ws.characters[3] as Character).patron_id == 1, "resync_tree set patron")


func _test_serialization_roundtrip() -> void:
	var ws := _fixture()
	var d1 := ws.to_dict()
	var ws2 := WorldState.from_dict(d1)
	var d2 := ws2.to_dict()
	var s1 := JSON.stringify(d1, "", true, true)
	var s2 := JSON.stringify(d2, "", true, true)
	_check(s1 == s2, "to_dict -> from_dict -> to_dict must be identical")
	_check(World.check_invariants(ws2).is_empty(), "deserialized world passes invariants")


func _test_json_roundtrip() -> void:
	# Golden files and snapshots go through JSON text, where int dictionary
	# keys become strings and ints become doubles — from_dict must normalize.
	var ws := _fixture()
	var s1 := JSON.stringify(ws.to_dict(), "", true, true)
	var parsed: Dictionary = JSON.parse_string(s1)
	var ws3 := WorldState.from_dict(parsed)
	var s3 := JSON.stringify(ws3.to_dict(), "", true, true)
	_check(s1 == s3, "JSON text round trip must be identical")


func _test_events_access_flag() -> void:
	var ws := _fixture()
	ws.clear_events_read()
	_check(ws.is_events_read_clean(), "flag clear after reset")
	var _e := ws.events
	_check(not ws.is_events_read_clean(), "reading events sets the flag")
	ws.clear_events_read()
	_check(ws.is_events_read_clean(), "flag clear again")


func _expect_single_violation(tag: String, corrupt: Callable) -> void:
	var ws := _fixture()
	corrupt.call(ws)
	var v := World.check_invariants(ws)
	var tags := {}
	for s in v:
		tags[s.substr(0, s.find(":"))] = true
	_check(not v.is_empty(), "%s: corruption fired no violation" % tag)
	_check(tags.size() == 1 and tags.has(tag),
		"%s: expected only this invariant to fire, got %s" % [tag, str(v)])


func _test_corruptions() -> void:
	_expect_single_violation("I1", func(ws: WorldState) -> void:
		((ws.characters[0] as Character).beliefs[1] as Belief).fabricated = true)
	_expect_single_violation("I2", func(ws: WorldState) -> void:
		((ws.characters[0] as Character).beliefs[1] as Belief).turn_acquired = 0)
	_expect_single_violation("I5", func(ws: WorldState) -> void:
		(ws.characters[3] as Character).rank += 1)
	_expect_single_violation("I6", func(ws: WorldState) -> void:
		(ws.slots[5] as Slot).occupant_id = 999)
	_expect_single_violation("I7", func(ws: WorldState) -> void:
		(ws.relationships[World.pair_key(1, 0)] as Relationship).opinion = 1.5)
	_expect_single_violation("I8", func(ws: WorldState) -> void:
		(ws.traces_by_event[1] as Array).append(999))
	_expect_single_violation("I9", func(ws: WorldState) -> void:
		var r := Relationship.new()
		r.from_id = 2
		r.to_id = 99
		r.opinion = 0.1
		World.set_relationship(ws, r))
	_expect_single_violation("I10", func(ws: WorldState) -> void:
		(ws._events[0] as Event).id = 7
		(ws._events[1] as Event).id = 0)
