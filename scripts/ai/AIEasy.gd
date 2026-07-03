extends "res://scripts/ai/AIController.gd"

# Easy: evalueert alle zetten maar kiest willekeurig uit de beste paar,
# dus speelt redelijk maar maakt fouten. Erft slimme kaarten + koppeling.
func choose_action(state: GameState) -> Dictionary:
	var actions: Array = enumerate_actions(state, player_id)
	if actions.is_empty():
		return {}
	var scored: Array = []
	for a in actions:
		scored.append({"action": a, "value": evaluate(simulate(state, a), player_id)})
	scored.sort_custom(func(x, y): return x.value > y.value)
	var top: int = mini(3, scored.size())
	return scored[randi() % top].action
