class_name ArenaFuzz
extends RefCounted

# F1.4 — fuzz & invarianten als nachtvangnet: L0-vs-L0-partijen (seeded) met
# property-checks per actie. Elke schending levert een repro-bestand in
# results/fuzz/ met seed + config + volledig event-log.
#
# Invarianten (bouwplan §11/F1.4):
#  1. Pionnen ontstaan nooit uit het niets: na de opstelling is de id-set
#     bevroren; geëlimineerd blijft geëlimineerd.
#  2. De HP-som klopt met de events: per gevechtsactie is de totale HP-delta
#     exact damage(actief doelwit) + terugslag.
#  3. Geen actie buiten legal_actions: L0 kiest per constructie uit legal;
#     de runner telt illegale/fallback-keuzes — beide horen 0 te zijn.
#  4. fold(log) == eindstaat: het opgenomen log speelt terug naar exact
#     dezelfde staat (byte-vergelijking, zonder per-actie-hash: snel).
#  5. De view lekt niets (compacte F0.6-canary, gesampled per N acties).
#
# Zelftest ("test de tester"): sabotage=true muteert halverwege stiekem de
# staat; de checks MOETEN dat vangen, anders is het vangnet stuk.


## Draai een fuzz-run. Retourneert {games, violations, repro_paden}.
static func run(games: int, base_seed: int, out_dir: String, sabotage: bool = false) -> Dictionary:
	var doctrines: Array = Constants.DOCTRINE_DATA.keys()
	var violations: int = 0
	var repro_paden: Array = []
	for g in games:
		var seed_val: int = base_seed + g
		var rules := RulesConfig.new()
		rules.cycle_limit = 12
		var d1: int = doctrines[(seed_val * 7) % doctrines.size()]
		var d2: int = doctrines[(seed_val * 13 + 2) % doctrines.size()]
		var runner := AgentRunner.new(AgentL0.new(), AgentL0.new(), d1, d2, seed_val, rules)
		runner.max_steps = 2500
		var log := MatchLog.new()
		log.setup(runner.state(), {"fuzz_seed": seed_val, "sabotage": sabotage})
		var checker := FuzzChecker.new(log, sabotage)
		runner.metrics = checker
		runner.run()
		checker.final_checks(runner)
		if not checker.schendingen.is_empty():
			violations += 1
			if not sabotage and repro_paden.size() < 20:
				var pad := out_dir.path_join("repro_%d.json" % seed_val)
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
				log.meta["schendingen"] = checker.schendingen
				log.save(pad, runner.state())
				repro_paden.append(pad)
	return {"games": games, "violations": violations, "repro_paden": repro_paden}


