class_name Reducer
extends RefCounted

# F0.4a/b — de reducer: apply(state, action, player_id) -> {ok, events, error}.
# Puur in de afgesproken zin (B2): geen Nodes, geen signals, geen globals,
# deterministisch; muteert de meegegeven state in-place (aanroeper kloont
# indien nodig). Dekt sinds F0.4b de VOLLEDIGE fasemachine: opstelling,
# kaartdefinitie (commit-gate), reveal (per-speler ACK — het single-ack-gat is
# dicht), koppelfase met staartkoppelen, ronde/cyclus-overgangen én de
# actiefase met beurtwissel en win-checks.
#
# Events zijn typed dicts {type, seq, payload}. De GameSession-shim vertaalt
# ze 1-op-1 naar de bestaande signals (game.gd merkt niets); straks schrijft
# het event-log (F0.7) ze weg en streamt de server (F4) ze naar clients.
#
# Sinds F0.4c: RESIGN + cycluslimiet-remise. Sinds F0.8: klokken (now_ms-param).

const EV_ACTION := "action_applied"           # {action, result} → action_performed-signal
const EV_STATE := "state_updated"             # {} → state_updated-signal
const EV_PLACEMENT := "placement_submitted"   # {player_id}
const EV_CARDS_REVEALED := "cards_revealed"   # {totals_p1, totals_p2, winner}
const EV_WOLF_PENDING := "wolf_step_pending"  # {pawn_id}
const EV_TURN := "turn_changed"               # {player_id}
const EV_PHASE := "phase_changed"             # {new_phase, old_phase}
const EV_CYCLE_STARTED := "cycle_started"     # {cycle}
const EV_GAME_OVER := "game_over"             # {winner}


static func apply(state: GameState, action: Dictionary, player_id: int, now_ms: int = -1) -> Dictionary:
	# F1.3: snelle poort (structuur/fase/beurt/eigendom) — de dure legaliteit
	# (paden, doelwitten, charge-kosten) zit al ATOMAIR in Rules.apply_* en
	# wordt daar afgedwongen; dubbel valideren kostte de arena ~30% doorvoer.
	# Validator.is_legal blijft de volledige poort voor tests/tools/UI.
	var gate: Dictionary = Validator.gate_check(state, action, player_id)
	if not gate.legal:
		return {"ok": false, "events": [], "error": gate.reason}
	var was_actiefase: bool = state.phase == Phase.Type.ACTION
	var events: Array = []
	var ok := true
	var fout := ""
	match String(action.type):
		Actions.PLACE:
			_do_place(state, action, player_id, events)
		Actions.DEFINE_CARDS:
			_do_define(state, action, player_id, events)
		Actions.ACK_REVEAL:
			_do_ack_reveal(state, player_id, events)
		Actions.LINK:
			_do_link(state, action, player_id, events)
		Actions.MOVE:
			ok = _do_move(state, action, events)
			fout = "Ongeldige zet"
		Actions.MELEE:
			ok = _do_melee(state, action, events)
			fout = "Ongeldige aanval"
		Actions.SHOOT:
			ok = _do_shoot(state, action, events)
			fout = "Ongeldig schot"
		Actions.CHARGE:
			ok = _do_charge(state, action, events)
			fout = "Ongeldige charge"
		Actions.WOLF_STEP:
			ok = _do_wolf_step(state, action, events)
			fout = "Ongeldige Wolf-stap"
		Actions.SKIP_WOLF_STEP:
			_do_skip_wolf(state, events)
		Actions.RESIGN:
			_do_resign(state, player_id, events)
		Actions.CLAIM_TIMEOUT:
			if now_ms < 0 or not _clocks_on(state) or state.turn_deadline <= 0 or now_ms <= state.turn_deadline:
				return {"ok": false, "events": [], "error": "Deadline nog niet verstreken"}
			_do_claim_timeout(state, player_id, now_ms, events)
		_:
			return {"ok": false, "events": [], "error": "Onbekend actietype"}
	if not ok:
		return {"ok": false, "events": [], "error": fout}
	# F0.8: bankverbruik na een geslaagde actiefase-actie, gemeten tegen de
	# OUDE deadline (die pas in _update_deadline verschuift).
	if now_ms >= 0 and _clocks_on(state) and was_actiefase \
			and state.turn_deadline > 0 and String(action.type) != Actions.CLAIM_TIMEOUT:
		_consume_bank(state, player_id, now_ms)
	if now_ms >= 0:
		_update_deadline(state, now_ms)
	_seq(events)
	return {"ok": true, "events": events, "error": ""}


