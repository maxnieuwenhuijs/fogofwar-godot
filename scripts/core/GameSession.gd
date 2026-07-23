extends Node

signal state_updated(state: GameState)
signal phase_changed(new_phase: int, old_phase: int)
signal placement_submitted(player_id: int)
signal cards_revealed_event(totals_p1: Dictionary, totals_p2: Dictionary, initiative_winner: int)
signal turn_changed(player_id: int)
signal action_performed(action: Dictionary, result: Dictionary)
signal wolf_step_pending(pawn_id: int)
signal cycle_started(cycle_number: int)
signal game_over(winner_id: int)
signal error_occurred(player_id: int, message: String)

var state: GameState = null

var _linking_queue: Array = []
var _reveal_pending: Dictionary = {}

func _ready() -> void:
	state = GameState.new()

## Start een partij: doctrines vastleggen, daarna vrije opstelling (PLACEMENT).
## rules_config: per-match regelknoppen (F0.2); null = 4.1.9-hr-defaults.
func start_new_game(doctrine_p1: int = Constants.Doctrine.MENS, doctrine_p2: int = Constants.Doctrine.MENS, rules_config: RulesConfig = null) -> void:
	state = GameState.new()
	if rules_config != null:
		state.rules = rules_config
	state.doctrines[Constants.PLAYER_1] = doctrine_p1
	state.doctrines[Constants.PLAYER_2] = doctrine_p2
	state.cycle = 1
	state.round_number = 1
	_transition_to(Phase.Type.PLACEMENT)
	state_updated.emit(state)

## Gemak: start + standaard-opstelling voor beide spelers (tests, sims, AI-partijen).
func start_new_game_default(doctrine_p1: int = Constants.Doctrine.MENS, doctrine_p2: int = Constants.Doctrine.MENS) -> void:
	start_new_game(doctrine_p1, doctrine_p2)
	submit_placement(Constants.PLAYER_1, state.default_placement(Constants.PLAYER_1))
	submit_placement(Constants.PLAYER_2, state.default_placement(Constants.PLAYER_2))

## Vrije opstelling binnen de twee thuisrijen (v4.1 §2.2). Beide ingediend → Cyclus 1.
func submit_placement(player_id: int, placements: Array) -> bool:
	# F0.3: alle legaliteit door één poort (Validator); mutatie blijft hier tot F0.4.
	var verdict: Dictionary = Validator.is_legal(state, Actions.make_place(placements), player_id)
	if not verdict.legal:
		error_occurred.emit(player_id, verdict.reason)
		return false
	state.apply_placement(player_id, placements)
	placement_submitted.emit(player_id)
	state_updated.emit(state)
	if state.placements_done.get(Constants.PLAYER_1, false) and state.placements_done.get(Constants.PLAYER_2, false):
		_transition_to(Phase.Type.SETUP_1_DEFINE)
		cycle_started.emit(1)
		state_updated.emit(state)
	return true

func submit_default_placement(player_id: int) -> bool:
	return submit_placement(player_id, state.default_placement(player_id))

func submit_define_cards(player_id: int, cards_data: Array) -> bool:
	var verdict: Dictionary = Validator.is_legal(state, Actions.make_define_cards(cards_data), player_id)
	if not verdict.legal:
		error_occurred.emit(player_id, verdict.reason)
		return false
	var new_cards: Array = []
	for d in cards_data:
		var card := Card.new(
			state.next_card_id(),
			player_id,
			state.round_number,
			int(d.hp),
			int(d.stamina),
			int(d.attack),
		)
		new_cards.append(card)
		state.all_cards[card.id] = card
	state.cards_defined[player_id] = new_cards
	state_updated.emit(state)

	var p1_done: bool = state.cards_defined[Constants.PLAYER_1].size() > 0
	var p2_done: bool = state.cards_defined[Constants.PLAYER_2].size() > 0
	if p1_done and p2_done:
		_enter_reveal_phase()
	return true

func _enter_reveal_phase() -> void:
	state.cards_revealed[Constants.PLAYER_1] = state.cards_defined[Constants.PLAYER_1].duplicate()
	state.cards_revealed[Constants.PLAYER_2] = state.cards_defined[Constants.PLAYER_2].duplicate()
	_transition_to(Phase.reveal_for_round(state.round_number))
	# v4.1: initiatief is altijd deterministisch beslist (bod → speed-bod → vorige houder).
	_reveal_pending = Rules.compute_initiative(state)
	cards_revealed_event.emit(
		_reveal_pending.totals_p1,
		_reveal_pending.totals_p2,
		_reveal_pending.winner,
	)

