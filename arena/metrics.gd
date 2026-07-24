class_name ArenaMetrics
extends RefCounted

# F1.2 — per-game metrics, de letterlijke bouwplan-§8.2-mapping:
# cycli · winnaar+methode (haven/eliminatie/forfeit/remise+tiebreak) ·
# zobrist-herhalingen · kills-op-standbeelden per kaartprofiel (1/5/1-oogst) ·
# schoten per kanon + kanonnen-zonder-schot-% (benadering van "geblokkeerde
# intenties": een kanon dat een hele partij geen schootsveld vindt) ·
# koppelverdeling kaartprofiel→type · verspilde Attack per kill (Leeuw-
# spiraal) · schade-per-actie (Muis) · winmethode per havenvak (hoekfort) ·
# full_state-vlaggen per kant (gedekt-vs-open-ablatie, B8) · remise-trigger.
#
# De collector hangt aan AgentRunner.metrics: before_action ziet de staat
# vóór de klap (voor hp-before/overkill), after_action de events erna.

var track_repetitions: bool = true

var _hashes: Dictionary = {}
var _repetitions: int = 0
var _pending_hp_before: int = 0
var _per_speler: Dictionary = {}
var _statue_kills_by_profile: Dictionary = {}
var _link_matrix: Dictionary = {}
var _cannon_shots: Dictionary = {}  # pion-id -> aantal schoten


func _init() -> void:
	for p in [Constants.PLAYER_1, Constants.PLAYER_2]:
		_per_speler[p] = {
			"actions": 0, "damage": 0, "kills": 0, "overkill": 0,
			"shots": 0, "melees": 0, "charges": 0, "moves": 0, "wolf_steps": 0,
			"spawns": 0, "cp_bet": 0,  # F2.5: v4.2-meetpunten (CHECK-eis)
		}


func before_action(state: GameState, _player: int, actie: Dictionary) -> void:
	_pending_hp_before = 0
	var target_id: int = -1
	match String(actie.type):
		Actions.MELEE:
			target_id = int(actie.defender_id)
		Actions.SHOOT:
			target_id = int(actie.target_id)
		Actions.CHARGE:
			target_id = int(actie.defender_id)
		Actions.CANNON_ACT:
			if String(actie.sub) == "shoot":
				target_id = int(actie.target_id)
	if target_id >= 0:
		var target: Pawn = state.pawns.get(target_id, null)
		if target != null:
			_pending_hp_before = target.current_hp if target.is_active else 0


func after_action(state: GameState, player: int, actie: Dictionary, events: Array) -> void:
	var stats: Dictionary = _per_speler[player]
	var t: String = String(actie.type)
	match t:
		Actions.MOVE:
			stats.actions += 1
			stats.moves += 1
		Actions.WOLF_STEP:
			stats.wolf_steps += 1
		Actions.MELEE, Actions.SHOOT, Actions.CHARGE:
			stats.actions += 1
			if t == Actions.MELEE:
				stats.melees += 1
			elif t == Actions.CHARGE:
				stats.charges += 1
			_verwerk_gevecht(state, player, actie, events)
		Actions.LINK:
			_verwerk_koppeling(state, player, actie)
		Actions.BET_CP:
			_per_speler[player].cp_bet += int(actie.amount)
		Actions.SPAWN:
			# De reveal (bij de laatste commit) draagt de toegekende spawns
			# voor BEIDE spelers; geweigerde spawns tellen bewust niet mee.
			for ev in events:
				if String(ev.type) == Reducer.EV_SPAWNS_REVEALED:
					for pid in [Constants.PLAYER_1, Constants.PLAYER_2]:
						_per_speler[pid].spawns += (ev.payload[str(pid)].spawned as Array).size()
		Actions.CANNON_ACT:
			stats.actions += 1
			if String(actie.sub) == "shoot":
				_verwerk_gevecht(state, player, actie, events)
				stats.shots += 1
				var kanon: Pawn = state.pawns.get(int(actie.pawn_id), null)
				if kanon != null and kanon.unit_type == Constants.UnitType.ARTILLERY:
					_cannon_shots[kanon.id] = int(_cannon_shots.get(kanon.id, 0)) + 1
			else:
				stats.moves += 1
		_:
			pass
	if t == Actions.SHOOT:
		var schutter: Pawn = state.pawns.get(int(actie.shooter_id), null)
		if schutter != null and schutter.unit_type == Constants.UnitType.ARTILLERY:
			_cannon_shots[schutter.id] = int(_cannon_shots.get(schutter.id, 0)) + 1
			stats.shots += 1
		elif schutter != null:
			stats.shots += 1
	if track_repetitions and state.phase == Phase.Type.ACTION:
		var h: String = Zobrist.state_hash(state)
		if _hashes.has(h):
			_repetitions += 1
		_hashes[h] = true


