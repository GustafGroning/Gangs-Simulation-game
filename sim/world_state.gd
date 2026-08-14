class_name WorldState
extends RefCounted
# doc 1 §3. Root simulation state. All cross-references are integer ids
# (-1 = none). The only RandomNumberGenerator in the sim lives here.
# A run is identified by (seed, config_hash).

var seed: int = 0
var rng: RandomNumberGenerator = null
var turn: int = 0
var heat: float = 0.0

var characters: Dictionary = {}      # id -> Character
var slots: Dictionary = {}           # id -> Slot
var relationships: Dictionary = {}   # pair_key -> Relationship
var traces: Dictionary = {}          # id -> Trace
var traces_by_event: Dictionary = {} # event_id -> Array[int]
var jobs: Array = []                 # Array[Job] — filled in phase 2
var pending_judgments: Array = []    # filled in phase 6
var config: Config = null

var _next_char_id: int = 0
var _next_trace_id: int = 0
var _next_slot_id: int = 0
var _next_job_id: int = 0

# Ground truth. Append-only via add_event(); array index == id (invariant I10).
# Reads set a debug flag so the turn loop can prove the AI never touched
# ground truth (doc 4 §3): clear_events_read() before each scorer call,
# assert_ai_clean() after.
var _events: Array = []              # Array[Event]
var events_read: bool = false
var events: Array:
	get:
		events_read = true
		return _events


static func create(p_seed: int) -> WorldState:
	var ws := WorldState.new()
	ws.seed = p_seed
	ws.rng = RandomNumberGenerator.new()
	ws.rng.seed = p_seed
	ws.config = Config.new()
	return ws


func add_character(c: Character) -> Character:
	c.id = _next_char_id
	_next_char_id += 1
	characters[c.id] = c
	return c


func add_slot(s: Slot) -> Slot:
	s.id = _next_slot_id
	_next_slot_id += 1
	slots[s.id] = s
	return s


func add_event(e: Event) -> Event:
	e.id = _events.size()
	_events.append(e)
	return e


func add_job(j: Job) -> Job:
	j.id = _next_job_id
	_next_job_id += 1
	jobs.append(j)
	return j


func add_trace(t: Trace) -> Trace:
	t.id = _next_trace_id
	_next_trace_id += 1
	traces[t.id] = t
	if not traces_by_event.has(t.event_id):
		traces_by_event[t.event_id] = []
	(traces_by_event[t.event_id] as Array).append(t.id)
	return t


func clear_events_read() -> void:
	events_read = false


func is_events_read_clean() -> bool:
	return not events_read


# Call after each scorer invocation: asserts the AI never read ground truth,
# then resets the flag for the next check.
func assert_ai_clean() -> void:
	assert(not events_read, "AI code read WorldState.events — belief-state boundary violated")
	events_read = false


func to_dict() -> Dictionary:
	var chars_d := {}
	for k: int in characters:
		chars_d[k] = (characters[k] as Character).to_dict()
	var slots_d := {}
	for k: int in slots:
		slots_d[k] = (slots[k] as Slot).to_dict()
	var rels_d := {}
	for k: int in relationships:
		rels_d[k] = (relationships[k] as Relationship).to_dict()
	var events_d := []
	for e: Event in _events:
		events_d.append(e.to_dict())
	var traces_d := {}
	for k: int in traces:
		traces_d[k] = (traces[k] as Trace).to_dict()
	var tbe_d := {}
	for k: int in traces_by_event:
		tbe_d[k] = (traces_by_event[k] as Array).duplicate()
	var jobs_d := []
	for j: Job in jobs:
		jobs_d.append(j.to_dict())
	return {
		"seed": seed,
		# rng state is a 64-bit int; JSON numbers are doubles, so keep it a string.
		"rng_state": str(rng.state) if rng != null else "",
		"turn": turn,
		"heat": heat,
		"characters": chars_d,
		"slots": slots_d,
		"relationships": rels_d,
		"events": events_d,
		"traces": traces_d,
		"traces_by_event": tbe_d,
		"jobs": jobs_d,
		"pending_judgments": [],
		"config": config.to_dict() if config != null else null,
		"next_char_id": _next_char_id,
		"next_trace_id": _next_trace_id,
		"next_slot_id": _next_slot_id,
		"next_job_id": _next_job_id,
	}


static func from_dict(d: Dictionary) -> WorldState:
	var ws := WorldState.new()
	ws.seed = int(d["seed"])
	ws.rng = RandomNumberGenerator.new()
	ws.rng.seed = ws.seed
	if str(d.get("rng_state", "")) != "":
		ws.rng.state = str(d["rng_state"]).to_int()
	ws.turn = int(d["turn"])
	ws.heat = float(d["heat"])
	for k in d["characters"]:
		ws.characters[int(k)] = Character.from_dict(d["characters"][k])
	for k in d["slots"]:
		ws.slots[int(k)] = Slot.from_dict(d["slots"][k])
	for k in d["relationships"]:
		ws.relationships[int(k)] = Relationship.from_dict(d["relationships"][k])
	for ed in d["events"]:
		ws._events.append(Event.from_dict(ed))
	for k in d["traces"]:
		ws.traces[int(k)] = Trace.from_dict(d["traces"][k])
	for k in d["traces_by_event"]:
		ws.traces_by_event[int(k)] = Array(World.int_array(d["traces_by_event"][k]))
	for jd in d["jobs"]:
		ws.jobs.append(Job.from_dict(jd))
	ws.config = Config.from_dict(d["config"]) if d.get("config") != null else null
	ws._next_char_id = int(d["next_char_id"])
	ws._next_trace_id = int(d["next_trace_id"])
	ws._next_slot_id = int(d["next_slot_id"])
	ws._next_job_id = int(d.get("next_job_id", 0))
	return ws
