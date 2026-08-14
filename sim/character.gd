class_name Character
extends RefCounted
# doc 1 §3. Position fields (rank, patron_id, crew_ids) are DERIVED from slot
# occupancy — never set them directly; World.resync_tree keeps them in sync.

var id: int = -1
var name: String = ""
var state: int = E.CharState.ACTIVE

# Position (derived from slots)
var rank: int = 0                    # 0 = boss, higher = lower in tree
var patron_id: int = -1
var crew_ids: Array[int] = []

# Resources
var standing: float = 0.0
var money: int = 0

# Personality — fixed at generation
var traits: Array[int] = []          # E.Trait
var temperature: float = 0.3         # softmax τ
var competence: float = 0.5          # 0..1

# Goals — mutable, decay toward baseline. `goals` holds ONLY the scalar goals;
# LOYALTY and VENGEANCE live in their target-indexed dictionaries and are
# never present in `goals`.
var goals: Dictionary = {}           # E.Goal -> float
var loyalty: Dictionary = {}         # char_id -> float
var vengeance: Dictionary = {}       # char_id -> float
var goal_baseline: Dictionary = {}   # E.Goal -> float, generated

# Cognition
var beliefs: Dictionary = {}         # event_id -> Belief
var plan: Plan = null
var attention: Array[int] = []       # recomputed each turn

# Bookkeeping
var last_action: StringName = &""
var last_target: int = -1
var favors: Dictionary = {}          # char_id -> int (tokens they owe me)
var purchased_opinion: Dictionary = {}  # char_id -> float, brittle channel


func to_dict() -> Dictionary:
	var beliefs_d := {}
	for k: int in beliefs:
		beliefs_d[k] = (beliefs[k] as Belief).to_dict()
	return {
		"id": id,
		"name": name,
		"state": state,
		"rank": rank,
		"patron_id": patron_id,
		"crew_ids": Array(crew_ids),
		"standing": standing,
		"money": money,
		"traits": Array(traits),
		"temperature": temperature,
		"competence": competence,
		"goals": goals.duplicate(),
		"loyalty": loyalty.duplicate(),
		"vengeance": vengeance.duplicate(),
		"goal_baseline": goal_baseline.duplicate(),
		"beliefs": beliefs_d,
		"plan": plan.to_dict() if plan != null else null,
		"attention": Array(attention),
		"last_action": String(last_action),
		"last_target": last_target,
		"favors": favors.duplicate(),
		"purchased_opinion": purchased_opinion.duplicate(),
	}


static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	c.id = int(d["id"])
	c.name = str(d["name"])
	c.state = int(d["state"])
	c.rank = int(d["rank"])
	c.patron_id = int(d["patron_id"])
	c.crew_ids = World.int_array(d["crew_ids"])
	c.standing = float(d["standing"])
	c.money = int(d["money"])
	c.traits = World.int_array(d["traits"])
	c.temperature = float(d["temperature"])
	c.competence = float(d["competence"])
	c.goals = World.int_keyed_floats(d["goals"])
	c.loyalty = World.int_keyed_floats(d["loyalty"])
	c.vengeance = World.int_keyed_floats(d["vengeance"])
	c.goal_baseline = World.int_keyed_floats(d["goal_baseline"])
	for k in d["beliefs"]:
		c.beliefs[int(k)] = Belief.from_dict(d["beliefs"][k])
	c.plan = Plan.from_dict(d["plan"]) if d["plan"] != null else null
	c.attention = World.int_array(d["attention"])
	c.last_action = StringName(str(d["last_action"]))
	c.last_target = int(d["last_target"])
	c.favors = World.int_keyed_ints(d["favors"])
	c.purchased_opinion = World.int_keyed_floats(d["purchased_opinion"])
	return c


func has_trait(t: int) -> bool:
	return t in traits
