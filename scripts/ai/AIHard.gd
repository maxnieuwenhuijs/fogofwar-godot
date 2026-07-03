extends "res://scripts/ai/AIController.gd"

# Hard: negamax (alpha-beta) op de gedeelde zero-sum evaluatie, met beam search
# op basis van zet-sortering zodat de vertakking beheersbaar blijft.
const SEARCH_DEPTH: int = 3
const BEAM_ROOT: int = 14
const BEAM: int = 8
const BIG: int = 1000000000
const WIN_SCORE: int = 5000000


func choose_action(state: GameState) -> Dictionary:
	var actions: Array = enumerate_actions(state, player_id)
	if actions.is_empty():
		return {}
	_order(actions, state, player_id)
	if actions.size() > BEAM_ROOT:
		actions.resize(BEAM_ROOT)
	var best: Dictionary = {}
	var best_val: int = -BIG
	for a in actions:
		var child: GameState = simulate(state, a)
		var v: int = -_negamax(child, SEARCH_DEPTH - 1, -BIG, BIG, Constants.opponent(player_id))
		if v > best_val:
			best_val = v
			best = a
	return best if not best.is_empty() else best_greedy_action(state)


func _negamax(state: GameState, depth: int, alpha: int, beta: int, side: int) -> int:
	var winner: int = Rules.check_win(state)
	if winner == side:
		return WIN_SCORE + depth
	elif winner != -1:
		return -WIN_SCORE - depth
	if depth <= 0:
		return evaluate(state, side)
	var actions: Array = enumerate_actions(state, side)
	if actions.is_empty():
		# Kan niet handelen → beurt naar tegenstander (of eindstand).
		var opp: int = Constants.opponent(side)
		if not Rules.can_player_act(state, opp):
			return evaluate(state, side)
		return -_negamax(state, depth - 1, -beta, -alpha, opp)
	_order(actions, state, side)
	if actions.size() > BEAM:
		actions.resize(BEAM)
	var best: int = -BIG
	for a in actions:
		var child: GameState = simulate(state, a)
		var val: int = -_negamax(child, depth - 1, -beta, -alpha, Constants.opponent(side))
		if val > best:
			best = val
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best


func _order(actions: Array, state: GameState, side: int) -> void:
	actions.sort_custom(func(a, b): return _quick(state, side, a) > _quick(state, side, b))


func _quick(state: GameState, side: int, action: Dictionary) -> int:
	var opp: int = Constants.opponent(side)
	var my_target: Array = Constants.get_haven_for_player(side)
	var opp_target: Array = Constants.get_haven_for_player(opp)
	match String(action.type):
		"attack":
			var defender: Pawn = state.pawns[action.defender_id]
			var attacker: Pawn = state.pawns[action.attacker_id]
			var s: int = 120
			# Bedreiging bij de te verdedigen haven wegslaan = topprioriteit.
			s += maxi(0, Constants.BOARD_SIZE - _min_dist(defender.position, opp_target)) * 8
			if not defender.is_active or attacker.attack_value >= defender.current_hp:
				s += 300
			return s
		"shot":
			var target: Pawn = state.pawns[action.target_id]
			var shooter: Pawn = state.pawns[action.shooter_id]
			var s: int = 130  # veilig chippen: geen terugslag, geen terreinverlies
			s += maxi(0, Constants.BOARD_SIZE - _min_dist(target.position, opp_target)) * 8
			if not target.is_active or Rules.shot_damage(shooter) >= target.current_hp:
				s += 300
			return s
		"charge":
			var defender2: Pawn = state.pawns[action.defender_id]
			var cav: Pawn = state.pawns[action.pawn_id]
			var s2: int = 130
			s2 += maxi(0, Constants.BOARD_SIZE - _min_dist(defender2.position, opp_target)) * 8
			if not defender2.is_active or cav.attack_value >= defender2.current_hp:
				s2 += 300
			s2 += (_min_dist(cav.position, my_target) - _min_dist(action.move_target, my_target)) * 10
			return s2
	# move: dichter bij mijn doelhaven = beter.
	if my_target.has(action.target):
		return 700
	var pawn: Pawn = state.pawns[action.pawn_id]
	return (_min_dist(pawn.position, my_target) - _min_dist(action.target, my_target)) * 20
