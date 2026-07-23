class_name Reducer
extends RefCounted

# F0.4a — de reducer: apply(state, action, player_id) -> {ok, events, error}.
# Puur in de afgesproken zin (B2): geen Nodes, geen signals, geen globals,
# deterministisch; muteert de meegegeven state in-place (aanroeper kloont
# indien nodig). Dit deel dekt de ACTIEFASE: MOVE/MELEE/SHOOT/CHARGE/
# WOLF_STEP/SKIP_WOLF_STEP, inclusief beurtwissel en win-check.
#
# Events zijn typed dicts {type, seq, payload}. De GameSession-shim vertaalt
# ze 1-op-1 naar de bestaande signals (game.gd merkt niets); straks schrijft
# het event-log (F0.7) ze weg en streamt de server (F4) ze naar clients.
#
# Nog in de shim (F0.4b): setup-fasen, fasemachine en de cyclus-reset — de
# reducer geeft daarvoor het event CYCLE_RESET terug.

const EV_ACTION := "action_applied"      # {action, result} → action_performed-signal
const EV_STATE := "state_updated"        # {} → state_updated-signal
const EV_WOLF_PENDING := "wolf_step_pending"  # {pawn_id}
const EV_TURN := "turn_changed"          # {player_id}
const EV_PHASE := "phase_changed"        # {new_phase, old_phase}
const EV_GAME_OVER := "game_over"        # {winner}
const EV_CYCLE_RESET := "cycle_reset"    # {} → shim draait _start_new_cycle (tot F0.4b)


static func apply(state: GameState, action: Dictionary, player_id: int) -> Dictionary:
	var verdict: Dictionary = Validator.is_legal(state, action, player_id)
	if not verdict.legal:
		return {"ok": false, "events": [], "error": verdict.reason}
	var events: Array = []
	match String(action.type):
		Actions.MOVE:
			_do_move(state, action, events)
		Actions.MELEE:
			_do_melee(state, action, events)
		Actions.SHOOT:
			_do_shoot(state, action, events)
		Actions.CHARGE:
			_do_charge(state, action, events)
		Actions.WOLF_STEP:
			_do_wolf_step(state, action, events)
		Actions.SKIP_WOLF_STEP:
			_do_skip_wolf(state, events)
		_:
			return {"ok": false, "events": [], "error": "Actietype nog niet in de reducer (F0.4b)"}
	_seq(events)
	return {"ok": true, "events": events, "error": ""}


## Kan de reducer dit actietype al aan? (De shim routeert de rest zelf.)
static func handles(action_type: String) -> bool:
	return action_type in [Actions.MOVE, Actions.MELEE, Actions.SHOOT,
		Actions.CHARGE, Actions.WOLF_STEP, Actions.SKIP_WOLF_STEP]


# =========================================================================
# Acties
# =========================================================================

static func _do_move(state: GameState, action: Dictionary, events: Array) -> void:
	var pawn_id: int = int(action.pawn_id)
	var from_pos: Vector2i = state.pawns[pawn_id].position
	Rules.apply_move(state, pawn_id, action.target)
	# Legacy-vorm van het action_performed-signaal (game.gd matcht hierop).
	_ev(events, EV_ACTION, {
		"action": {"type": "move", "pawn_id": pawn_id, "from": from_pos, "target": action.target},
		"result": {"success": true},
	})
	_post_action(state, events)


static func _do_melee(state: GameState, action: Dictionary, events: Array) -> void:
	var attacker_id: int = int(action.attacker_id)
	var result: Dictionary = Rules.apply_melee(state, attacker_id, int(action.defender_id))
	_ev(events, EV_ACTION, {
		"action": {"type": "attack", "attacker_id": attacker_id, "defender_id": int(action.defender_id)},
		"result": result,
	})
	_after_combat(state, attacker_id, result, events)


