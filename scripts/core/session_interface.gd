class_name SessionInterface
extends Node

## F4.3b — de naad tussen game.gd en "wie het spel bijhoudt".
##
## game.gd praat uitsluitend tegen een `session: SessionInterface`. Offline is
## dat de autoload GameSession (die IS de LocalSession: hij extends deze
## klasse en draait Validator/Reducer in-proces). Online wordt het een
## RemoteSession (F4.3f) die dezelfde submit-signaturen aanbiedt en dezelfde
## signals uitzendt, maar de acties naar de server stuurt en zijn `state`
## herbouwt uit de fog-view. Zo merkt de renderer niets van het verschil.
##
## De signals en `_relay_events` zijn LETTERLIJK uit GameSession verhuisd
## (geen typecoercie erbij: de codec voor JSON-events komt in F4.3d), zodat
## het offline pad byte-identiek blijft. De submit-stubs hieronder zijn de
## volledige set van GameSession; een sessie die iets niet kan (bv. een
## RemoteSession die geen `start_new_game` kent) meldt dat luid.
##
## De haken onderaan (local_player_id, klok, naam_van, pion_gedekt,
## tegenstander_status, is_online) hebben defaults die voor lokaal identiek
## zijn aan wat game.gd altijd al aannam: mens = speler 1, geen klok, de
## tegenstander is de AI.

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
signal doctrines_revealed(doctrines: Dictionary)  # F4.0: beide keuzes tegelijk onthuld

var state: GameState = null


# --- Start ---------------------------------------------------------------

func start_new_game(_doctrine_p1: int = Constants.Doctrine.MENS, _doctrine_p2: int = Constants.Doctrine.MENS, _rules_config: RulesConfig = null) -> void:
	_niet_ondersteund("start_new_game")

func start_new_game_pre_game(_rules_config: RulesConfig = null) -> void:
	_niet_ondersteund("start_new_game_pre_game")

func start_new_game_default(_doctrine_p1: int = Constants.Doctrine.MENS, _doctrine_p2: int = Constants.Doctrine.MENS) -> void:
	_niet_ondersteund("start_new_game_default")


# --- Submits (de volledige set van GameSession) ---------------------------

func submit_choose_doctrine(_player_id: int, _doctrine: int) -> bool:
	return _niet_ondersteund("submit_choose_doctrine")

func submit_placement(_player_id: int, _placements: Array) -> bool:
	return _niet_ondersteund("submit_placement")

func submit_default_placement(_player_id: int) -> bool:
	return _niet_ondersteund("submit_default_placement")

func submit_define_cards(_player_id: int, _cards_data: Array) -> bool:
	return _niet_ondersteund("submit_define_cards")

func submit_ack_reveal(_player_id: int) -> bool:
	return _niet_ondersteund("submit_ack_reveal")

## Compat-shim: bevestigt de reveal voor BEIDE spelers. Alleen zinvol als
## deze sessie beide kanten bijhoudt (offline). Online bestaat dit pad niet.
func acknowledge_reveal() -> void:
	_niet_ondersteund("acknowledge_reveal")

func submit_link(_player_id: int, _card_id: int, _pawn_id: int) -> bool:
	return _niet_ondersteund("submit_link")

func submit_move(_player_id: int, _pawn_id: int, _target_pos: Vector2i) -> bool:
	return _niet_ondersteund("submit_move")

func submit_attack(_player_id: int, _attacker_id: int, _defender_id: int) -> bool:
	return _niet_ondersteund("submit_attack")

func submit_shot(_player_id: int, _shooter_id: int, _target_id: int) -> bool:
	return _niet_ondersteund("submit_shot")

func submit_charge(_player_id: int, _pawn_id: int, _move_target: Vector2i, _defender_id: int) -> bool:
	return _niet_ondersteund("submit_charge")

func submit_wolf_step(_player_id: int, _target: Vector2i) -> bool:
	return _niet_ondersteund("submit_wolf_step")

func submit_resign(_player_id: int) -> bool:
	return _niet_ondersteund("submit_resign")

func submit_spawn(_player_id: int, _spawns: Array) -> bool:
	return _niet_ondersteund("submit_spawn")

func submit_bet_cp(_player_id: int, _amount: int) -> bool:
	return _niet_ondersteund("submit_bet_cp")

func submit_cannon_roll(_player_id: int, _pawn_id: int, _target: Vector2i) -> bool:
	return _niet_ondersteund("submit_cannon_roll")

func submit_cannon_shoot(_player_id: int, _pawn_id: int, _target_id: int) -> bool:
	return _niet_ondersteund("submit_cannon_shoot")

func submit_claim_timeout(_player_id: int, _now_ms: int) -> bool:
	return _niet_ondersteund("submit_claim_timeout")

func skip_wolf_step(_player_id: int) -> bool:
	return _niet_ondersteund("skip_wolf_step")

func get_state() -> GameState:
	return state


# --- Haken (defaults = het offline gedrag van altijd) -----------------------

## Welke kant de mens aan dit scherm speelt. Offline altijd speler 1; online
## de seat van de match (F4.3g draait daar de camera op).
func local_player_id() -> int:
	return Constants.PLAYER_1

## De klok als paar: de deadline uit de staat en, online, de servertijd
## waarmee de client zijn offset kan bepalen (F4.4). -1 = geen servertijd.
func klok() -> Dictionary:
	return {"deadline_ms": state.turn_deadline if state != null else 0, "server_now_ms": -1}

## Naam van een speler zoals de sessie hem kent (online: uit de match).
## Leeg = game.gd valt terug op zijn eigen teksten (jij / AI).
func naam_van(_player_id: int) -> String:
	return ""

## F0.6/F4.3: staat een pion voor MIJ gedekt (Krokodil-schutkleur)? Offline
## exact de expressie die de hp-blokjes altijd al gebruikten; online komt het
## '?'-sentinel uit de view.
func pion_gedekt(pawn_id: int) -> bool:
	if state == null:
		return false
	var pawn: Pawn = state.pawns.get(pawn_id, null)
	if pawn == null:
		return false
	return pawn.owner_id != local_player_id() and not pawn.card_revealed

## Online: {enemy_has_chosen, enemy_has_defined, enemy_has_spawned} uit de
## view, voor de wachtteksten. Offline leeg: de AI dient altijd meteen in.
func tegenstander_status() -> Dictionary:
	return {}

func is_online() -> bool:
	return false


# --- Events -> signals (letterlijk uit GameSession, F0.4a) ------------------

## De reducer-events worden 1-op-1 naar de signals vertaald zodat game.gd
## niets merkt. Geen typecoercie hier: lokaal komen de payloads getypt uit de
## reducer; de JSON-codec voor online events zit in de RemoteSession (F4.3d).
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
			Reducer.EV_DOCTRINES_REVEALED:
				doctrines_revealed.emit(ev.payload.doctrines)


func _niet_ondersteund(naam: String) -> bool:
	push_error("SessionInterface: %s wordt niet ondersteund door deze sessie (%s)" % [naam, get_class()])
	return false