func _verwerk_gevecht(state: GameState, player: int, actie: Dictionary, events: Array) -> void:
	var stats: Dictionary = _per_speler[player]
	for ev in events:
		if String(ev.type) != Reducer.EV_ACTION:
			continue
		var result: Dictionary = ev.payload.result
		var damage: int = int(result.get("damage", 0))
		stats.damage += damage
		if bool(result.get("eliminated", false)):
			stats.kills += 1
			if _pending_hp_before > 0:
				stats.overkill += maxi(0, damage - _pending_hp_before)
			else:
				# Standbeeld-kill (inactief doelwit): registreer het kaartprofiel
				# van de aanvaller (de "1/5/1-oogst"-vraag uit §8.2).
				var aanvaller_id: int = -1
				match String(actie.type):
					Actions.MELEE:
						aanvaller_id = int(actie.attacker_id)
					Actions.SHOOT:
						aanvaller_id = int(actie.shooter_id)
					Actions.CHARGE, Actions.CANNON_ACT:
						aanvaller_id = int(actie.pawn_id)
				var aanvaller: Pawn = state.pawns.get(aanvaller_id, null)
				if aanvaller != null and aanvaller.is_active:
					var profiel := "%d/%d/%d" % [aanvaller.max_hp, aanvaller.max_stamina, aanvaller.attack_value]
					_statue_kills_by_profile[profiel] = int(_statue_kills_by_profile.get(profiel, 0)) + 1


func _verwerk_koppeling(state: GameState, player: int, actie: Dictionary) -> void:
	var card: Card = state.all_cards.get(int(actie.card_id), null)
	var pawn: Pawn = state.pawns.get(int(actie.pawn_id), null)
	if card == null or pawn == null:
		return
	var dominant := "mix"
	if card.hp > card.stamina and card.hp > card.attack:
		dominant = "hp"
	elif card.stamina > card.hp and card.stamina > card.attack:
		dominant = "spd"
	elif card.attack > card.hp and card.attack > card.stamina:
		dominant = "atk"
	var type_naam: String = ["inf", "cav", "art"][pawn.unit_type]
	# Per speler (de aggregatie splitst zo per doctrine, §8.2).
	var sleutel := "p%d_%s_op_%s" % [player, dominant, type_naam]
	_link_matrix[sleutel] = int(_link_matrix.get(sleutel, 0)) + 1


## Sluit af en lever de jsonl-regel (zonder wallclock: reproduceerbaar).
func finalize(runner: AgentRunner, d1: int, d2: int, seed_val: int, agent_labels: Dictionary) -> Dictionary:
	var state: GameState = runner.state()
	var methode := "remise"
	var haven_cells: Array = []
	if runner.winner != -1:
		var verliezer: int = Constants.opponent(runner.winner)
		if Rules.count_pawns_in_haven(state, runner.winner) >= state.rules.pawns_in_haven_to_win:
			methode = "haven"
			var haven: Array = Constants.get_haven_for_player(runner.winner)
			for pawn in state.pawns.values():
				if pawn.owner_id == runner.winner and not pawn.is_eliminated and haven.has(pawn.position):
					haven_cells.append(pawn.position.x)
		elif state.get_alive_pawns_for(verliezer).is_empty():
			methode = "eliminatie"
		else:
			methode = "tiebreak"
	var remise_trigger := ""
	if runner.winner == -1:
		remise_trigger = "cycle_limit" if state.rules.cycle_limit > 0 and state.cycle > state.rules.cycle_limit else "tiebreak_gelijk"
	var kanonnen_totaal: int = 0
	var kanonnen_met_schot: int = _cannon_shots.size()
	var kanon_schoten: int = 0
	for pawn in state.pawns.values():
		if pawn.unit_type == Constants.UnitType.ARTILLERY:
			kanonnen_totaal += 1
	for id in _cannon_shots:
		kanon_schoten += int(_cannon_shots[id])
	var spelers: Dictionary = {}
	for p in [Constants.PLAYER_1, Constants.PLAYER_2]:
		var st: Dictionary = _per_speler[p].duplicate()
		st["schade_per_actie"] = (float(st.damage) / st.actions) if st.actions > 0 else 0.0
		st["overkill_per_kill"] = (float(st.overkill) / st.kills) if st.kills > 0 else 0.0
		st["full_state"] = bool(agent_labels.get("full_state_%d" % p, false))
		spelers[str(p)] = st
	return {
		"seed": seed_val,
		"d1": Constants.doctrine_name(d1),
		"d2": Constants.doctrine_name(d2),
		"agents": {"p1": agent_labels.get("p1", "?"), "p2": agent_labels.get("p2", "?")},
		"winner": runner.winner,
		"methode": methode,
		"remise_trigger": remise_trigger,
		"cycli": state.cycle,
		"steps": runner.steps,
		"illegal": runner.illegal_count,
		"fallback": runner.fallback_count,
		"repetitions": _repetitions,
		"haven_cells": haven_cells,
		"statue_kills_by_profile": _statue_kills_by_profile,
		"link_matrix": _link_matrix,
		"kanonnen": kanonnen_totaal,
		"kanon_schoten": kanon_schoten,
		"kanonnen_zonder_schot_pct": (100.0 * (kanonnen_totaal - kanonnen_met_schot) / kanonnen_totaal) if kanonnen_totaal > 0 else 0.0,
		"spelers": spelers,
	}
