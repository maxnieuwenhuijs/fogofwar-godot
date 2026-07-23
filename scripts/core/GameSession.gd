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

## F0.7: opt-in event-log — zet een MatchLog (na start_new_game) en elke
## geaccepteerde actie wordt bijgeschreven. Gebruikt door -- record en straks
## door de server/arena; de gewone UI-flow laat dit op null.
var match_log: MatchLog = null


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
	return _apply_action(player_id, Actions.make_place(placements))

func submit_default_placement(player_id: int) -> bool:
	return submit_placement(player_id, state.default_placement(player_id))

func submit_define_cards(player_id: int, cards_data: Array) -> bool:
	return _apply_action(player_id, Actions.make_define_cards(cards_data))

## Per-speler reveal-bevestiging (F0.4b): de fase gaat pas door als beide
## spelers geackt hebben. Stil bij weigering (het oude ack-pad was ook stil).
func submit_ack_reveal(player_id: int) -> bool:
	var action := Actions.make_ack_reveal()
	var res: Dictionary = Reducer.apply(state, action, player_id)
	if not res.ok:
		return false
	_record(player_id, action, res.events)
	_relay_events(res.events)
	return true

## Compat-shim voor de huidige single-ack-UI: bevestigt voor BEIDE spelers,
## zodat offline gedrag identiek blijft aan vóór F0.4b.
func acknowledge_reveal() -> void:
	submit_ack_reveal(Constants.PLAYER_1)
	submit_ack_reveal(Constants.PLAYER_2)

func submit_link(player_id: int, card_id: int, pawn_id: int) -> bool:
	return _apply_action(player_id, Actions.make_link(card_id, pawn_id))

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

## Opgeven (F0.4c) — vanuit de UI (opgeven-knop in het hulpmenu).
func submit_resign(player_id: int) -> bool:
	return _apply_action(player_id, Actions.make_resign())

## Timeout claimen (F0.8) — offline is game.gd de klok-autoriteit en geeft
## die zijn eigen now_ms mee; online wordt dat de server (F4).
func submit_claim_timeout(player_id: int, now_ms: int) -> bool:
	var action := Actions.make_claim_timeout()
	var res: Dictionary = Reducer.apply(state, action, player_id, now_ms)
	if not res.ok:
		error_occurred.emit(player_id, res.error)
		return false
	_record(player_id, action, res.events)
	_relay_events(res.events)
	return true

func skip_wolf_step(player_id: int) -> bool:
	# Stil bij weigering (bestaand gedrag: geen error_occurred-signaal).
	var action := Actions.make_skip_wolf_step()
	var res: Dictionary = Reducer.apply(state, action, player_id)
	if not res.ok:
		return false
	_record(player_id, action, res.events)
	_relay_events(res.events)
	return true

## F0.4a-shim: actiefase-acties gaan door Reducer.apply; de events worden
## 1-op-1 naar de bestaande signals vertaald zodat game.gd niets merkt.
func _apply_action(player_id: int, action: Dictionary) -> bool:
	var res: Dictionary = Reducer.apply(state, action, player_id)
	if not res.ok:
		error_occurred.emit(player_id, res.error)
		return false
	_record(player_id, action, res.events)
	_relay_events(res.events)
	return true

func _record(player_id: int, action: Dictionary, events: Array) -> void:
	if match_log != null:
		match_log.record(player_id, action, events, state)

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
			Reducer.EV_PLACEMENT:
				placement_submitted.emit(ev.payload.player_id)
			Reducer.EV_CARDS_REVEALED:
				cards_revealed_event.emit(ev.payload.totals_p1, ev.payload.totals_p2, ev.payload.winner)
			Reducer.EV_CYCLE_STARTED:
				cycle_started.emit(ev.payload.cycle)

func _transition_to(new_phase: int) -> void:
	var old: int = state.phase
	state.phase = new_phase
	phase_changed.emit(new_phase, old)

func get_state() -> GameState:
	return state