## De reducer dekt sinds F0.8 de volledige actietaal.
static func handles(action_type: String) -> bool:
	return Actions._FIELDS.has(action_type)


# =========================================================================
# Setup-fasen (F0.4b)
# =========================================================================

static func _do_place(state: GameState, action: Dictionary, player_id: int, events: Array) -> void:
	state.apply_placement(player_id, action.placements)
	_ev(events, EV_PLACEMENT, {"player_id": player_id})
	_ev(events, EV_STATE, {})
	if state.placements_done.get(Constants.PLAYER_1, false) \
			and state.placements_done.get(Constants.PLAYER_2, false):
		_set_phase(state, Phase.Type.SETUP_1_DEFINE, events)
		_ev(events, EV_CYCLE_STARTED, {"cycle": 1})
		_ev(events, EV_STATE, {})
		_check_define_gate(state, events)


static func _do_define(state: GameState, action: Dictionary, player_id: int, events: Array) -> void:
	var new_cards: Array = []
	for d in action.cards:
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
	_ev(events, EV_STATE, {})
	_check_define_gate(state, events)


## Commit-gate (4.1.10-hr): de reveal volgt zodra elke speler die MOET
## definiëren (>= 1 vrije pion) dat gedaan heeft; een uitgedunde speler
## zonder vrije pionnen slaat de ronde over en de ander gaat gewoon door.
static func _check_define_gate(state: GameState, events: Array) -> void:
	if not Phase.is_define(state.phase):
		return
	for speler in [Constants.PLAYER_1, Constants.PLAYER_2]:
		if state.cards_defined.get(speler, []).size() == 0 \
				and Validator.expected_define_count(state, speler) > 0:
			return  # deze speler moet nog
	_enter_reveal(state, events)


static func _enter_reveal(state: GameState, events: Array) -> void:
	state.cards_revealed[Constants.PLAYER_1] = state.cards_defined[Constants.PLAYER_1].duplicate()
	state.cards_revealed[Constants.PLAYER_2] = state.cards_defined[Constants.PLAYER_2].duplicate()
	state.reveal_acks = {Constants.PLAYER_1: false, Constants.PLAYER_2: false}
	_set_phase(state, Phase.reveal_for_round(state.round_number), events)
	# Initiatief is deterministisch; hier alvast berekend voor het reveal-event.
	var init: Dictionary = Rules.compute_initiative(state)
	_ev(events, EV_CARDS_REVEALED, {
		"totals_p1": init.totals_p1,
		"totals_p2": init.totals_p2,
		"winner": init.winner,
	})


## Per-speler ACK (F0.4b-gedragsverbetering): de fase gaat pas door als
## BEIDE spelers bevestigd hebben. compute_initiative is deterministisch,
## dus bij de tweede ack veilig opnieuw te berekenen.
static func _do_ack_reveal(state: GameState, player_id: int, events: Array) -> void:
	state.reveal_acks[player_id] = true
	if not (state.reveal_acks.get(Constants.PLAYER_1, false)
			and state.reveal_acks.get(Constants.PLAYER_2, false)):
		return  # wachten op de ander
	var init: Dictionary = Rules.compute_initiative(state)
	state.initiative_player = init.winner
	state.last_initiative_winner = init.winner
	_begin_linking(state, events)