## Per-actie invarianten-checker; hangt aan AgentRunner.metrics.
class FuzzChecker:
	extends RefCounted

	var schendingen: Array = []
	var _log: MatchLog
	var _sabotage: bool
	var _acties: int = 0
	var _bevroren_ids: Dictionary = {}
	var _ids_bevroren: bool = false
	var _geelimineerd: Dictionary = {}
	var _hp_voor: int = 0
	var _doelwit_actief_voor: bool = false
	var _spook_gespawnd: bool = false
	var _hp_gesaboteerd: bool = false

	func _init(log: MatchLog, sabotage: bool) -> void:
		_log = log
		_sabotage = sabotage

	func before_action(state: GameState, _player: int, actie: Dictionary) -> void:
		var t: String = String(actie.type)
		if t == Actions.MELEE or t == Actions.SHOOT or t == Actions.CHARGE:
			_hp_voor = _som_hp(state)
			var doel_id: int = -1
			match t:
				Actions.MELEE:
					doel_id = int(actie.defender_id)
				Actions.SHOOT:
					doel_id = int(actie.target_id)
				Actions.CHARGE:
					doel_id = int(actie.defender_id)
			var doel: Pawn = state.pawns.get(doel_id, null)
			_doelwit_actief_voor = doel != null and doel.is_active
		else:
			_hp_voor = -1

	func after_action(state: GameState, player: int, actie: Dictionary, events: Array) -> void:
		_acties += 1
		_log.record(player, actie, events, state, false)  # zonder per-actie-hash (snel)
		# Zelftest-sabotage: twee stiekeme mutaties die de checks MOETEN vangen.
		# a) spook-pion (geëlimineerd, raakt gameplay niet) → bevroren-ids-check;
		# b) +1 HP precies op een gevechtsactie → HP-delta-check. Een kale +1 HP
		# op een willekeurig moment is NIET genoeg: de eerstvolgende cyclus-reset
		# wist hem uit voordat fold hem kan zien.
		if _sabotage and _acties >= 40:
			if not _spook_gespawnd:
				var bron: Pawn = state.pawns.values()[0]
				var spook: Pawn = Pawn.from_dict(bron.to_dict())
				spook.id = 9999
				spook.is_eliminated = true
				state.pawns[9999] = spook
				_spook_gespawnd = true
			if not _hp_gesaboteerd and _hp_voor >= 0:
				for pawn in state.pawns.values():
					if not pawn.is_eliminated and pawn.is_active:
						pawn.current_hp += 1  # HP uit het niets
						_hp_gesaboteerd = true
						break
		# 1) Pion-ids bevroren na de opstelling; geëlimineerd blijft geëlimineerd.
		if not _ids_bevroren and state.phase != Phase.Type.PLACEMENT:
			for id in state.pawns:
				_bevroren_ids[id] = true
			_ids_bevroren = true
		elif _ids_bevroren:
			for id in state.pawns:
				if not _bevroren_ids.has(id):
					schendingen.append("actie %d: pion %d ontstond uit het niets" % [_acties, id])
		for id in state.pawns:
			var pawn: Pawn = state.pawns[id]
			if pawn.is_eliminated:
				_geelimineerd[id] = true
			elif _geelimineerd.has(id):
				schendingen.append("actie %d: pion %d stond op uit de dood" % [_acties, id])
		# 2) HP-delta klopt met de events (alleen gevechtsacties). Uitzondering:
		# eindigt de actie de actiefase (cyclus-reset of game-einde), dan
		# unlinkt _start_new_cycle iedereen (HP -> 0) vóórdat de winnaar wordt
		# bepaald — correct gedrag, geen schending. Signaal: CYCLE_STARTED óf
		# een phase_changed wég uit ACTION (game-over kent geen CYCLE_STARTED).
		if _hp_voor >= 0:
			var reset_in_events: bool = false
			var verwacht: int = 0
			for ev in events:
				if String(ev.type) == Reducer.EV_CYCLE_STARTED:
					reset_in_events = true
				elif String(ev.type) == Reducer.EV_PHASE \
						and int(ev.payload.old_phase) == Phase.Type.ACTION:
					reset_in_events = true
				if String(ev.type) != Reducer.EV_ACTION:
					continue
				var result: Dictionary = ev.payload.result
				if _doelwit_actief_voor:
					verwacht += int(result.get("damage", 0))
				if bool(result.get("retaliation", false)):
					verwacht += int(result.get("retaliation_damage", 0))
			if not reset_in_events:
				var delta: int = _hp_voor - _som_hp(state)
				if delta != verwacht:
					schendingen.append("actie %d: HP-delta %d maar events beloven %d" % [_acties, delta, verwacht])
		# 5) View-lek-canary (gesampled: elke 25e actie).
		if _acties % 25 == 0:
			for viewer in [Constants.PLAYER_1, Constants.PLAYER_2]:
				_check_view_lek(state, viewer)

	## Compacte F0.6-canary (de volle versie leeft in tests/ViewTests.gd).
	func _check_view_lek(state: GameState, viewer: int) -> void:
		var enemy: int = Constants.opponent(viewer)
		var view: Dictionary = View.for_player(state, viewer)
		if state.phase == Phase.Type.PLACEMENT:
			for key in view.pawns:
				if int(view.pawns[key].owner_id) == enemy:
					schendingen.append("actie %d: blinde opstelling lekt pion %s" % [_acties, key])
		var revealed_enemy: Dictionary = {}
		for c in state.cards_revealed.get(enemy, []):
			revealed_enemy[c.id] = true
		for c in state.cards_defined.get(enemy, []):
			if not revealed_enemy.has(c.id) and c.linked_pawn_id == -1 and view.cards.has(str(c.id)):
				schendingen.append("actie %d: niet-onthulde kaart %d lekt" % [_acties, c.id])
		for pawn in state.pawns.values():
			if pawn.owner_id != enemy or not pawn.is_active or pawn.card_revealed or pawn.is_eliminated:
				continue
			var pv: Dictionary = view.pawns.get(str(pawn.id), {})
			if not pv.is_empty() and not (pv.current_hp is String):
				schendingen.append("actie %d: gedekte pion %d lekt stats" % [_acties, pawn.id])

	## 3+4) Eind-checks: legale keuzes + fold == eindstaat.
	func final_checks(runner: AgentRunner) -> void:
		if runner.illegal_count > 0:
			schendingen.append("runner telde %d illegale keuzes" % runner.illegal_count)
		if runner.fallback_count > 0:
			schendingen.append("runner telde %d fallback-keuzes (L0 hoort zelf te kiezen)" % runner.fallback_count)
		var uitkomst: Dictionary = MatchLog.fold(_log.meta.initial_state, _log.entries, false)
		if not uitkomst.ok:
			schendingen.append("fold faalde op seq %d: %s" % [int(uitkomst.seq), String(uitkomst.get("fout", "?"))])
			return
		var nagespeeld: String = JSON.stringify(Serializer.state_to_dict(uitkomst.state))
		var echt: String = JSON.stringify(Serializer.state_to_dict(runner.state()))
		if nagespeeld != echt:
			schendingen.append("fold(log) != eindstaat (byte-vergelijking)")

	func _som_hp(state: GameState) -> int:
		var som: int = 0
		for pawn in state.pawns.values():
			som += pawn.current_hp
		return som
