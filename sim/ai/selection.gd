class_name Selection
extends RefCounted
# gangs-action-choice.md §5. Softmax over the top N — never argmax.
# Per-character temperature is a characterisation tool: Reckless ~erratic,
# Calculating ~near-optimal.


static func choose(ws: WorldState, c: Character, cands: Array) -> ActionCandidate:
	if cands.is_empty():
		return null
	var pool := cands.duplicate()
	pool.sort_custom(func(a: ActionCandidate, b: ActionCandidate):
		if a.score != b.score:
			return a.score > b.score
		if a.action != b.action:
			return String(a.action) < String(b.action)
		return a.target_id < b.target_id)
	var top := pool.slice(0, mini(Tuning.SOFTMAX_TOP_N, pool.size()))
	var tau := maxf(0.01, c.temperature)
	var best_score: float = (top[0] as ActionCandidate).score
	var weights := []
	for cand: ActionCandidate in top:
		weights.append(exp((cand.score - best_score) / tau))
	return Rng.weighted_pick(top, weights, ws.rng)