static func _begin_linking(state: GameState, events: Array) -> void:
	state.current_player = state.initiative_player
	# Heeft de initiatiefhouder zelf geen koppelwerk, dan start de tegenstander
	# (staartkoppelen vanaf de eerste beurt).
	var opponent: int = Constants.opponent(state.initiative_player)
	if not _has_link_work(state, state.current_player) and _has_link_work(state, opponent):
		state.current_player = opponent
	_set_phase(state, Phase.linking_for_round(state.round_number), events)
	_ev(events, EV_TURN, {"player_id": state.current_player})
	_check_linking_complete(state, events)


static func _do_link(state: GameState, action: Dictionary, player_id: int, events: Array) -> void:
	var card: Card = state.all_cards.get(int(action.card_id), null)
	var pawn: Pawn = state.pawns.get(int(action.pawn_id), null)
	var doctrine: Dictionary = state.doctrine_data_of(player_id)
	# Beer: +1 HP buiten het budget (v4.1 §6.4). Speed-bonus buiten het budget:
	# Muis krijgt +1 op elke pion (zwerm-mobiliteit), Vos +1 op cavalerie.
	var speed_bonus: int = int(doctrine.get("speed_bonus", 0))
	if pawn.unit_type == Constants.UnitType.CAVALRY:
		speed_bonus += int(doctrine.cav_speed_bonus)
	pawn.link_card(card, doctrine.hp_bonus, speed_bonus)
	# Vos: de toewijzing is gedekt tot de pion schade toebrengt of ontvangt (§6.6).
	pawn.card_revealed = not doctrine.hidden_link
	_ev(events, EV_STATE, {})
	_advance_linking_turn(state, events)


## Om de beurt koppelen; is één speler klaar, dan koppelt de ander zijn
## resterende kaarten achter elkaar (staartkoppelen, v4.1 §4.3-C-2).
static func _advance_linking_turn(state: GameState, events: Array) -> void:
	if not Phase.is_linking(state.phase):
		return
	var next_player: int = Constants.opponent(state.current_player)
	var next_has_work: bool = _has_link_work(state, next_player)
	var current_has_work: bool = _has_link_work(state, state.current_player)
	if next_has_work:
		state.current_player = next_player
		_ev(events, EV_TURN, {"player_id": state.current_player})
		_check_linking_complete(state, events)
	elif current_has_work:
		_ev(events, EV_TURN, {"player_id": state.current_player})
		_check_linking_complete(state, events)
	else:
		_advance_from_linking(state, events)


static func _check_linking_complete(state: GameState, events: Array) -> void:
	if not Phase.is_linking(state.phase):
		return
	# Klaar zodra geen van beide spelers nog koppelwerk heeft; kaarten zonder
	# geldige pion vervallen gewoon (v4.1 §4.3-C-3).
	if not _has_link_work(state, Constants.PLAYER_1) \
			and not _has_link_work(state, Constants.PLAYER_2):
		_advance_from_linking(state, events)


static func _has_link_work(state: GameState, player_id: int) -> bool:
	var has_unlinked_card := false
	for c in state.cards_revealed[player_id]:
		if not c.is_linked():
			has_unlinked_card = true
			break
	if not has_unlinked_card:
		return false
	for pawn in state.pawns.values():
		if pawn.owner_id == player_id and not pawn.is_eliminated and pawn.linked_card_id == -1:
			return true
	return false


static func _advance_from_linking(state: GameState, events: Array) -> void:
	if state.round_number < state.rules.rounds_per_cycle:
		state.round_number += 1
		state.reset_for_new_round()
		_set_phase(state, Phase.define_for_round(state.round_number), events)
		_check_define_gate(state, events)
	else:
		_enter_action_phase(state, events)


