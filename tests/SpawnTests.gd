extends TestSuite

# F2.2 — pools, CYCLE_SPAWN en de blinde SPAWN (v4.2, config-gated door het
# campaign-blok). Dekt de masterplan-CHECK: spawn boven poolsaldo geweigerd,
# spawn op bezet vak geweigerd bij reveal, blinde gelijktijdigheid (view lekt
# niets tot beide binnen zijn), plus pool-init, versie-bump, win op bord+pool
# en de volledige RESET->CYCLE_SPAWN->define-flow.


func _class_name() -> String:
	return "SpawnTests"


## Campagne-staat met 1 zet-bare P1-pion (speed 1) en een P2-standbeeld:
## na de ene MOVE kan niemand iets en eindigt de cyclus.
func _campagne_op_cycluseinde() -> Dictionary:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var mover: Pawn = s._spawn_pawn(1, Vector2i(5, 8))
	var card := Card.new(s.next_card_id(), 1, 1, 3, 1, 1)
	s.all_cards[card.id] = card
	mover.link_card(card)
	s._spawn_pawn(2, Vector2i(5, 1))
	s.init_pools()
	return {"s": s, "mover": mover}


## Direct in de spawn-fase (voor gerichte SPAWN-validatie-tests).
func _spawn_fase_staat() -> GameState:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.phase = Phase.Type.CYCLE_SPAWN
	s.cycle = 2
	s._spawn_pawn(1, Vector2i(5, 8))
	s._spawn_pawn(2, Vector2i(5, 1))
	s.init_pools()
	return s


func test_campaign_blok_bumpt_rules_version() -> void:
	var met := RulesConfig.from_dict({"campaign": {}})
	assert_eq(met.rules_version, "4.2.0", "campaign-activering = 4.2.0")
	assert_true(met.campaign_actief())
	var zonder := RulesConfig.from_dict({})
	assert_eq(zonder.rules_version, "4.1.10-hr", "zonder blok blijft 4.1.x")
	assert_false(zonder.campaign_actief())


func test_campaign_weigert_one_action_stamina() -> void:
	var c := RulesConfig.from_dict({"campaign": {}, "stamina_model": "one_action"})
	assert_eq(c.stamina_model, "pool", "D9: one_action onder campaign teruggezet naar pool")


func test_pool_init_is_3x_comp_per_type() -> void:
	var s := _spawn_fase_staat()
	var comp: Array = s.doctrine_data_of(1).comp
	assert_eq(s.pool_count(1, Constants.UnitType.INFANTRY), int(comp[0]) * 3)
	assert_eq(s.pool_count(1, Constants.UnitType.CAVALRY), int(comp[1]) * 3)
	assert_eq(s.pool_count(1, Constants.UnitType.ARTILLERY), int(comp[2]) * 3)


func test_expliciete_startpool_wint_van_poolfactor() -> void:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {"pools": {"1": {"inf": 2, "cav": 1, "art": 0}}}})
	s.init_pools()
	assert_eq(s.pool_count(1, Constants.UnitType.INFANTRY), 2, "expliciete pool uit het campaign-blok")
	assert_true(s.pool_count(2, Constants.UnitType.INFANTRY) > 2, "P2 zonder expliciete pool valt terug op 3x comp")


func test_spawn_boven_poolsaldo_geweigerd() -> void:
	var s := _spawn_fase_staat()
	s.pools[1] = {"inf": 1, "cav": 0, "art": 0}
	var res: Dictionary = Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(3, 10)},
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(4, 10)},
	]), 1)
	assert_false(res.ok, "2 spawns met saldo 1 moet geweigerd")
	assert_eq(res.error, "Onvoldoende pool-voorraad")


func test_spawn_boven_cap_geweigerd() -> void:
	var s := _spawn_fase_staat()
	var teveel: Array = []
	for x in [1, 2, 3, 4]:
		teveel.append({"type": Constants.UnitType.INFANTRY, "pos": Vector2i(x, 10)})
	var res: Dictionary = Reducer.apply(s, Actions.make_spawn(teveel), 1)
	assert_false(res.ok, "4 spawns boven spawn_max 3")


