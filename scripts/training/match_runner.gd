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


func _init(controller1, controller2, doctrine1: int = Constants.Doctrine.MENS, doctrine2: int = Constants.Doctrine.MENS, seed_val: int = 0, rules: RulesConfig = null) -> void:
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
	if rules != null:
		_state.rules = rules  # F2.5: trainer/sim onder een custom (v4.2-)config
	_state.doctrines[Constants.PLAYER_1] = doctrine1
	_state.doctrines[Constants.PLAYER_2] = doctrine2
	_state.phase = Phase.Type.PLACEMENT
	Reducer.apply(_state, Actions.make_place(ai1.choose_placement(_state)), Constants.PLAYER_1)
	Reducer.apply(_state, Actions.make_place(ai2.choose_placement(_state)), Constants.PLAYER_2)
	_state.init_pools()


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
	if ph == Phase.Type.CYCLE_SPAWN:
		# F2.5 (v4.2): volste inzet uit de sample-opties (max spawnen).
		for pid in [Constants.PLAYER_1, Constants.PLAYER_2]:
			if _state.spawn_done.get(pid, false):
				continue
			var opties: Array = Validator.legal_actions(_state, pid)
			var volste: Dictionary = Actions.make_spawn([])
			for a in opties:
				if String(a.type) == Actions.SPAWN and (a.spawns as Array).size() > (volste.spawns as Array).size():
					volste = a
			Reducer.apply(_state, volste, pid)
	elif Phase.is_define(ph):
		for pid in [Constants.PLAYER_1, Constants.PLAYER_2]:
			if _state.cards_defined[pid].size() > 0 \
					or Validator.expected_define_count(_state, pid) == 0:
				continue
			var bot = ai1 if pid == Constants.PLAYER_1 else ai2
			# F2.5-heuristiek: CP op de ronde-3-kaarten (masterplan); daarna
			# krijgen de eerste `bet` kaarten het extra budgetpunt op hp.
			var bet: int = 0
			if _state.rules.campaign_actief() and _state.round_number == 3 \
					and not _state.cp_bet_done.get(pid, false):
				bet = mini(int(_state.cp.get(pid, 0)), Validator.expected_define_count(_state, pid))
				if bet > 0:
					Reducer.apply(_state, Actions.make_bet_cp(bet), pid)
			var cards: Array = bot.generate_cards(_state)
			for i in mini(bet, cards.size()):
				cards[i].hp = int(cards[i].hp) + 1
			var res: Dictionary = Reducer.apply(_state, Actions.make_define_cards(cards), pid)
			if not res.ok and bet > 0:
				# Terugvallen op de onverdikte set (bet is dan verbrand, D2).
				for i in mini(bet, cards.size()):
					cards[i].hp = int(cards[i].hp) - 1
				Reducer.apply(_state, Actions.make_define_cards(cards), pid)
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
				# F2.5/B3: onder campaign spreekt artillerie CANNON_ACT.
				var camp: bool = _state.rules.campaign_actief()
				match String(act.type):
					"move":
						var loper: Pawn = _state.pawns.get(int(act.pawn_id), null)
						if camp and loper != null and loper.unit_type == Constants.UnitType.ARTILLERY:
							Reducer.apply(_state, Actions.make_cannon_roll(int(act.pawn_id), act.target), _state.current_player)
						else:
							Reducer.apply(_state, Actions.make_move(int(act.pawn_id), act.target), _state.current_player)
					"attack":
						Reducer.apply(_state, Actions.make_melee(int(act.attacker_id), int(act.defender_id)), _state.current_player)
					"shot":
						var schutter: Pawn = _state.pawns.get(int(act.shooter_id), null)
						if camp and schutter != null and schutter.unit_type == Constants.UnitType.ARTILLERY:
							Reducer.apply(_state, Actions.make_cannon_shoot(int(act.shooter_id), int(act.target_id)), _state.current_player)
						else:
							Reducer.apply(_state, Actions.make_shoot(int(act.shooter_id), int(act.target_id)), _state.current_player)
					"charge":
						Reducer.apply(_state, Actions.make_charge(int(act.pawn_id), act.move_target, int(act.defender_id)), _state.current_player)
	if _state.phase == Phase.Type.GAME_OVER:
		done = true
		winner = _state.winner


## Compat: er is geen Node meer om op te ruimen (RefCounted ruimt zichzelf op).
func dispose() -> void:
	pass
