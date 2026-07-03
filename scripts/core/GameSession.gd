extends Node

signal state_updated(state: GameState)
signal phase_changed(new_phase: int, old_phase: int)
signal placement_submitted(player_id: int)
signal cards_revealed_event(totals_p1: Dictionary, totals_p2: Dictionary, initiative_winner: int, needs_rps: bool)
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
func start_new_game(doctrine_p1: int = Constants.Doctrine.MENS, doctrine_p2: int = Constants.Doctrine.MENS) -> void:
	state = GameState.new()
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
	if state.phase != Phase.Type.PLACEMENT:
		error_occurred.emit(player_id, "Niet in opstellingsfase")
		return false
	if state.placements_done.get(player_id, false):
		error_occurred.emit(player_id, "Opstelling al ingediend")
		return false
	if not state.is_valid_placement(player_id, placements):
		error_occurred.emit(player_id, "Ongeldige opstelling")
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
	if not Phase.is_define(state.phase):
		error_occurred.emit(player_id, "Niet in definitie fase")
		return false
	if state.cards_defined.get(player_id, []).size() > 0:
		error_occurred.emit(player_id, "Je hebt al gedefinieerd deze ronde")
		return false
	var doctrine: Dictionary = state.doctrine_data_of(player_id)
	var expected: int = doctrine.cards
	if cards_data.size() != expected:
		error_occurred.emit(player_id, "Moet %d kaarten definiëren" % expected)
		return false
	var new_cards: Array = []
	for d in cards_data:
		if not Card.is_valid_stats(int(d.hp), int(d.stamina), int(d.attack), doctrine.budget, doctrine.speed_max):
			error_occurred.emit(player_id, "Ongeldige statistieken (som moet %d zijn, elk minstens 1)" % doctrine.budget)
			return false
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
		false,
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
	if not Phase.is_linking(state.phase):
		error_occurred.emit(player_id, "Niet in linking fase")
		return false
	if state.current_player != player_id:
		error_occurred.emit(player_id, "Niet jouw beurt")
		return false
	var card: Card = state.all_cards.get(card_id, null)
	if card == null or card.owner_id != player_id or card.round_number != state.round_number or card.is_linked():
		error_occurred.emit(player_id, "Ongeldige kaart")
		return false
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.owner_id != player_id or pawn.is_eliminated or pawn.linked_card_id != -1:
		error_occurred.emit(player_id, "Ongeldige pion")
		return false
	var doctrine: Dictionary = state.doctrine_data_of(player_id)
	# Beer: +1 HP buiten het budget (v4.1 §6.4); Vos: cavalerie +1 Speed (perk).
	var speed_bonus: int = 0
	if pawn.unit_type == Constants.UnitType.CAVALRY:
		speed_bonus = int(doctrine.cav_speed_bonus)
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
	if state.round_number < Constants.ROUNDS_PER_CYCLE:
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

func _validate_action_turn(player_id: int) -> bool:
	if state.phase != Phase.Type.ACTION:
		error_occurred.emit(player_id, "Niet in actie fase")
		return false
	if state.current_player != player_id:
		error_occurred.emit(player_id, "Niet jouw beurt")
		return false
	if state.pending_wolf_step_pawn != -1:
		error_occurred.emit(player_id, "Eerst de Wolf-stap afronden (of overslaan)")
		return false
	return true

func submit_move(player_id: int, pawn_id: int, target_pos: Vector2i) -> bool:
	if not _validate_action_turn(player_id):
		return false
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.owner_id != player_id:
		error_occurred.emit(player_id, "Ongeldige pion")
		return false
	var from_pos: Vector2i = pawn.position
	if not Rules.apply_move(state, pawn_id, target_pos):
		error_occurred.emit(player_id, "Ongeldige zet")
		return false
	var action := {
		"type": "move",
		"pawn_id": pawn_id,
		"from": from_pos,
		"target": target_pos,
	}
	var result := {"success": true}
	action_performed.emit(action, result)
	_post_action(player_id)
	return true

## Melee-aanval (Infanterie, of Cavalerie zonder verplaatsing).
func submit_attack(player_id: int, attacker_id: int, defender_id: int) -> bool:
	if not _validate_action_turn(player_id):
		return false
	var attacker: Pawn = state.pawns.get(attacker_id, null)
	if attacker == null or attacker.owner_id != player_id:
		error_occurred.emit(player_id, "Ongeldige aanvaller")
		return false
	var result: Dictionary = Rules.apply_melee(state, attacker_id, defender_id)
	if not result.success:
		error_occurred.emit(player_id, "Ongeldige aanval")
		return false
	var action := {"type": "attack", "attacker_id": attacker_id, "defender_id": defender_id}
	action_performed.emit(action, result)
	_after_combat(player_id, attacker_id, result)
	return true