func test_spawn_buiten_achterste_rij_geweigerd() -> void:
	var s := _spawn_fase_staat()
	var res: Dictionary = Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(5, 9)},
	]), 1)
	assert_false(res.ok, "D6: alleen de eigen achterste rij")
	# P2's achterste rij is rij 0 (gespiegeld).
	var res2: Dictionary = Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(5, 0)},
	]), 2)
	assert_true(res2.ok, "P2 spawnt op rij 0")


func test_bezet_vak_geweigerd_bij_reveal_pion_blijft_in_pool() -> void:
	var s := _spawn_fase_staat()
	s._spawn_pawn(1, Vector2i(5, 10))  # blokkeur op de achterste rij
	var inf_voor: int = s.pool_count(1, Constants.UnitType.INFANTRY)
	var pionnen_voor: int = s.pawns.size()
	# Blinde inzet op het bezette vak is LEGAAL (D6: weigering pas bij reveal).
	var res1: Dictionary = Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(5, 10)},
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(6, 10)},
	]), 1)
	assert_true(res1.ok, "blinde inzet op bezet vak mag (weigering volgt bij reveal)")
	var res2: Dictionary = Reducer.apply(s, Actions.make_spawn([]), 2)
	assert_true(res2.ok)
	# Reveal gebeurd: 1 spawn toegekend, 1 geweigerd.
	assert_eq(s.pawns.size(), pionnen_voor + 1, "alleen de vrije-vak-spawn komt op het bord")
	assert_eq(s.pool_count(1, Constants.UnitType.INFANTRY), inf_voor - 1, "geweigerde spawn blijft in de pool")
	var reveal: Dictionary = {}
	for ev in res2.events:
		if String(ev.type) == Reducer.EV_SPAWNS_REVEALED:
			reveal = ev.payload
	assert_eq(reveal["1"].spawned.size(), 1)
	assert_eq(reveal["1"].geweigerd.size(), 1, "de bezette-vak-spawn staat in de geweigerd-lijst")


func test_blinde_gelijktijdigheid_view_lekt_niets() -> void:
	var s := _spawn_fase_staat()
	var res: Dictionary = Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(7, 10)},
	]), 1)
	assert_true(res.ok)
	assert_eq(s.phase, Phase.Type.CYCLE_SPAWN, "wachten op P2: nog geen reveal")
	assert_eq(s.pawns.size(), 2, "geen pion op het bord voor de reveal")
	# P2's view: WEL dat P1 ingediend heeft, NIET wat.
	var view2: Dictionary = View.for_player(s, 2)
	assert_true(bool(view2.enemy_has_spawned))
	assert_eq((view2.own_spawn_commit as Array).size(), 0)
	assert_false(JSON.stringify(view2).contains("[7,10]"), "de inzet-positie lekt niet naar P2")
	# P1 ziet zijn eigen inzet wel terug.
	var view1: Dictionary = View.for_player(s, 1)
	assert_eq((view1.own_spawn_commit as Array).size(), 1)


func test_vijandelijke_pool_verborgen_in_view() -> void:
	var s := _spawn_fase_staat()
	var view1: Dictionary = View.for_player(s, 1)
	assert_true(view1.pools[str(1)] is Dictionary, "eigen pool zichtbaar")
	assert_eq(view1.pools[str(2)], "?", "D12: vijandelijke pool is het ?-sentinel")
	# Ablatie (full_state) en pool_zichtbaar=true tonen alles.
	var open: Dictionary = View.for_player(s, 1, false)
	assert_true(open.pools[str(2)] is Dictionary)
	s.rules = RulesConfig.from_dict({"campaign": {"pool_zichtbaar": true}})
	var zichtbaar: Dictionary = View.for_player(s, 1)
	assert_true(zichtbaar.pools[str(2)] is Dictionary)


func test_expliciete_startpool_lekt_niet_via_rules() -> void:
	# Review-fix F2.2: view.pools verbergt de vijand-pool, maar het campaign-
	# blok in view.rules droeg een expliciete startpool (F3-pad) integraal mee.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {"pools": {
		"1": {"inf": 5, "cav": 2, "art": 1}, "2": {"inf": 9, "cav": 0, "art": 0}}}})
	s._spawn_pawn(1, Vector2i(5, 8))
	s._spawn_pawn(2, Vector2i(5, 1))
	s.init_pools()
	var view1: Dictionary = View.for_player(s, 1)
	assert_eq(view1.rules.campaign.pools, "?", "expliciete startpool geredigeerd in view.rules")
	assert_eq(view1.pools[str(2)], "?", "en het saldo-sentinel blijft staan")
	# Full-state-ablatie en pool_zichtbaar=true zien hem wel.
	var open: Dictionary = View.for_player(s, 1, false)
	assert_true(open.rules.campaign.pools is Dictionary)
	# De gedeelde cached_dict is NIET gemuteerd door de redactie.
	assert_true(s.rules.cached_dict().campaign.pools is Dictionary, "cached_dict blijft ongeredigeerd")