static func _enter_action_phase(state: GameState, events: Array) -> void:
	# De initiatiefhouder van Ronde 3 begint. Kan hij niets, dan de tegenstander;
	# kan niemand iets, dan direct de Resetfase (v4.1 §4.4/4.5).
	state.current_player = state.initiative_player
	_set_phase(state, Phase.Type.ACTION, events)
	var current_can: bool = Rules.can_player_act(state, state.current_player)
	var opponent: int = Constants.opponent(state.current_player)
	var opponent_can: bool = Rules.can_player_act(state, opponent)
	if not current_can and not opponent_can:
		_start_new_cycle(state, events)
		return
	if not current_can:
		state.current_player = opponent
	_ev(events, EV_TURN, {"player_id": state.current_player})


static func _start_new_cycle(state: GameState, events: Array) -> void:
	state.reset_for_new_cycle()
	if _check_game_over(state, events):
		return
	# Cycluslimiet-remise (F0.4c): voorbij de limiet beslist de tiebreak
	# (materiaal → haven → nabijheid; -1 = echte remise). Voorkomt oneindige
	# patstellingen (bv. twee deterministische AI's die elkaar eeuwig ontwijken).
	if state.rules.cycle_limit > 0 and state.cycle > state.rules.cycle_limit:
		state.winner = tiebreak_winner(state)
		_set_phase(state, Phase.Type.GAME_OVER, events)
		_ev(events, EV_GAME_OVER, {"winner": state.winner})
		return
	_set_phase(state, Phase.Type.SETUP_1_DEFINE, events)
	_ev(events, EV_CYCLE_STARTED, {"cycle": state.cycle})
	_ev(events, EV_STATE, {})
	_check_define_gate(state, events)


## RESIGN (F0.4c): opgeven kan in elke speelbare fase; de tegenstander wint.
static func _do_resign(state: GameState, player_id: int, events: Array) -> void:
	state.winner = Constants.opponent(player_id)
	_set_phase(state, Phase.Type.GAME_OVER, events)
	_ev(events, EV_GAME_OVER, {"winner": state.winner})


## Tiebreak bij de cycluslimiet (was: MatchRunner-heuristiek, nu spelregel):
## 1) meeste pionnen over, 2) meeste in de haven, 3) verst opgerukt richting
## de eigen doelhaven. Alles gelijk → -1 (remise).
static func tiebreak_winner(state: GameState) -> int:
	var a1: int = state.get_alive_pawns_for(Constants.PLAYER_1).size()
	var a2: int = state.get_alive_pawns_for(Constants.PLAYER_2).size()
	if a1 != a2:
		return Constants.PLAYER_1 if a1 > a2 else Constants.PLAYER_2
	var h1: int = Rules.count_pawns_in_haven(state, Constants.PLAYER_1)
	var h2: int = Rules.count_pawns_in_haven(state, Constants.PLAYER_2)
	if h1 != h2:
		return Constants.PLAYER_1 if h1 > h2 else Constants.PLAYER_2
	var p1: int = _haven_closeness(state, Constants.PLAYER_1)
	var p2: int = _haven_closeness(state, Constants.PLAYER_2)
	if p1 != p2:
		return Constants.PLAYER_1 if p1 > p2 else Constants.PLAYER_2
	return -1


static func _haven_closeness(state: GameState, side: int) -> int:
	var haven: Array = Constants.get_haven_for_player(side)
	var total: int = 0
	for pawn in state.pawns.values():
		if pawn.owner_id != side or pawn.is_eliminated:
			continue
		var best: int = 999
		for h in haven:
			var d: int = absi(pawn.position.x - h.x) + absi(pawn.position.y - h.y)
			if d < best:
				best = d
		total += Constants.BOARD_SIZE * 2 - best
	return total


# =========================================================================
# Actiefase (F0.4a)
# =========================================================================

static func _do_move(state: GameState, action: Dictionary, events: Array) -> bool:
	var pawn_id: int = int(action.pawn_id)
	var from_pos: Vector2i = state.pawns[pawn_id].position
	if not Rules.apply_move(state, pawn_id, action.target):
		return false
	# Legacy-vorm van het action_performed-signaal (game.gd matcht hierop).
	_ev(events, EV_ACTION, {
		"action": {"type": "move", "pawn_id": pawn_id, "from": from_pos, "target": action.target},
		"result": {"success": true},
	})
	_post_action(state, events)
	return true


