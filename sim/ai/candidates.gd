class_name Candidates
extends RefCounted
# gangs-action-choice.md §2. Gate-first candidate generation: cheap
# `requires` predicates against the actor's BELIEFS kill most of the space,
# then targets expand over the attention set only. The idle floor candidate
# is always included so selection has a defined answer.


static func generate(ws: WorldState, c: Character) -> Array:
	var out := []
	for action: Action in ActionRegistry.all_actions():
		if action.targeted:
			for tid in c.attention:
				var target: Character = ws.characters[tid]
				if not action.requires(ws, c, target):
					continue
				for vis in action.visibilities:
					out.append(_make(action, c, tid, vis))
		else:
			if not action.requires(ws, c, null):
				continue
			for vis in action.visibilities:
				out.append(_make(action, c, -1, vis))
	return out


static func _make(action: Action, c: Character, target_id: int, vis: int) -> ActionCandidate:
	var cand := ActionCandidate.new()
	cand.action = action.id
	cand.actor_id = c.id
	cand.target_id = target_id
	cand.visibility = vis
	return cand