## Beschieting: infanterieschot (afstand 2) of artillerievuur (dracht = Speed).
func submit_shot(player_id: int, shooter_id: int, target_id: int) -> bool:
	if not _validate_action_turn(player_id):
		return false
	var shooter: Pawn = state.pawns.get(shooter_id, null)
	if shooter == null or shooter.owner_id != player_id:
		error_occurred.emit(player_id, "Ongeldige schutter")
		return false
	var result: Dictionary = Rules.apply_shot(state, shooter_id, target_id)
	if not result.success:
		error_occurred.emit(player_id, "Ongeldig schot")
		return false
	var action := {"type": "shot", "shooter_id": shooter_id, "target_id": target_id}
	action_performed.emit(action, result)
	_post_action(player_id)
	return true

## Cavalerie-charge: bewegen + optionele melee in één actie (defender_id -1 = geen aanval).
func submit_charge(player_id: int, pawn_id: int, move_target: Vector2i, defender_id: int) -> bool:
	if not _validate_action_turn(player_id):
		return false
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null or pawn.owner_id != player_id:
		error_occurred.emit(player_id, "Ongeldige pion")
		return false
	var result: Dictionary = Rules.apply_charge(state, pawn_id, move_target, defender_id)
	if not result.success:
		error_occurred.emit(player_id, "Ongeldige charge")
		return false
	var action := {
		"type": "charge",
		"pawn_id": pawn_id,
		"move_target": move_target,
		"defender_id": defender_id,
	}
	action_performed.emit(action, result)
	_after_combat(player_id, pawn_id, result)
	return true

## Wolf: de optionele gratis stap na een melee. target = aangrenzend leeg vak.
func submit_wolf_step(player_id: int, target: Vector2i) -> bool:
	if state.phase != Phase.Type.ACTION or state.current_player != player_id:
		error_occurred.emit(player_id, "Niet jouw beurt")
		return false
	var pawn_id: int = state.pending_wolf_step_pawn
	if pawn_id == -1:
		error_occurred.emit(player_id, "Geen Wolf-stap tegoed")
		return false
	var from_pos: Vector2i = state.pawns[pawn_id].position
	if not Rules.apply_wolf_step(state, pawn_id, target):
		error_occurred.emit(player_id, "Ongeldige Wolf-stap")
		return false
	state.pending_wolf_step_pawn = -1
	var action := {"type": "wolf_step", "pawn_id": pawn_id, "from": from_pos, "target": target}
	action_performed.emit(action, {"success": true})
	_post_action(player_id)
	return true

func skip_wolf_step(player_id: int) -> bool:
	if state.pending_wolf_step_pawn == -1 or state.current_player != player_id:
		return false
	state.pending_wolf_step_pawn = -1
	_post_action(player_id)
	return true

## Na melee/charge: eerst win-check, daarna eventueel de Wolf-stap openzetten.
func _after_combat(player_id: int, attacker_id: int, result: Dictionary) -> void:
	state_updated.emit(state)
	var winner: int = Rules.check_win(state)
	if winner != -1:
		state.winner = winner
		_transition_to(Phase.Type.GAME_OVER)
		game_over.emit(winner)
		return
	if result.get("wolf_step_available", false):
		state.pending_wolf_step_pawn = attacker_id
		wolf_step_pending.emit(attacker_id)
		return  # beurt wisselt pas na submit_wolf_step / skip_wolf_step
	_check_action_phase_status()

func _post_action(_player_id: int) -> void:
	state_updated.emit(state)
	var winner: int = Rules.check_win(state)
	if winner != -1:
		state.winner = winner
		_transition_to(Phase.Type.GAME_OVER)
		game_over.emit(winner)
		return
	_check_action_phase_status()

func _check_action_phase_status() -> void:
	if state.phase != Phase.Type.ACTION:
		return
	var current_can: bool = Rules.can_player_act(state, state.current_player)
	var opponent: int = Constants.opponent(state.current_player)
	var opponent_can: bool = Rules.can_player_act(state, opponent)
	if not current_can and not opponent_can:
		_start_new_cycle()
		return
	if not current_can and opponent_can:
		state.current_player = opponent
		turn_changed.emit(state.current_player)
	elif current_can and opponent_can:
		state.current_player = opponent
		turn_changed.emit(state.current_player)
	else:
		turn_changed.emit(state.current_player)

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
