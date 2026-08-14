class_name Rng
# Deterministic randomness helpers (doc 1 §1). Every function takes the
# explicit RandomNumberGenerator owned by WorldState — the global RNG and the
# zero-arg Array shuffle/pick_random methods are banned under sim/ (CI grep).


# In-place Fisher-Yates shuffle.
static func shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func pick(arr: Array, rng: RandomNumberGenerator) -> Variant:
	assert(not arr.is_empty(), "Rng.pick on empty array")
	return arr[rng.randi_range(0, arr.size() - 1)]


# Returns an element of arr, chosen with probability proportional to its
# weight. arr and weights are parallel arrays.
static func weighted_pick(arr: Array, weights: Array, rng: RandomNumberGenerator) -> Variant:
	assert(arr.size() == weights.size(), "Rng.weighted_pick: arr/weights size mismatch")
	assert(not arr.is_empty(), "Rng.weighted_pick on empty array")
	var total := 0.0
	for w: float in weights:
		assert(w >= 0.0, "Rng.weighted_pick: negative weight")
		total += w
	assert(total > 0.0, "Rng.weighted_pick: all weights zero")
	var roll := rng.randf_range(0.0, total)
	var acc := 0.0
	for i in arr.size():
		acc += weights[i]
		if roll < acc:
			return arr[i]
	return arr[arr.size() - 1]  # roll landed exactly on total


static func randfn(mean: float, deviation: float, rng: RandomNumberGenerator) -> float:
	return rng.randfn(mean, deviation)