static func _do_melee(state: GameState, action: Dictionary, events: Array) -> bool:
	var attacker_id: int = int(action.attacker_id)
	var result: Dictionary = Rules.apply_melee(state, attacker_id, int(action.defender_id))
	if not result.success:
		return false
	_ev(events, EV_ACTION, {
		"action": {"type": "attack", "attacker_id": attacker_id, "defender_id": int(action.defender_id)},
		"result": result,
	})
	_after_combat(state, attacker_id, result, events)
	return true


static func _do_shoot(state: GameState, action: Dictionary, events: Array) -> bool:
	var shooter_id: int = int(action.shooter_id)
	var result: Dictionary = Rules.apply_shot(state, shooter_id, int(action.target_id))
	if not result.success:
		return false
	_ev(events, EV_ACTION, {
		"action": {"type": "shot", "shooter_id": shooter_id, "target_id": int(action.target_id)},
		"result": result,
	})
	_post_action(state, events)
	return true


static func _do_charge(state: GameState, action: Dictionary, events: Array) -> bool:
	var pawn_id: int = int(action.pawn_id)
	var result: Dictionary = Rules.apply_charge(state, pawn_id, action.move_target, int(action.defender_id))
	if not result.success:
		return false
	_ev(events, EV_ACTION, {
		"action": {"type": "charge", "pawn_id": pawn_id, "move_target": action.move_target,
			"defender_id": int(action.defender_id)},
		"result": result,
	})
	_after_combat(state, pawn_id, result, events)
	return true


static func _do_wolf_step(state: GameState, action: Dictionary, events: Array) -> bool:
	var pawn_id: int = state.pending_wolf_step_pawn
	var from_pos: Vector2i = state.pawns[pawn_id].position
	if not Rules.apply_wolf_step(state, pawn_id, action.target):
		return false
	state.pending_wolf_step_pawn = -1
	_ev(events, EV_ACTION, {
		"action": {"type": "wolf_step", "pawn_id": pawn_id, "from": from_pos, "target": action.target},
		"result": {"success": true},
	})
	_post_action(state, events)
	return true


static func _do_skip_wolf(state: GameState, events: Array) -> void:
	# Geen action_performed-event: het oude skip-pad emitte dat ook nooit.
	state.pending_wolf_step_pawn = -1
	_post_action(state, events)


# =========================================================================
# Afhandeling na een actie
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
	_set_phase(state, Phase.Type.GAME_OVER, events)
	_ev(events, EV_GAME_OVER, {"winner": winner})
	return true


## Beurtwissel: strikte afwisseling waar mogelijk; kan niemand meer iets,
## dan eindigt de cyclus (reset + nieuwe setup-ronde, of winst).
static func _advance_turn(state: GameState, events: Array) -> void:
	if state.phase != Phase.Type.ACTION:
		return
	var current_can: bool = Rules.can_player_act(state, state.current_player)
	var opponent: int = Constants.opponent(state.current_player)
	var opponent_can: bool = Rules.can_player_act(state, opponent)
	if not current_can and not opponent_can:
		_start_new_cycle(state, events)
		return
	if opponent_can:
		state.current_player = opponent
	_ev(events, EV_TURN, {"player_id": state.current_player})


# =========================================================================
# Klokken (F0.8) — rules.clock {bank_sec, increment_sec}; bank_sec 0 = uit.
# Model: setup-fasen krijgen increment_sec per beslissing (geen bankverbruik,
# deadline overschreden = defaults); de actiefase krijgt increment + bank
# (tijd voorbij de increment eet de bank op; deadline = bank op = forfeit).
# =========================================================================

static func _clocks_on(state: GameState) -> bool:
	return int(state.rules.clock.get("bank_sec", 0)) > 0


static func _ensure_clocks(state: GameState) -> void:
	if state.clocks.is_empty():
		var bank: int = int(state.rules.clock.get("bank_sec", 0)) * 1000
		state.clocks = {
			Constants.PLAYER_1: {"bank_ms": bank},
			Constants.PLAYER_2: {"bank_ms": bank},
		}


