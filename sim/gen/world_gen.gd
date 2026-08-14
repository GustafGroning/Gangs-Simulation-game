class_name WorldGen
extends RefCounted
# BOOTSTRAP world builder — pre-phase-7 scaffolding so phases 2-6 have a
# seeded world to run. The full generator (doc 2: history simulation, planted
# hooks, trait floors, name lists, initial beliefs) replaces the guts of this
# in phase 7. Structure kept doc-2-shaped: tree → characters → slots by
# fitness → relationships.

const NAMES := [
	"Rosa", "Marco", "Vito", "Sal", "Nina", "Enzo", "Carla", "Dante",
	"Bruno", "Livia", "Paolo", "Gia", "Tony", "Ada", "Rocco", "Mira",
	"Franco", "Delia", "Ugo", "Zeta",
]

# Trait exclusion pairs (doc 2): never co-assign.
const EXCLUSIONS := [
	[E.Trait.RECKLESS, E.Trait.CRAVEN],
	[E.Trait.RECKLESS, E.Trait.CALCULATING],
	[E.Trait.LOYAL, E.Trait.AMBITIOUS],
]


static func bootstrap(p_seed: int) -> WorldState:
	var ws := WorldState.create(p_seed)

	# Tree: 1 boss, 3 rank-1, 7 rank-2 slots (one vacant), 6 rank-3. 16 chars.
	var slot_specs := []          # [rank, parent_index]
	slot_specs.append([0, -1])
	for i in 3:
		slot_specs.append([1, 0])
	for i in 6:
		slot_specs.append([2, 1 + i % 3])
	slot_specs.append([2, 1])     # the doc-2 starting vacancy, at rank 2
	for i in 6:
		slot_specs.append([3, 4 + i])
	for spec in slot_specs:
		var s := Slot.new()
		s.rank = spec[0]
		s.parent_slot_id = spec[1]
		ws.add_slot(s)

	var cast_size := 16
	for i in cast_size:
		ws.add_character(_make_character(ws, NAMES[i]))

	_assign_slots(ws)
	World.resync_tree(ws)
	_derive_relationships(ws)
	World.assert_invariants(ws)
	return ws


static func _make_character(ws: WorldState, p_name: String) -> Character:
	var c := Character.new()
	c.name = p_name
	c.traits = _draw_traits(ws)
	c.temperature = clampf(Rng.randfn(Tuning.TEMPERATURE_MEAN, Tuning.TEMPERATURE_DEV, ws.rng),
		Tuning.TEMPERATURE_MIN, Tuning.TEMPERATURE_MAX)
	if c.has_trait(E.Trait.CALCULATING):
		c.temperature = clampf(c.temperature * Tuning.CALCULATING_TEMP_MULT, 0.01, 1.0)
	if c.has_trait(E.Trait.RECKLESS):
		c.temperature = clampf(c.temperature * Tuning.RECKLESS_TEMP_MULT, 0.01, 1.0)
	c.competence = clampf(Rng.randfn(Tuning.COMPETENCE_MEAN, Tuning.COMPETENCE_DEV, ws.rng),
		Tuning.COMPETENCE_MIN, Tuning.COMPETENCE_MAX)
	c.goals = _draw_goals(ws, c)
	c.goal_baseline = c.goals.duplicate()
	return c


static func _draw_traits(ws: WorldState) -> Array[int]:
	var counts := Tuning.TRAIT_COUNT_WEIGHTS.keys()
	var weights := []
	for k in counts:
		weights.append(float(Tuning.TRAIT_COUNT_WEIGHTS[k]))
	var count: int = Rng.weighted_pick(counts, weights, ws.rng)
	var pool: Array = E.Trait.values()
	var picked: Array[int] = []
	var guard := 0
	while picked.size() < count and guard < 50:
		guard += 1
		var t: int = Rng.pick(pool, ws.rng)
		if t in picked:
			continue
		var excluded := false
		for pair in EXCLUSIONS:
			if (t == pair[0] and pair[1] in picked) or (t == pair[1] and pair[0] in picked):
				excluded = true
				break
		if not excluded:
			picked.append(t)
	picked.sort()
	return picked