func test_win_kijkt_naar_bord_plus_pool() -> void:
	var s := _spawn_fase_staat()
	# P2 heeft geen actieve pion op het bord (alleen een standbeeld dat we
	# elimineren), maar wel pool-voorraad: geen eliminatie-winst.
	for pawn in s.pawns.values():
		if pawn.owner_id == 2:
			pawn.is_eliminated = true
	assert_eq(Rules.check_win(s), -1, "pool-voorraad houdt P2 in leven")
	s.pools[2] = {"inf": 0, "cav": 0, "art": 0}
	assert_eq(Rules.check_win(s), Constants.PLAYER_1, "bord en pool leeg -> P1 wint")


func test_flow_reset_spawn_define() -> void:
	var opzet: Dictionary = _campagne_op_cycluseinde()
	var s: GameState = opzet.s
	var res: Dictionary = Reducer.apply(s, Actions.make_move(opzet.mover.id, Vector2i(5, 7)), 1)
	assert_true(res.ok)
	assert_eq(s.phase, Phase.Type.CYCLE_SPAWN, "cycluseinde onder campaign -> spawn-fase")
	assert_eq(s.cycle, 2)
	var admin_gezien := false
	for ev in res.events:
		if String(ev.type) == Reducer.EV_CYCLE_ADMIN:
			admin_gezien = true
	assert_true(admin_gezien, "RESET-fase logt het cycle_admin-ledger-event")
	var pionnen_voor: int = s.pawns.size()
	assert_true(Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.CAVALRY, "pos": Vector2i(2, 10)},
	]), 1).ok)
	assert_true(Reducer.apply(s, Actions.make_spawn([]), 2).ok)
	assert_eq(s.phase, Phase.Type.SETUP_1_DEFINE, "na de reveal beginnen de define-rondes")
	assert_eq(s.pawns.size(), pionnen_voor + 1)
	assert_eq(s.pool_count(1, Constants.UnitType.CAVALRY), int(s.doctrine_data_of(1).comp[1]) * 3 - 1)


func test_zonder_campaign_geen_spawn_fase() -> void:
	var opzet: Dictionary = _campagne_op_cycluseinde()
	var s: GameState = opzet.s
	s.rules = RulesConfig.new()  # campaign weg -> puur 4.1-pad
	s.pools = {}
	var res: Dictionary = Reducer.apply(s, Actions.make_move(opzet.mover.id, Vector2i(5, 7)), 1)
	assert_true(res.ok)
	assert_eq(s.phase, Phase.Type.SETUP_1_DEFINE, "zonder campaign direct naar de define-rondes")


func test_lege_pools_auto_commit() -> void:
	var opzet: Dictionary = _campagne_op_cycluseinde()
	var s: GameState = opzet.s
	s.pools[1] = {"inf": 0, "cav": 0, "art": 0}
	s.pools[2] = {"inf": 0, "cav": 0, "art": 0}
	var res: Dictionary = Reducer.apply(s, Actions.make_move(opzet.mover.id, Vector2i(5, 7)), 1)
	assert_true(res.ok)
	assert_eq(s.phase, Phase.Type.SETUP_1_DEFINE, "beide pools leeg -> auto-commit + direct door (D11)")


func test_spawn_serialisatie_roundtrip() -> void:
	var s := _spawn_fase_staat()
	assert_true(Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(3, 10)},
	]), 1).ok)
	# Mid-gate snapshot (P1 committed, P2 niet): roundtrip moet byte-identiek zijn.
	var d: Dictionary = Serializer.state_to_dict(s)
	var terug: GameState = Serializer.state_from_dict(d)
	assert_eq(JSON.stringify(Serializer.state_to_dict(terug)), JSON.stringify(d), "roundtrip byte-identiek")
	assert_eq(Zobrist.state_hash(terug), Zobrist.state_hash(s))
