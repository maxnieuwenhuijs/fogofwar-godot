extends "res://scripts/ai/AIController.gd"

# Medium: 1-ply greedy op de gedeelde evaluatie. Erft slimme kaarten + koppeling.
func choose_action(state: GameState) -> Dictionary:
	return best_greedy_action(state)