static func _do_shoot(state: GameState, action: Dictionary, events: Array) -> void:
	var shooter_id: int = int(action.shooter_id)
	var result: Dictionary = Rules.apply_shot(state, shooter_id, int(action.target_id))
	_ev(events, EV_ACTION, {
		"action": {"type": "shot", "shooter_id": shooter_id, "target_id": int(action.target_id)},
		"result": result,
	})
	_post_action(state, events)


static func _do_charge(state: GameState, action: Dictionary, events: Array) -> void:
	var pawn_id: int = int(action.pawn_id)
	var result: Dictionary = Rules.apply_charge(state, pawn_id, action.move_target, int(action.defender_id))
	_ev(events, EV_ACTION, {
		"action": {"type": "charge", "pawn_id": pawn_id, "move_target": action.move_target,
			"defender_id": int(action.defender_id)},
		"result": result,
	})
	_after_combat(state, pawn_id, result, events)


static func _do_wolf_step(state: GameState, action: Dictionary, events: Array) -> void:
	var pawn_id: int = state.pending_wolf_step_pawn
	var from_pos: Vector2i = state.pawns[pawn_id].position
	Rules.apply_wolf_step(state, pawn_id, action.target)
	state.pending_wolf_step_pawn = -1
	_ev(events, EV_ACTION, {
		"action": {"type": "wolf_step", "pawn_id": pawn_id, "from": from_pos, "target": action.target},
		"result": {"success": true},
	})
	_post_action(state, events)


static func _do_skip_wolf(state: GameState, events: Array) -> void:
	# Geen action_performed-event: het huidige skip-pad emitte dat ook nooit.
	state.pending_wolf_step_pawn = -1
	_post_action(state, events)


# =========================================================================
# Afhandeling na een actie (was: GameSession._post_action/_after_combat/
# _check_action_phase_status)
# =========================================================================

## Na melee/charge: eerst win-check, daarna eventueel de Wolf-stap openzetten.
static func _after_combat(state: GameState, attacker_id: int, result: Dictionary, events: Array) -> void:
	_ev(events, EV_STATE, {})
	if _check_game_over(state, events):
		return
	if result.get("wolf_step_available", false):
		state.pending_wolf_step_pawn = attacker_id
		_ev(events, EV_WOLF_PENDING, {"pawn_id": attacker_id})
		return  # beurt wisselt pas na WOLF_STEP / SKIP_WOLF_STEP
	_advance_turn(state, events)


static func _post_action(state: GameState, events: Array) -> void:
	_ev(events, EV_STATE, {})
	if _check_game_over(state, events):
		return
	_advance_turn(state, events)


static func _check_game_over(state: GameState, events: Array) -> bool:
	var winner: int = Rules.check_win(state)
	if winner == -1:
		return false
	state.winner = winner
	var old: int = state.phase
	state.phase = Phase.Type.GAME_OVER
	_ev(events, EV_PHASE, {"new_phase": Phase.Type.GAME_OVER, "old_phase": old})
	_ev(events, EV_GAME_OVER, {"winner": winner})
	return true


## Beurtwissel: strikte afwisseling waar mogelijk; kan niemand meer iets,
## dan eindigt de cyclus (het CYCLE_RESET-event; de shim reset tot F0.4b).
static func _advance_turn(state: GameState, events: Array) -> void:
	if state.phase != Phase.Type.ACTION:
		return
	var current_can: bool = Rules.can_player_act(state, state.current_player)
	var opponent: int = Constants.opponent(state.current_player)
	var opponent_can: bool = Rules.can_player_act(state, opponent)
	if not current_can and not opponent_can:
		_ev(events, EV_CYCLE_RESET, {})
		return
	if opponent_can:
		state.current_player = opponent
	_ev(events, EV_TURN, {"player_id": state.current_player})


# =========================================================================
# Event-helpers
# =========================================================================

static func _ev(events: Array, type: String, payload: Dictionary) -> void:
	events.append({"type": type, "seq": 0, "payload": payload})


static func _seq(events: Array) -> void:
	for i in events.size():
		events[i].seq = i
