class_name AgentL0
extends Agent

# L0 — uniform random uit de legale acties. De ondergrens van elk meetprogramma
# en de motor van de fuzz (F1.4): als L0 crasht of een illegale actie kiest,
# is de engine stuk, niet de agent.


func decide(_view: Dictionary, legal: Array, decide_rng: SeededRng) -> Dictionary:
	if legal.is_empty():
		return {}
	return legal[decide_rng.randi_range(0, legal.size() - 1)]


func wants_view(_phase: int) -> bool:
	return false  # L0 kiest puur uit legal