func acknowledge_reveal() -> void:
	if not Phase.is_reveal(state.phase):
		return
	if _reveal_pending.is_empty():
		return
	var init_result: Dictionary = _reveal_pending
	_reveal_pending = {}
	state.initiative_player = init_result.winner
	state.last_initiative_winner = init_result.winner
	_begin_linking()

func _begin_linking() -> void:
	_linking_queue = [state.initiative_player, Constants.opponent(state.initiative_player)]
	state.current_player = _linking_queue[0]
	# Heeft de initiatiefhouder zelf geen koppelwerk (geen vrije pionnen), dan
	# start de tegenstander (staartkoppelen vanaf de eerste beurt).
	if not _player_has_pending_link_work(state.current_player) \
			and _player_has_pending_link_work(_linking_queue[1]):
		state.current_player = _linking_queue[1]
	_transition_to(Phase.linking_for_round(state.round_number))
	turn_changed.emit(state.current_player)
	_check_linking_completeness()

func _check_linking_completeness() -> void:
	if not Phase.is_linking(state.phase):
		return
	# Klaar zodra geen van beide spelers nog koppelwerk heeft; kaarten zonder
	# geldige pion vervallen gewoon (v4.1 §4.3-C-3).
	if not _player_has_pending_link_work(Constants.PLAYER_1) \
			and not _player_has_pending_link_work(Constants.PLAYER_2):
		_advance_from_linking()

func _player_has_unlinked_pawn(player_id: int) -> bool:
	for pawn in state.pawns.values():
		if pawn.owner_id == player_id and not pawn.is_eliminated and pawn.linked_card_id == -1:
			return true
	return false

func submit_link(player_id: int, card_id: int, pawn_id: int) -> bool:
	var verdict: Dictionary = Validator.is_legal(state, Actions.make_link(card_id, pawn_id), player_id)
	if not verdict.legal:
		error_occurred.emit(player_id, verdict.reason)
		return false
	var card: Card = state.all_cards.get(card_id, null)
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	var doctrine: Dictionary = state.doctrine_data_of(player_id)
	# Beer: +1 HP buiten het budget (v4.1 §6.4). Speed-bonus buiten het budget:
	# Muis krijgt +1 op elke pion (zwerm-mobiliteit), Vos +1 op cavalerie.
	var speed_bonus: int = int(doctrine.get("speed_bonus", 0))
	if pawn.unit_type == Constants.UnitType.CAVALRY:
		speed_bonus += int(doctrine.cav_speed_bonus)
	pawn.link_card(card, doctrine.hp_bonus, speed_bonus)
	# Vos: de toewijzing is gedekt tot de pion schade toebrengt of ontvangt (§6.6).
	pawn.card_revealed = not doctrine.hidden_link
	state_updated.emit(state)
	_advance_linking_turn()
	return true

## Om de beurt koppelen vanaf de initiatiefhouder; is één speler klaar, dan koppelt
## de ander zijn resterende kaarten achter elkaar (staartkoppelen, v4.1 §4.3-C-2).
func _advance_linking_turn() -> void:
	if not Phase.is_linking(state.phase):
		return
	var next_player: int = Constants.opponent(state.current_player)
	var next_has_work: bool = _player_has_pending_link_work(next_player)
	var current_has_work: bool = _player_has_pending_link_work(state.current_player)
	if next_has_work:
		state.current_player = next_player
		turn_changed.emit(state.current_player)
		if not Phase.is_linking(state.phase):
			return
		_check_linking_completeness()
	elif current_has_work:
		turn_changed.emit(state.current_player)
		if not Phase.is_linking(state.phase):
			return
		_check_linking_completeness()
	else:
		_advance_from_linking()

func _player_has_pending_link_work(player_id: int) -> bool:
	var has_unlinked_card := false
	for c in state.cards_revealed[player_id]:
		if not c.is_linked():
			has_unlinked_card = true
			break
	if not has_unlinked_card:
		return false
	return _player_has_unlinked_pawn(player_id)

