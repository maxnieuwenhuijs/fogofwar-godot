class_name MatchRunner
extends RefCounted

# Speelt één AI-vs-AI potje, stap voor stap. Sinds F0.4c rechtstreeks op
# Reducer.apply met een kale GameState — geen GameSession-Node, geen signals,
# geen free() meer nodig. Dit is hetzelfde pad dat de arena (F1) en de
# server-workers (F4) gebruiken.

var ai1
var ai2
var done: bool = false
var winner: int = -1
var _state: GameState
var _guard: int = 0
## Stap-limiet: bij overschrijding beslist de tiebreak (Reducer.tiebreak_winner).
## Lager = snellere metingen (arena), hoger = zuiverder (training).
var max_steps: int = 2500


func _init(controller1, controller2, doctrine1: int = Constants.Doctrine.MENS, doctrine2: int = Constants.Doctrine.MENS, seed_val: int = 0) -> void:
	ai1 = controller1
	ai2 = controller2
	ai1.player_id = Constants.PLAYER_1
	ai2.player_id = Constants.PLAYER_2
	# F0.1: beide agents krijgen een onafhankelijke sub-stream van de match-seed,
	# zodat een extra loting bij P1 nooit het verloop van P2 verschuift.
	var match_rng := SeededRng.new(seed_val)
	ai1.rng = match_rng.fork("p1")
	ai2.rng = match_rng.fork("p2")
	_state = GameState.new()
	_state.doctrines[Constants.PLAYER_1] = doctrine1
	_state.doctrines[Constants.PLAYER_2] = doctrine2
	_state.phase = Phase.Type.PLACEMENT
	Reducer.apply(_state, Actions.make_place(ai1.choose_placement(_state)), Constants.PLAYER_1)
	Reducer.apply(_state, Actions.make_place(ai2.choose_placement(_state)), Constants.PLAYER_2)


func state() -> GameState:
	return _state


## Eén beslissing verder (define/reveal/link/action).
func step() -> void:
	if done:
		return
	_guard += 1
	if _guard > max_steps:
		# Patstelling → beslis op materiaal, dan haven-voortgang (trainings-signaal).
		done = true
		winner = Reducer.tiebreak_winner(_state)
		return
	var ph: int = _state.phase
	if ph == Phase.Type.GAME_OVER:
		done = true
		winner = _state.winner
		return
	var cur = ai1 if _state.current_player == Constants.PLAYER_1 else ai2
	if Phase.is_define(ph):
		if _state.cards_defined[Constants.PLAYER_1].size() == 0:
			Reducer.apply(_state, Actions.make_define_cards(ai1.generate_cards(_state)), Constants.PLAYER_1)
		if _state.cards_defined[Constants.PLAYER_2].size() == 0:
			Reducer.apply(_state, Actions.make_define_cards(ai2.generate_cards(_state)), Constants.PLAYER_2)
	elif Phase.is_reveal(ph):
		# Per-speler ACK (F0.4b); de runner bevestigt voor beide bots.
		Reducer.apply(_state, Actions.make_ack_reveal(), Constants.PLAYER_1)
		Reducer.apply(_state, Actions.make_ack_reveal(), Constants.PLAYER_2)
	elif Phase.is_linking(ph):
		var link: Dictionary = cur.choose_link(_state)
		if link.has("card_id"):
			Reducer.apply(_state, Actions.make_link(int(link.card_id), int(link.pawn_id)), _state.current_player)
		else:
			done = true
	elif ph == Phase.Type.ACTION:
		if _state.pending_wolf_step_pawn != -1:
			var wolf: Dictionary = cur.choose_wolf_step(_state)
			if wolf.has("target"):
				Reducer.apply(_state, Actions.make_wolf_step(wolf.target), _state.current_player)
			else:
				Reducer.apply(_state, Actions.make_skip_wolf_step(), _state.current_player)
		else:
			var act: Dictionary = cur.choose_action(_state)
			if act.is_empty():
				done = true
			else:
				match String(act.type):
					"move":
						Reducer.apply(_state, Actions.make_move(int(act.pawn_id), act.target), _state.current_player)
					"attack":
						Reducer.apply(_state, Actions.make_melee(int(act.attacker_id), int(act.defender_id)), _state.current_player)
					"shot":
						Reducer.apply(_state, Actions.make_shoot(int(act.shooter_id), int(act.target_id)), _state.current_player)
					"charge":
						Reducer.apply(_state, Actions.make_charge(int(act.pawn_id), act.move_target, int(act.defender_id)), _state.current_player)
	if _state.phase == Phase.Type.GAME_OVER:
		done = true
		winner = _state.winner


## Compat: er is geen Node meer om op te ruimen (RefCounted ruimt zichzelf op).
func dispose() -> void:
	pass
