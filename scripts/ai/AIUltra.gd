extends "res://scripts/ai/AIHard.gd"

# Ultra ("god mode"): iterative-deepening negamax met een TIJDSBUDGET per zet.
# Zelfde geleerde gewichten als de rest, maar dieper (tot diepte 5) en breder
# (beam 20/10) nadenken. Draait op de AI-thread, dus de UI blijft vloeiend.

const ULTRA_BEAM_ROOT: int = 20
const ULTRA_BEAM: int = 10
const ULTRA_MAX_DEPTH: int = 5

## Denktijd per zet in ms (instelbaar; hoger = sterker en trager).
var time_budget_ms: int = 2200

var _deadline: int = 0
var _timed_out: bool = false


func choose_action(state: GameState) -> Dictionary:
	var actions: Array = enumerate_actions(state, player_id)
	if actions.is_empty():
		return {}
	_order(actions, state, player_id)
	if actions.size() > ULTRA_BEAM_ROOT:
		actions.resize(ULTRA_BEAM_ROOT)
	_deadline = Time.get_ticks_msec() + time_budget_ms
	# Diepte 2 is altijd haalbaar (≈ Hard-snelheid); daarna verdiepen zolang
	# het budget het toelaat. Bij een timeout telt de laatst afgemaakte diepte.
	var best: Dictionary = actions[0]
	for depth in range(2, ULTRA_MAX_DEPTH + 1):
		_timed_out = false
		var round_best: Dictionary = {}
		var round_val: int = -BIG
		for a in actions:
			var child: GameState = simulate(state, a)
			var v: int = -_negamax_ultra(child, depth - 1, -BIG, BIG, Constants.opponent(player_id))
			if _timed_out:
				break
			if v > round_val:
				round_val = v
				round_best = a
		if _timed_out or round_best.is_empty():
			break
		best = round_best
		# Move-ordering: de beste zet eerst in de volgende (diepere) iteratie.
		actions.erase(best)
		actions.insert(0, best)
	return best


func _negamax_ultra(state: GameState, depth: int, alpha: int, beta: int, side: int) -> int:
	if Time.get_ticks_msec() > _deadline:
		_timed_out = true
		return evaluate(state, side)
	var winner: int = Rules.check_win(state)
	if winner == side:
		return WIN_SCORE + depth
	elif winner != -1:
		return -WIN_SCORE - depth
	if depth <= 0:
		return evaluate(state, side)
	var actions: Array = enumerate_actions(state, side)
	if actions.is_empty():
		var opp: int = Constants.opponent(side)
		if not Rules.can_player_act(state, opp):
			return evaluate(state, side)
		return -_negamax_ultra(state, depth - 1, -beta, -alpha, opp)
	_order(actions, state, side)
	if actions.size() > ULTRA_BEAM:
		actions.resize(ULTRA_BEAM)
	var best: int = -BIG
	for a in actions:
		var child: GameState = simulate(state, a)
		var val: int = -_negamax_ultra(child, depth - 1, -beta, -alpha, Constants.opponent(side))
		if _timed_out:
			return best if best > -BIG else evaluate(state, side)
		if val > best:
			best = val
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best