func _advance_from_linking() -> void:
	_linking_queue.clear()
	_reveal_pending = {}
	if state.round_number < state.rules.rounds_per_cycle:
		state.round_number += 1
		state.reset_for_new_round()
		_transition_to(Phase.define_for_round(state.round_number))
	else:
		_enter_action_phase()

func _enter_action_phase() -> void:
	# De initiatiefhouder van Ronde 3 begint. Kan hij niets, dan de tegenstander;
	# kan niemand iets, dan direct de Resetfase (v4.1 §4.4/4.5).
	state.current_player = state.initiative_player
	_transition_to(Phase.Type.ACTION)
	var current_can: bool = Rules.can_player_act(state, state.current_player)
	var opponent_id: int = Constants.opponent(state.current_player)
	var opponent_can: bool = Rules.can_player_act(state, opponent_id)
	if not current_can and not opponent_can:
		_start_new_cycle()
		return
	if not current_can:
		state.current_player = opponent_id
	turn_changed.emit(state.current_player)

func submit_move(player_id: int, pawn_id: int, target_pos: Vector2i) -> bool:
	return _apply_action(player_id, Actions.make_move(pawn_id, target_pos))

## Melee-aanval (Infanterie, of Cavalerie zonder verplaatsing).
func submit_attack(player_id: int, attacker_id: int, defender_id: int) -> bool:
	return _apply_action(player_id, Actions.make_melee(attacker_id, defender_id))

## Beschieting: infanterieschot (afstand exact 2) of artillerievuur (vaste dracht 6, +1 Leeuw).
func submit_shot(player_id: int, shooter_id: int, target_id: int) -> bool:
	return _apply_action(player_id, Actions.make_shoot(shooter_id, target_id))

## Cavalerie-charge: bewegen + optionele melee in één actie (defender_id -1 = geen aanval).
func submit_charge(player_id: int, pawn_id: int, move_target: Vector2i, defender_id: int) -> bool:
	return _apply_action(player_id, Actions.make_charge(pawn_id, move_target, defender_id))

## Wolf: de optionele gratis stap na een melee. target = aangrenzend leeg vak.
func submit_wolf_step(player_id: int, target: Vector2i) -> bool:
	return _apply_action(player_id, Actions.make_wolf_step(target))

func skip_wolf_step(player_id: int) -> bool:
	# Stil bij weigering (bestaand gedrag: geen error_occurred-signaal).
	var res: Dictionary = Reducer.apply(state, Actions.make_skip_wolf_step(), player_id)
	if not res.ok:
		return false
	_relay_events(res.events)
	return true

## F0.4a-shim: actiefase-acties gaan door Reducer.apply; de events worden
## 1-op-1 naar de bestaande signals vertaald zodat game.gd niets merkt.
func _apply_action(player_id: int, action: Dictionary) -> bool:
	var res: Dictionary = Reducer.apply(state, action, player_id)
	if not res.ok:
		error_occurred.emit(player_id, res.error)
		return false
	_relay_events(res.events)
	return true

func _relay_events(events: Array) -> void:
	for ev in events:
		match String(ev.type):
			Reducer.EV_ACTION:
				action_performed.emit(ev.payload.action, ev.payload.result)
			Reducer.EV_STATE:
				state_updated.emit(state)
			Reducer.EV_WOLF_PENDING:
				wolf_step_pending.emit(ev.payload.pawn_id)
			Reducer.EV_TURN:
				turn_changed.emit(ev.payload.player_id)
			Reducer.EV_PHASE:
				phase_changed.emit(ev.payload.new_phase, ev.payload.old_phase)
			Reducer.EV_GAME_OVER:
				game_over.emit(ev.payload.winner)
			Reducer.EV_CYCLE_RESET:
				_start_new_cycle()  # verhuist in F0.4b naar de reducer

func _start_new_cycle() -> void:
	state.reset_for_new_cycle()
	var winner: int = Rules.check_win(state)
	if winner != -1:
		state.winner = winner
		_transition_to(Phase.Type.GAME_OVER)
		game_over.emit(winner)
		return
	_transition_to(Phase.Type.SETUP_1_DEFINE)
	cycle_started.emit(state.cycle)
	state_updated.emit(state)

func _transition_to(new_phase: int) -> void:
	var old: int = state.phase
	state.phase = new_phase
	phase_changed.emit(new_phase, old)

func get_state() -> GameState:
	return state