## Tijd voorbij de increment-ruimte gaat van de bank van de acterende speler af.
static func _consume_bank(state: GameState, player_id: int, now_ms: int) -> void:
	_ensure_clocks(state)
	var bank: int = int(state.clocks[player_id].bank_ms)
	var overshoot: int = maxi(0, now_ms - (state.turn_deadline - bank))
	state.clocks[player_id].bank_ms = maxi(0, bank - overshoot)


## Nieuwe deadline na élke geslaagde actie/fase-overgang.
static func _update_deadline(state: GameState, now_ms: int) -> void:
	if not _clocks_on(state):
		return
	_ensure_clocks(state)
	if state.phase == Phase.Type.GAME_OVER:
		state.turn_deadline = 0
		return
	var increment: int = int(state.rules.clock.get("increment_sec", 0)) * 1000
	if state.phase == Phase.Type.ACTION:
		state.turn_deadline = now_ms + increment + int(state.clocks[state.current_player].bank_ms)
	else:
		state.turn_deadline = now_ms + increment


## CLAIM_TIMEOUT (deadline al gevalideerd): setup-fasen krijgen defaults voor
## elke achterblijver; in de actiefase is de bank op en verliest de beurtspeler.
static func _do_claim_timeout(state: GameState, _claimant: int, now_ms: int, events: Array) -> void:
	var ph: int = state.phase
	if ph == Phase.Type.ACTION:
		_ensure_clocks(state)
		state.clocks[state.current_player].bank_ms = 0
		state.winner = Constants.opponent(state.current_player)
		_set_phase(state, Phase.Type.GAME_OVER, events)
		_ev(events, EV_GAME_OVER, {"winner": state.winner})
		return
	if ph == Phase.Type.PLACEMENT:
		for speler in [Constants.PLAYER_1, Constants.PLAYER_2]:
			if not state.placements_done.get(speler, false):
				_merge_sub_apply(state, Actions.make_place(state.default_placement(speler)), speler, now_ms, events)
		return
	if Phase.is_define(ph):
		for speler in [Constants.PLAYER_1, Constants.PLAYER_2]:
			if state.cards_defined.get(speler, []).size() == 0:
				var sets: Array = Validator._sample_card_sets(state, speler)
				if not sets.is_empty():
					_merge_sub_apply(state, Actions.make_define_cards(sets[0]), speler, now_ms, events)
		return
	if Phase.is_reveal(ph):
		for speler in [Constants.PLAYER_1, Constants.PLAYER_2]:
			if not state.reveal_acks.get(speler, false):
				_merge_sub_apply(state, Actions.make_ack_reveal(), speler, now_ms, events)
		return
	if Phase.is_linking(ph):
		# Eén automatische koppeling voor de trage beurtspeler; de deadline
		# verschuift daarna vanzelf (meerdere claims mogelijk).
		var opties: Array = Validator.legal_actions(state, state.current_player)
		if not opties.is_empty():
			_merge_sub_apply(state, opties[0], state.current_player, now_ms, events)


## Sub-actie binnen een timeout-afhandeling: pas toe en neem de events over.
static func _merge_sub_apply(state: GameState, action: Dictionary, player_id: int, now_ms: int, events: Array) -> void:
	var res: Dictionary = apply(state, action, player_id, now_ms)
	if res.ok:
		events.append_array(res.events)


# =========================================================================
# Event-helpers
# =========================================================================

static func _set_phase(state: GameState, new_phase: int, events: Array) -> void:
	var old: int = state.phase
	state.phase = new_phase
	_ev(events, EV_PHASE, {"new_phase": new_phase, "old_phase": old})


static func _ev(events: Array, type: String, payload: Dictionary) -> void:
	events.append({"type": type, "seq": 0, "payload": payload})


static func _seq(events: Array) -> void:
	for i in events.size():
		events[i].seq = i