static func _draw_goals(ws: WorldState, c: Character) -> Dictionary:
	var scalar_goals := [E.Goal.AMBITION, E.Goal.SECURITY, E.Goal.WEALTH, E.Goal.STANDING]
	var goals := {}
	for g in scalar_goals:
		goals[g] = clampf(Rng.randfn(Tuning.GOAL_BASE_MEAN, Tuning.GOAL_BASE_DEV, ws.rng), 0.0, 1.0)
	# Polarization: one dominant drive up, one recessive down (doc 2 §3).
	var dominant: int = Rng.pick(scalar_goals, ws.rng)
	var others := scalar_goals.filter(func(g): return g != dominant)
	var recessive: int = Rng.pick(others, ws.rng)
	goals[dominant] = clampf(goals[dominant] + Tuning.GOAL_POLARIZE_UP, 0.0, 1.0)
	goals[recessive] = clampf(goals[recessive] - Tuning.GOAL_POLARIZE_DOWN, 0.0, 1.0)
	# Trait modifiers (doc 2 §3).
	if c.has_trait(E.Trait.AMBITIOUS):
		goals[E.Goal.AMBITION] = clampf(goals[E.Goal.AMBITION] + 0.30, 0.0, 1.0)
	if c.has_trait(E.Trait.CRAVEN):
		goals[E.Goal.SECURITY] = clampf(goals[E.Goal.SECURITY] + 0.30, 0.0, 1.0)
		goals[E.Goal.AMBITION] = clampf(goals[E.Goal.AMBITION] - 0.20, 0.0, 1.0)
	if c.has_trait(E.Trait.GREEDY):
		goals[E.Goal.WEALTH] = clampf(goals[E.Goal.WEALTH] + 0.30, 0.0, 1.0)
	if c.has_trait(E.Trait.BRUTAL):
		goals[E.Goal.SECURITY] = clampf(goals[E.Goal.SECURITY] - 0.15, 0.0, 1.0)
	if c.has_trait(E.Trait.LOYAL):
		goals[E.Goal.AMBITION] = clampf(goals[E.Goal.AMBITION] - 0.25, 0.0, 1.0)
	if c.has_trait(E.Trait.PARANOID):
		goals[E.Goal.SECURITY] = clampf(goals[E.Goal.SECURITY] + 0.20, 0.0, 1.0)
	return goals


# Slot assignment by fitness (doc 2 §4): not random, not meritocratic.
static func _assign_slots(ws: WorldState) -> void:
	var fitness := []  # [char_id, score]
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		var score := 0.5 * c.competence + 0.3 * float(c.goals[E.Goal.AMBITION]) + 0.2 * ws.rng.randf()
		fitness.append([cid, score])
	fitness.sort_custom(func(a, b): return a[1] > b[1] if a[1] != b[1] else a[0] < b[0])

	# Occupy slots best-first, skipping the deliberate rank-2 vacancy (the
	# LAST rank-2 slot stays open — doc 2 §2).
	var slot_ids := ws.slots.keys()
	slot_ids.sort()
	var vacancy_id := -1
	for sid in slot_ids:
		if (ws.slots[sid] as Slot).rank == 2:
			vacancy_id = sid  # last rank-2 slot wins
	var i := 0
	for sid in slot_ids:
		if sid == vacancy_id:
			continue
		if i >= fitness.size():
			break
		var s: Slot = ws.slots[sid]
		s.occupant_id = fitness[i][0]
		i += 1

	for sid in slot_ids:
		var s: Slot = ws.slots[sid]
		if s.occupant_id == -1:
			continue
		var c: Character = ws.characters[s.occupant_id]
		c.standing = maxf(0.5, Tuning.STANDING_BY_RANK[s.rank] + Rng.randfn(0.0, Tuning.STANDING_NOISE, ws.rng))
		c.money = maxi(0, int(Tuning.MONEY_BY_RANK[s.rank] + Rng.randfn(0.0, Tuning.MONEY_NOISE, ws.rng)))
		c.competence = clampf(c.competence + Tuning.COMPETENCE_RANK_CORR * (3 - s.rank), Tuning.COMPETENCE_MIN, Tuning.COMPETENCE_MAX)


# Opinions for pairs within radius (patron/crew + siblings), doc 2 §6.
# History-derived deltas land in phase 7; here it is chemistry + structure.
static func _derive_relationships(ws: WorldState) -> void:
	for cid: int in ws.characters:
		var c: Character = ws.characters[cid]
		if c.patron_id != -1:
			_seed_rel(ws, c.patron_id, cid, Tuning.OPINION_PATRON_TO_CREW)
			_seed_rel(ws, cid, c.patron_id, Tuning.OPINION_CREW_TO_PATRON)
		for sibling in World.crew_of(ws, c.patron_id) if c.patron_id != -1 else []:
			if sibling != cid:
				_seed_rel(ws, cid, sibling, Tuning.OPINION_SIBLING)


static func _seed_rel(ws: WorldState, from_id: int, to_id: int, structural: float) -> void:
	if World.relationship_of(ws, from_id, to_id) != null:
		return
	var r := Relationship.new()
	r.from_id = from_id
	r.to_id = to_id
	r.opinion = clampf(structural + Rng.randfn(0.0, Tuning.OPINION_CHEMISTRY_DEV, ws.rng), -1.0, 1.0)
	# Sibling rivalry (competition for the same advocacy) is public knowledge —
	# this is what motive-biased rumor mutation bites on before any hostile
	# event has happened.
	if structural == Tuning.OPINION_SIBLING:
		r.known_motive = Tuning.SIBLING_KNOWN_MOTIVE
	World.set_relationship(ws, r)
