class_name MatchRunner
extends RefCounted

# Speelt één AI-vs-AI potje op een eigen engine-instantie, stap voor stap.
# Zo kunnen meerdere potjes parallel + versneld gespeeld en getoond worden.

const GameSessionScript := preload("res://scripts/core/GameSession.gd")

var engine: Node
var ai1
var ai2
var done: bool = false
var winner: int = -1
var _guard: int = 0


func _init(controller1, controller2, doctrine1: int = Constants.Doctrine.MENS, doctrine2: int = Constants.Doctrine.MENS) -> void:
	ai1 = controller1
	ai2 = controller2
	ai1.player_id = Constants.PLAYER_1
	ai2.player_id = Constants.PLAYER_2
	engine = GameSessionScript.new()
	engine.start_new_game(doctrine1, doctrine2)
	engine.submit_placement(Constants.PLAYER_1, ai1.choose_placement(engine.state))
	engine.submit_placement(Constants.PLAYER_2, ai2.choose_placement(engine.state))


func state() -> GameState:
	return engine.state


## Eén beslissing verder (define/reveal/rps/link/action).
func step() -> void:
	if done:
		return
	_guard += 1
	if _guard > 2500:
		# Patstelling → beslis op materiaal, dan haven-voortgang (trainings-signaal).
		done = true
		winner = _tiebreak()
		return
	var st: GameState = engine.state
	var ph: int = st.phase
	if ph == Phase.Type.GAME_OVER:
		done = true
		winner = st.winner
		return
	var cur = ai1 if st.current_player == Constants.PLAYER_1 else ai2
	if Phase.is_define(ph):
		if st.cards_defined[Constants.PLAYER_1].size() == 0:
			engine.submit_define_cards(Constants.PLAYER_1, ai1.generate_cards(st))
		if st.cards_defined[Constants.PLAYER_2].size() == 0:
			engine.submit_define_cards(Constants.PLAYER_2, ai2.generate_cards(st))
	elif Phase.is_reveal(ph):
		engine.acknowledge_reveal()
	elif Phase.is_linking(ph):
		var link: Dictionary = cur.choose_link(st)
		if link.has("card_id"):
			engine.submit_link(st.current_player, link.card_id, link.pawn_id)
		else:
			done = true
	elif ph == Phase.Type.ACTION:
		if st.pending_wolf_step_pawn != -1:
			var step: Dictionary = cur.choose_wolf_step(st)
			if step.has("target"):
				engine.submit_wolf_step(st.current_player, step.target)
			else:
				engine.skip_wolf_step(st.current_player)
		else:
			var act: Dictionary = cur.choose_action(st)
			if act.is_empty():
				done = true
			else:
				match String(act.type):
					"move":
						engine.submit_move(st.current_player, act.pawn_id, act.target)
					"attack":
						engine.submit_attack(st.current_player, act.attacker_id, act.defender_id)
					"shot":
						engine.submit_shot(st.current_player, act.shooter_id, act.target_id)
					"charge":
						engine.submit_charge(st.current_player, act.pawn_id, act.move_target, act.defender_id)
	if engine.state.phase == Phase.Type.GAME_OVER:
		done = true
		winner = engine.state.winner


func _tiebreak() -> int:
	var st: GameState = engine.state
	# 1) meeste pionnen over
	var a1: int = st.get_alive_pawns_for(Constants.PLAYER_1).size()
	var a2: int = st.get_alive_pawns_for(Constants.PLAYER_2).size()
	if a1 != a2:
		return Constants.PLAYER_1 if a1 > a2 else Constants.PLAYER_2
	# 2) meeste in de haven
	var h1: int = Rules.count_pawns_in_haven(st, Constants.PLAYER_1)
	var h2: int = Rules.count_pawns_in_haven(st, Constants.PLAYER_2)
	if h1 != h2:
		return Constants.PLAYER_1 if h1 > h2 else Constants.PLAYER_2
	# 3) verst opgerukt richting eigen doelhaven (bijna nooit exact gelijk → wél signaal)
	var p1: int = _haven_closeness(st, Constants.PLAYER_1)
	var p2: int = _haven_closeness(st, Constants.PLAYER_2)
	if p1 != p2:
		return Constants.PLAYER_1 if p1 > p2 else Constants.PLAYER_2
	return -1


func _haven_closeness(st: GameState, side: int) -> int:
	var haven: Array = Constants.get_haven_for_player(side)
	var total: int = 0
	for pawn in st.pawns.values():
		if pawn.owner_id != side or pawn.is_eliminated:
			continue
		var best: int = 999
		for h in haven:
			var d: int = abs(pawn.position.x - h.x) + abs(pawn.position.y - h.y)
			if d < best:
				best = d
		total += Constants.BOARD_SIZE * 2 - best
	return total


func dispose() -> void:
	if engine != null and is_instance_valid(engine):
		engine.free()
		engine = null
