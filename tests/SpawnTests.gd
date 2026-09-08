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
	assert_eq(met.rules_version, "4.3.5", "campaign-activering = 4.3.5 (dynamische trom, ruiter minstens 2/2)")
	assert_true(met.campaign_actief())
	var zonder := RulesConfig.from_dict({})
	assert_eq(zonder.rules_version, "4.3.0", "zonder blok is het de basisversie")
	assert_false(zonder.campaign_actief())


func test_campaign_weigert_one_action_stamina() -> void:
	var c := RulesConfig.from_dict({"campaign": {}, "stamina_model": "one_action"})
	assert_eq(c.stamina_model, "pool", "D9: one_action onder campaign teruggezet naar pool")


func test_pool_init_is_1_5x_comp_per_type() -> void:
	# D5-bijstelling (besluit Max 25 juli): reinforcements = startleger x 1.5.
	var s := _spawn_fase_staat()
	var comp: Array = s.doctrine_data_of(1).comp
	assert_eq(s.pool_count(1, Constants.UnitType.INFANTRY), int(floor(int(comp[0]) * 1.5)))
	assert_eq(s.pool_count(1, Constants.UnitType.CAVALRY), int(floor(int(comp[1]) * 1.5)))
	assert_eq(s.pool_count(1, Constants.UnitType.ARTILLERY), int(floor(int(comp[2]) * 1.5)))


func test_spawn_totaal_max_per_potje() -> void:
	# Besluit Max: max 15 spawns per potje, ongeacht pool of cycli.
	var s := _spawn_fase_staat()
	s.spawn_totaal[1] = 14  # 14 al gedaan dit potje
	assert_eq(s.spawns_over(1), 1)
	var res: Dictionary = Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(3, 10)},
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(4, 10)},
	]), 1)
	assert_false(res.ok, "2 spawns met nog 1 over dit potje")
	assert_eq(res.error, "Spawn-limiet van het potje bereikt")
	assert_true(Reducer.apply(s, Actions.make_spawn([
		{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(3, 10)},
	]), 1).ok, "de laatste toegestane spawn mag nog")
	assert_true(Reducer.apply(s, Actions.make_spawn([]), 2).ok)
	assert_eq(int(s.spawn_totaal[1]), 15, "teller staat op de potje-limiet")
	assert_eq(s.spawns_over(1), 0, "op = op — samples geven alleen nog de lege inzet")
	assert_eq(Validator._sample_spawn_sets(s, 1).size(), 1)


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
	assert_eq(s.pool_count(1, Constants.UnitType.CAVALRY), int(floor(int(s.doctrine_data_of(1).comp[1]) * 1.5)) - 1)


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


func test_lege_pool_verklikt_niet_via_timing() -> void:
	# Review-fix F2.2: auto-commit bij fase-start zou via enemy_has_spawned
	# direct verraden dat de vijandelijke pool leeg is (D12-lek via timing).
	var opzet: Dictionary = _campagne_op_cycluseinde()
	var s: GameState = opzet.s
	s.pools[2] = {"inf": 0, "cav": 0, "art": 0}
	assert_true(Reducer.apply(s, Actions.make_move(opzet.mover.id, Vector2i(5, 7)), 1).ok)
	assert_eq(s.phase, Phase.Type.CYCLE_SPAWN, "fase wacht op P1 (met voorraad)")
	var view1: Dictionary = View.for_player(s, 1)
	assert_false(bool(view1.enemy_has_spawned), "lege P2-pool lekt niet via een instant-commit")
	# Zodra P1 indient rondt de gate af (P2 auto-leeg) en volgt de reveal.
	assert_true(Reducer.apply(s, Actions.make_spawn([]), 1).ok)
	assert_eq(s.phase, Phase.Type.SETUP_1_DEFINE)


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


func test_c11_punten_pool_spawnkosten() -> void:
	# C11 (besluit Max, 27 juli): reserve = puntenpot; soldaat 1 / ruiter 2 /
	# kanon 3. Typed pools uit de (nog typed) campagnelaag -> waarde.
	var rules := RulesConfig.from_dict({"campaign": {
		"pool_model": "punten",
		"pools": {"1": 5, "2": {"inf": 2, "cav": 1, "art": 1}},
	}})
	var s := GameState.new()
	s.rules = rules
	s.doctrines[1] = Constants.Doctrine.MENS
	s.doctrines[2] = Constants.Doctrine.MENS
	s.init_pools()
	assert_eq(s.pool_total(1), 5, "expliciete puntenpot")
	assert_eq(s.pool_total(2), 7, "typed pool op waarde: 2x1 + 1x2 + 1x3")
	assert_eq(s.pool_count(1, Constants.UnitType.ARTILLERY), 1, "5 pt = 1 kanon")
	assert_eq(s.pool_count(1, Constants.UnitType.CAVALRY), 2, "5 pt = 2 ruiters")
	s.pool_take(1, Constants.UnitType.ARTILLERY)
	assert_eq(s.pool_total(1), 2, "kanon kost 3 punten")
	assert_eq(s.pool_count(1, Constants.UnitType.ARTILLERY), 0, "2 pt = geen kanon meer")
	s.pool_take(1, Constants.UnitType.CAVALRY)
	assert_eq(s.pool_total(1), 0, "ruiter kost 2 punten")
	# Zonder pool_model blijft alles byte-identiek typed (compat goldens).
	var oud := GameState.new()
	oud.rules = RulesConfig.from_dict({"campaign": {"pools": {"1": {"inf": 3, "cav": 0, "art": 0}}}})
	oud.doctrines[1] = Constants.Doctrine.MENS
	oud.doctrines[2] = Constants.Doctrine.MENS
	oud.init_pools()
	assert_eq(oud.pool_count(1, Constants.UnitType.INFANTRY), 3, "oud model onaangetast")


func test_c11_geen_type_buiten_de_doctrine() -> void:
	# BUGFIX (Max, 28 juli): het punten-model bepaalt HOEVEEL je koopt, niet
	# WAT. Een Muis (comp 18/4/0) mag dus nooit een kanon spawnen.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {"pool_model": "punten", "pools": {"1": 30, "2": 30}}})
	s.doctrines[1] = Constants.Doctrine.MUIS
	s.doctrines[2] = Constants.Doctrine.MENS
	s.init_pools()
	assert_false(s.kent_type(1, Constants.UnitType.ARTILLERY), "Muis kent geen artillerie")
	assert_eq(s.pool_count(1, Constants.UnitType.ARTILLERY), 0, "dus geen kanon te koop")
	assert_true(s.pool_count(1, Constants.UnitType.INFANTRY) > 0, "soldaten wel")
	assert_true(s.kent_type(2, Constants.UnitType.ARTILLERY), "Varken kent wel artillerie")
	s.phase = Phase.Type.CYCLE_SPAWN
	var achterste: int = Constants.get_start_rows_for_player(1)[0]
	var kanon := Actions.make_spawn([{"type": Constants.UnitType.ARTILLERY, "pos": Vector2i(5, achterste)}])
	assert_false(Validator.is_legal(s, kanon, 1).legal, "kanon spawnen als Muis geweigerd")
	var soldaat := Actions.make_spawn([{"type": Constants.UnitType.INFANTRY, "pos": Vector2i(5, achterste)}])
	assert_true(Validator.is_legal(s, soldaat, 1).legal, "soldaat spawnen mag wel")


func test_punten_pool_overleeft_serialisatie() -> void:
	# REGRESSIE (30 juli): Serializer.from_dict las alleen inf/cav/art terug.
	# In de punten-economie heet de reserve "pt", dus elke replay/fold verloor
	# hem stil -- zobrist hasht de pools niet, dus geen golden merkte het.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {
		"pool_model": "punten", "punten_start": 9,
	}})
	s.doctrines[1] = Constants.Doctrine.MENS
	s.doctrines[2] = Constants.Doctrine.MENS
	s.init_pools()
	assert_eq(s.pool_total(1), 9, "vaste startreserve")
	var terug: GameState = Serializer.state_from_dict(Serializer.state_to_dict(s))
	assert_eq(terug.pool_total(1), 9, "puntenreserve overleeft de roundtrip")
	assert_eq(terug.pool_count(1, Constants.UnitType.ARTILLERY), 3, "9 pt = 3 kanonnen")


func test_agent_ziet_eigen_puntenreserve() -> void:
	# REGRESSIE (30 juli): agents/agent.gd bouwde de pools typed op, zag dus 0
	# punten en spawnde nooit. Dat kostte twee trainingsnachten: 3240 partijen
	# met 0 spawns, terwijl de nacht van 24 juli er nog 36 per partij had.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {
		"pool_model": "punten", "punten_start": 7,
	}})
	s.doctrines[1] = Constants.Doctrine.MUIS
	s.doctrines[2] = Constants.Doctrine.MENS
	s.setup_initial_pawns()
	var view: Dictionary = View.for_player(s, 1)
	var her: GameState = Agent.reconstruct_state(view)
	assert_eq(her.pool_total(1), 7, "agent ziet zijn eigen puntenreserve")
	assert_eq(her.pool_count(1, Constants.UnitType.INFANTRY), 7, "7 pt = 7 soldaten")


func test_c15_buit_vaandel_en_tamboer() -> void:
	# C15 (besluit Max, 30 juli): een vaandeldrager levert 2 versterkingspunten
	# op, een tamboer 2 CP; sinds 4.3.4 (8 september) 4 CP, want er is er nog een.
	# 4.3.2 (besluit Max, 7 september): GEKOPPELD OF NIET MAAKT NIET UIT. Tot dan
	# leverde een gekoppelde drager niets op ("vaandel opgeborgen"), maar dat was
	# een regel die je aan het bord niet kon zien: de koppeling is geheim tot de
	# onthulling, dus je wist niet OF je drager iets waard was.
	# punten_start 0 = knop UIT (dan rekent poolfactor x comp), dus we zetten een
	# expliciet lege pool om de buit zuiver te kunnen meten.
	var rules := RulesConfig.from_dict({"campaign": {
		"pool_model": "punten", "pools": {"1": 0, "2": 0}, "cp_start": 0,
	}})
	var s := GameState.new()
	s.rules = rules
	s.doctrines[1] = Constants.Doctrine.MENS
	s.doctrines[2] = Constants.Doctrine.MENS
	s.init_pools()
	assert_eq(s.pool_total(1), 0, "lege reserve als startpunt")
	assert_eq(int(s.cp.get(1, 0)), 0, "leeg CP-saldo als startpunt")
	# Vaandeldrager van speler 2, ongekoppeld (standbeeld).
	var drager := s._spawn_pawn(2, Vector2i(5, 5), Constants.UnitType.INFANTRY)
	drager.rol = "flag"
	var aanvaller := s._spawn_pawn(1, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	aanvaller.link_card(Card.new(0, 1, 0, 1, 3, 2))
	var res: Dictionary = Rules.apply_melee(s, aanvaller.id, drager.id)
	assert_true(bool(res.success), "melee lukt")
	assert_true(bool(res.eliminated), "standbeeld sneuvelt")
	assert_eq(int(res.get("buit_pt", 0)), 2, "vaandel = 2 punten in het resultaat")
	assert_eq(s.pool_total(1), 2, "punten bijgeschreven op de reserve")
	# Tamboer: 4 CP (4.3.4, was 2: met een tamboer per leger telt hij dubbel).
	var tamboer := s._spawn_pawn(2, Vector2i(6, 5), Constants.UnitType.INFANTRY)
	tamboer.rol = "drum"
	var a2 := s._spawn_pawn(1, Vector2i(6, 4), Constants.UnitType.INFANTRY)
	a2.link_card(Card.new(1, 1, 0, 1, 3, 2))
	var res2: Dictionary = Rules.apply_melee(s, a2.id, tamboer.id)
	assert_eq(int(res2.get("buit_cp", 0)), 4, "tamboer = 4 CP in het resultaat")
	assert_eq(int(s.cp.get(1, 0)), 4, "CP bijgeschreven")
	# GEKOPPELDE drager levert sinds 4.3.2 EVENVEEL op.
	var drager3 := s._spawn_pawn(2, Vector2i(7, 5), Constants.UnitType.INFANTRY)
	drager3.rol = "flag"
	drager3.link_card(Card.new(2, 2, 0, 1, 3, 1))
	var a3 := s._spawn_pawn(1, Vector2i(7, 4), Constants.UnitType.INFANTRY)
	a3.link_card(Card.new(3, 1, 0, 1, 3, 5))
	var res3: Dictionary = Rules.apply_melee(s, a3.id, drager3.id)
	assert_true(bool(res3.eliminated), "gekoppelde drager sneuvelt ook")
	assert_eq(int(res3.get("buit_pt", 0)), 2, "en levert nu OOK 2 punten op (4.3.2)")
	assert_eq(s.pool_total(1), 4, "reserve loopt door naar 4")
	# Een pion ZONDER rol levert nooit iets op, gekoppeld of niet.
	var gewoon := s._spawn_pawn(2, Vector2i(8, 5), Constants.UnitType.INFANTRY)
	var a4 := s._spawn_pawn(1, Vector2i(8, 4), Constants.UnitType.INFANTRY)
	a4.link_card(Card.new(4, 1, 0, 1, 3, 5))
	var res4: Dictionary = Rules.apply_melee(s, a4.id, gewoon.id)
	assert_true(bool(res4.eliminated), "gewone soldaat sneuvelt")
	assert_eq(int(res4.get("buit_pt", 0)), 0, "zonder rol geen buit")
	assert_eq(s.pool_total(1), 4, "reserve onveranderd")


func test_c15_rol_overleeft_koppelen_en_serialisatie() -> void:
	# Max: "als je een mannetje koppelt onthoudt de game dat dit origineel de
	# vaandeldrager was, en als hij weer ontkoppelt heeft hij weer de vaandel."
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.doctrines[1] = Constants.Doctrine.MENS
	s.doctrines[2] = Constants.Doctrine.MENS
	var pion := s._spawn_pawn(1, Vector2i(3, 9), Constants.UnitType.INFANTRY)
	pion.rol = "flag"
	pion.link_card(Card.new(0, 1, 0, 2, 2, 1))
	assert_eq(pion.rol, "flag", "rol blijft bij het koppelen")
	pion.unlink()
	assert_eq(pion.rol, "flag", "en na ontkoppelen draagt hij hetzelfde vaandel")
	var terug: GameState = Serializer.state_from_dict(Serializer.state_to_dict(s))
	assert_eq(String((terug.pawns[pion.id] as Pawn).rol), "flag", "rol overleeft de roundtrip")


func test_c15_opstelling_grenzen() -> void:
	# Niet meer rollen dan toegestaan, niet op ruiters/kanonnen, en zonder
	# campagne-blok bestaan ze niet.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {"vaandels_max": 1, "tamboers_max": 1}})
	s.doctrines[1] = Constants.Doctrine.MUIS
	s.doctrines[2] = Constants.Doctrine.MUIS
	var basis: Array = s.default_placement(1)
	var vlaggen := 0
	var trommels := 0
	for e in basis:
		match String(e.get("rol", "")):
			"flag": vlaggen += 1
			"drum": trommels += 1
	assert_eq(vlaggen, 1, "standaard-opstelling houdt zich aan vaandels_max")
	assert_eq(trommels, 1, "en aan tamboers_max")
	assert_true(s.is_valid_placement(1, basis), "eigen standaard is legaal")
	# Te veel vaandels: geweigerd.
	var teveel: Array = []
	for e in basis:
		var kopie: Dictionary = (e as Dictionary).duplicate()
		if int(kopie.get("type", 0)) == Constants.UnitType.INFANTRY:
			kopie["rol"] = "flag"
		teveel.append(kopie)
	assert_false(s.is_valid_placement(1, teveel), "meer vaandels dan toegestaan wordt geweigerd")
	# Zonder campagne: geen rollen.
	var s2 := GameState.new()
	s2.rules = RulesConfig.new()
	s2.doctrines[1] = Constants.Doctrine.MUIS
	s2.doctrines[2] = Constants.Doctrine.MUIS
	var vlak: Array = s2.default_placement(1)
	for e in vlak:
		assert_eq(String(e.get("rol", "")), "", "4.1 kent geen figurant-rollen")
	var met_rol: Array = []
	for e in vlak:
		var k2: Dictionary = (e as Dictionary).duplicate()
		if int(k2.get("type", 0)) == Constants.UnitType.INFANTRY and met_rol.is_empty():
			k2["rol"] = "flag"
		met_rol.append(k2)
	assert_false(s2.is_valid_placement(1, met_rol), "rol zonder campagne-blok wordt geweigerd")


func test_c16_reserve_per_factie() -> void:
	# C16 (besluit Max, 30 juli): "de muis heeft dan bijv 12 tov de leeuw 7".
	var rules := RulesConfig.from_dict({"campaign": {
		"pool_model": "punten", "punten_start": 10,
		"punten_start_factie": {"1": 12, "2": 7},
	}})
	var s := GameState.new()
	s.rules = rules
	s.doctrines[1] = Constants.Doctrine.MUIS
	s.doctrines[2] = Constants.Doctrine.LEEUW
	s.init_pools()
	assert_eq(s.pool_total(1), 12, "muis krijgt 12 punten")
	assert_eq(s.pool_total(2), 7, "leeuw krijgt 7 punten")
	# Factie zonder eigen regel valt terug op punten_start.
	var s2 := GameState.new()
	s2.rules = rules
	s2.doctrines[1] = Constants.Doctrine.BEER
	s2.doctrines[2] = Constants.Doctrine.WOLF
	s2.init_pools()
	assert_eq(s2.pool_total(1), 10, "beer valt terug op de vaste waarde")


func test_c15_opstelling_telt_dragers_mee() -> void:
	# REGRESSIE (Max, 30 juli): de handmatige opstelling vulde na de dragers nog
	# eens de VOLLE infanterie aan. De opstelling kwam dan 4 pionnen te hoog uit,
	# de engine keurde hem af en de partij bleef in de opstelfase hangen -- dus
	# geen koppel-fase en geen gloeiende ring bij het hoveren.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {"vaandels_max": 2, "tamboers_max": 2}})
	s.doctrines[1] = Constants.Doctrine.MUIS
	s.doctrines[2] = Constants.Doctrine.MUIS
	var comp: Array = s.doctrine_data_of(1).comp
	var opstelling: Array = s.default_placement(1)
	assert_eq(opstelling.size(), int(comp[0]) + int(comp[1]) + int(comp[2]),
		"de opstelling heeft exact de doctrine-samenstelling")
	var inf := 0
	var dragers := 0
	for e in opstelling:
		if int(e.get("type", 0)) == Constants.UnitType.INFANTRY:
			inf += 1
			if String(e.get("rol", "")) != "":
				dragers += 1
	assert_eq(inf, int(comp[0]), "dragers tellen mee als infanterie, niet extra")
	assert_eq(dragers, 4, "twee vaandels en twee tamboers")
	assert_true(s.is_valid_placement(1, opstelling), "en de engine keurt hem goed")


func test_c17_een_economie_campagne_en_potje() -> void:
	# C17 (besluit Max, 31 juli): "het moet allemaal 1 lijn zijn". De
	# startreserve komt uit DEZELFDE formule als de campagnelaag; een los potje
	# is die formule maal potje_factor. Geen tweede economie meer.
	var camp := RulesConfig.from_dict({"campaign": {
		"pool_model": "punten", "start_poolfactor": 0.5, "potje_factor": 1.0,
		"cp_start": 10, "budget_bonus": {"1": {"pt": 4, "cp": 0}},
	}})
	var s := GameState.new()
	s.rules = camp
	s.doctrines[1] = Constants.Doctrine.MUIS      # comp 18/4/0
	s.doctrines[2] = Constants.Doctrine.MENS      # comp 13/6/3
	s.init_pools()
	# Muis: floor(18*0.5)=9 inf x1 + floor(4*0.5)=2 cav x2 = 13, +4 bonus = 17
	assert_eq(s.pool_total(1), 17, "muis krijgt de campagne-reserve inclusief bonus")
	# Varken: 6x1 + 3x2 + 1x3 = 15, geen bonus
	assert_eq(s.pool_total(2), 15, "varken krijgt de kale campagne-reserve")
	assert_eq(int(s.cp.get(1, 0)), 10, "CP uit dezelfde bron")
	# Los potje: exact dezelfde formule, kleinere pot.
	var potje := RulesConfig.from_dict({"campaign": {
		"pool_model": "punten", "start_poolfactor": 0.5, "potje_factor": 0.35,
		"cp_start": 10, "budget_bonus": {"1": {"pt": 4, "cp": 0}},
	}})
	var s2 := GameState.new()
	s2.rules = potje
	s2.doctrines[1] = Constants.Doctrine.MUIS
	s2.doctrines[2] = Constants.Doctrine.MENS
	s2.init_pools()
	assert_eq(s2.pool_total(1), 6, "muis in een los potje: 17 x 0,35 afgerond")
	assert_eq(s2.pool_total(2), 5, "varken in een los potje: 15 x 0,35 afgerond")
	assert_eq(int(s2.cp.get(1, 0)), 4, "en de CP schaalt mee")
	# Zonder campagne-blok bestaat de economie niet (4.1 blijft ongemoeid).
	var kaal := GameState.new()
	kaal.rules = RulesConfig.new()
	kaal.doctrines[1] = Constants.Doctrine.MUIS
	kaal.doctrines[2] = Constants.Doctrine.MENS
	kaal.init_pools()
	assert_eq(kaal.pool_total(1), 0, "4.1 kent geen reserve")


# =========================================================================
# C21 (7 september 2026): aura van tamboer en vaandel. "Zo dwingen we de
# spelers om ze ook echt daadwerkelijk te gebruiken."
# =========================================================================

func _c21_staat() -> GameState:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MENS
	s.doctrines[Constants.PLAYER_2] = Constants.Doctrine.MENS
	return s


func _c21_actief(s: GameState, owner: int, pos: Vector2i, hp: int, spd: int, atk: int) -> Pawn:
	var p: Pawn = s._spawn_pawn(owner, pos, Constants.UnitType.INFANTRY)
	p.link_card(Card.new(s.next_card_id(), owner, 0, hp, spd, atk))
	return p


func test_c21_vaandel_aura_geeft_attack() -> void:
	var s := _c21_staat()
	assert_eq(s.rules.rules_version, "4.3.5", "de aura is een regelwijziging (4.3.3); 4.3.4 en 4.3.5 kwamen erachteraan")
	var aanvaller: Pawn = _c21_actief(s, 1, Vector2i(5, 5), 3, 3, 1)
	var vaandel: Pawn = s._spawn_pawn(1, Vector2i(4, 4), Constants.UnitType.INFANTRY)
	vaandel.rol = "flag"   # diagonaal: hoort bij het blok van acht
	var doel: Pawn = _c21_actief(s, 2, Vector2i(5, 4), 2, 2, 1)
	assert_eq(Rules.effectieve_attack(s, aanvaller), 2, "+1 attack in de vorm om het eigen vaandel")
	assert_eq(aanvaller.attack_value, 1, "de kaartwaarde zelf blijft staan")
	assert_eq(Rules.effectieve_attack(s, vaandel), 0, "de drager buft zichzelf niet")
	var res: Dictionary = Rules.apply_melee(s, aanvaller.id, doel.id)
	assert_eq(int(res.damage), 2, "melee slaat met de aura")
	assert_true(bool(res.eliminated), "2 schade op 2 HP")
	# Buiten het blok (afstand 2 in een richting): niets.
	var ver: Pawn = _c21_actief(s, 1, Vector2i(6, 6), 3, 3, 1)
	assert_eq(Rules.effectieve_attack(s, ver), 1, "afstand 2 valt buiten de vorm")
	# Andermans vaandel doet niets; de trom geeft geen attack.
	var vijand: Pawn = _c21_actief(s, 2, Vector2i(3, 4), 3, 3, 1)
	assert_eq(Rules.effectieve_attack(s, vijand), 1, "andermans vaandel doet niets")
	var trom: Pawn = s._spawn_pawn(1, Vector2i(7, 7), Constants.UnitType.INFANTRY)
	trom.rol = "drum"
	assert_eq(Rules.effectieve_attack(s, ver), 1, "de trom geeft geen attack")
	# Schieten gaat ook met de aura.
	var schutter: Pawn = _c21_actief(s, 1, Vector2i(3, 5), 3, 3, 2)
	assert_eq(Rules.shot_damage(s, schutter), 3, "een schot vanuit de vorm is ook +1")
	# Twee vaandels stapelen niet.
	var vaandel2: Pawn = s._spawn_pawn(1, Vector2i(2, 6), Constants.UnitType.INFANTRY)
	vaandel2.rol = "flag"
	assert_eq(Rules.effectieve_attack(s, schutter), 3, "twee vaandels stapelen niet")
	# Een gekoppelde drager buft ook (4.3.2-lijn); een dode niet.
	vaandel.link_card(Card.new(s.next_card_id(), 1, 0, 2, 2, 1))
	assert_eq(Rules.effectieve_attack(s, aanvaller), 2, "gekoppeld vaandel buft nog steeds (aanvaller staat na de kill op 5,4)")
	s.remove_pawn(vaandel)
	assert_eq(Rules.effectieve_attack(s, aanvaller), 1, "een dood vaandel buft niet")
	# Knop uit.
	s.rules.campaign["aura_vaandel_attack"] = 0
	assert_eq(Rules.effectieve_attack(s, schutter), 2, "aura_vaandel_attack 0 = uit")
	# Zonder campagne-blok bestaat de aura niet.
	var kaal := GameState.new()
	var a41: Pawn = _c21_actief(kaal, 1, Vector2i(5, 5), 3, 3, 1)
	var v41: Pawn = kaal._spawn_pawn(1, Vector2i(5, 6), Constants.UnitType.INFANTRY)
	v41.rol = "flag"
	assert_eq(Rules.effectieve_attack(kaal, a41), 1, "4.1: geen aura")


func test_c21_trom_bonus_is_dynamisch() -> void:
	# 4.3.5 (Max, 8 september): de trom-bonus is een extra stamina-punt dat je
	# een keer per cyclus mag gebruiken, alleen op het moment dat je in de
	# vorm staat. Weg als de trom wegloopt of jij eruit stapt voordat je hem
	# gebruikte; terug als je erin stapt en hem nog niet gebruikte.
	var s := _c21_staat()
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var trom: Pawn = _c21_actief(s, 1, Vector2i(5, 9), 2, 4, 1)
	trom.rol = "drum"
	var naast: Pawn = _c21_actief(s, 1, Vector2i(6, 10), 2, 2, 1)   # diagonaal: in de vorm
	var ver: Pawn = _c21_actief(s, 1, Vector2i(9, 9), 2, 2, 1)     # buiten de vorm
	s._spawn_pawn(2, Vector2i(5, 0), Constants.UnitType.INFANTRY)
	# In de vorm: een punt extra beschikbaar, ook in het loopbereik en de zetten.
	assert_eq(Rules.stamina_beschikbaar(s, naast), 3, "2 van de kaart + 1 van de trom")
	assert_eq(naast.remaining_stamina, 2, "de eigen voorraad zelf blijft 2")
	assert_eq(Rules.move_range(s, naast), 3, "loopbereik telt de bonus mee")
	assert_eq(Rules.stamina_beschikbaar(s, ver), 2, "buiten de vorm: alleen de kaart")
	assert_true(Validator.is_legal(s, Actions.make_move(naast.id, Vector2i(9, 10)), 1).legal, "drie stappen mag met de bonus")
	assert_false(Validator.is_legal(s, Actions.make_move(ver.id, Vector2i(9, 6)), 1).legal, "zonder trom geen drie stappen")
	# Eruit stappen betaalt EERST de trom: eigen voorraad blijft heel, bonus op.
	assert_true(Rules.apply_move(s, naast.id, Vector2i(7, 10)), "een stap de vorm uit")
	assert_eq(naast.remaining_stamina, 2, "de stap kwam van de trom")
	assert_true(naast.trom_gebruikt, "en die is nu op")
	assert_eq(Rules.stamina_beschikbaar(s, naast), 2, "buiten de vorm: geen bonus meer")
	# Terug de vorm in: de bonus is gebruikt, dus niets extra.
	assert_true(Rules.apply_move(s, naast.id, Vector2i(6, 10)))
	assert_eq(naast.remaining_stamina, 1, "deze stap kostte een eigen punt")
	assert_eq(Rules.stamina_beschikbaar(s, naast), 1, "bonus al gebruikt, niet nog een keer")
	# De trom loopt naar `ver` toe: die krijgt de bonus (nog niet gebruikt)...
	assert_true(Rules.apply_move(s, trom.id, Vector2i(8, 9)), "de tamboer loopt drie vakken")
	assert_eq(Rules.stamina_beschikbaar(s, ver), 3, "de trom kwam naast hem staan")
	assert_false(ver.trom_gebruikt)
	# ...en verliest hem weer als de trom doorloopt.
	assert_true(Rules.apply_move(s, trom.id, Vector2i(7, 9)), "en nog een vak verder")
	assert_eq(Rules.stamina_beschikbaar(s, ver), 2, "de trom is weg, de bonus ook")
	assert_false(ver.trom_gebruikt, "nooit gebruikt, dus later nog te krijgen")
	# De tamboer zelf krijgt niets van zijn eigen trom.
	assert_eq(Rules.stamina_beschikbaar(s, trom), 0, "vier stappen gelopen, eigen trom telt niet")
	# Nul eigen stamina maar in de vorm: nog een actie, en daarna echt niets.
	var leeg: Pawn = _c21_actief(s, 1, Vector2i(6, 8), 2, 1, 3)   # naast de trom op (7,9)
	leeg.remaining_stamina = 0
	var doel: Pawn = s._spawn_pawn(2, Vector2i(6, 7), Constants.UnitType.INFANTRY)
	assert_true(Rules.can_pawn_act(s, leeg.id), "met alleen de trom kun je nog handelen")
	var res: Dictionary = Rules.apply_melee(s, leeg.id, doel.id)
	assert_true(bool(res.success) and bool(res.eliminated), "de melee lukt op de trom")
	assert_true(leeg.trom_gebruikt)
	assert_false(Rules.can_pawn_act(s, leeg.id), "daarna is het echt op")
	# Volgende cyclus: (ont)koppelen zet de bonus terug.
	leeg.unlink()
	assert_false(leeg.trom_gebruikt, "ontkoppelen wist het gebruik")
	naast.link_card(Card.new(s.next_card_id(), 1, 0, 2, 2, 1))
	assert_false(naast.trom_gebruikt, "koppelen ook")
	# Het gebruik reist mee in de staat (replay, view, hash).
	naast.trom_gebruikt = true
	var terug: GameState = Serializer.state_from_dict(Serializer.state_to_dict(s))
	assert_true((terug.pawns[naast.id] as Pawn).trom_gebruikt, "trom_gebruikt overleeft de roundtrip")
	var h1: String = Zobrist.state_hash(s)
	naast.trom_gebruikt = false
	assert_true(Zobrist.state_hash(s) != h1, "en zit in de staat-hash")
	# Knop uit: geen bonus, ook niet in de vorm.
	s.rules.campaign["aura_tamboer_stamina"] = 0
	var in_vorm: Pawn = _c21_actief(s, 1, Vector2i(8, 8), 2, 2, 1)   # naast de trom op (7,9)
	assert_eq(Rules.stamina_beschikbaar(s, in_vorm), 2, "aura_tamboer_stamina 0 = uit")


func test_c21_trom_bonus_bij_charge_en_kanon() -> void:
	# De bonus telt in elke actie: charge (stappen + 1) en kanon-acties.
	var s := _c21_staat()
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var trom: Pawn = s._spawn_pawn(1, Vector2i(5, 9), Constants.UnitType.INFANTRY)
	trom.rol = "drum"
	# Een pion met voorraad over, anders sluit de reducer na de kanon-rol de
	# cyclus (niemand kan meer) en wist het ontkoppelen precies wat we meten.
	_c21_actief(s, 1, Vector2i(1, 10), 2, 3, 1)
	var ruiter: Pawn = s._spawn_pawn(1, Vector2i(6, 9), Constants.UnitType.CAVALRY)
	ruiter.link_card(Card.new(s.next_card_id(), 1, 0, 3, 2, 2))
	var vijand: Pawn = s._spawn_pawn(2, Vector2i(6, 6), Constants.UnitType.INFANTRY)
	# Twee stappen (naar 6,7) plus de aanval = 3: alleen met de trom te betalen.
	var charge: Dictionary = Actions.make_charge(ruiter.id, Vector2i(6, 7), vijand.id)
	assert_true(Validator.is_legal(s, charge, 1).legal, "charge van 3 met 2 stamina en de trom")
	var res: Dictionary = Rules.apply_charge(s, ruiter.id, Vector2i(6, 7), vijand.id)
	assert_true(bool(res.success), "charge lukt")
	assert_eq(ruiter.remaining_stamina, 0, "2 eigen + 1 trom betaald")
	assert_true(ruiter.trom_gebruikt)
	# Kanon: rollen kost 1; met 0 eigen stamina en de trom mag het nog een keer.
	var kanon: Pawn = s._spawn_pawn(1, Vector2i(4, 9), Constants.UnitType.ARTILLERY)
	kanon.link_card(Card.new(s.next_card_id(), 1, 0, 2, 1, 2))
	kanon.remaining_stamina = 0
	var rol: Dictionary = Actions.make_cannon_roll(kanon.id, Vector2i(4, 8))
	assert_true(Validator.is_legal(s, rol, 1).legal, "kanon rolt op de trom")
	var uit: Dictionary = Reducer.apply(s, rol, 1)
	assert_true(bool(uit.ok), "reducer laat de rol toe: %s" % str(uit.get("error", "")))
	assert_eq(kanon.position, Vector2i(4, 8))
	assert_eq(kanon.remaining_stamina, 0, "de trom betaalde de rol")
	assert_true(kanon.trom_gebruikt)


func test_ruiter_heeft_minstens_2_stamina_en_2_attack() -> void:
	# 4.3.5 (Max, 8 september): "een bigbro / paard heeft altijd 2 stamina en 2
	# attack". Gelezen als ondergrens (stat_minimum), na kaart en bonussen,
	# naast de basis-HP van C12. Een sterkere kaart telt gewoon.
	var regels := RulesConfig.from_dict({"campaign": {}, "basis_hp": {"cav": 2},
		"stat_minimum": {"cav": {"stamina": 2, "attack": 2}}})
	assert_eq(int(regels.stat_minimum["cav"]["stamina"]), 2, "knop gelezen")
	var rond: RulesConfig = RulesConfig.from_dict(regels.to_dict())
	assert_eq(int(rond.stat_minimum["cav"]["attack"]), 2, "knop overleeft to_dict/from_dict (view, replay)")
	var s := GameState.new()
	s.rules = regels
	s.doctrines[1] = Constants.Doctrine.MENS
	s.doctrines[2] = Constants.Doctrine.MENS
	s.phase = Phase.linking_for_round(1)
	s.current_player = 1
	s.initiative_player = 1
	var ruiter: Pawn = s._spawn_pawn(1, Vector2i(5, 10), Constants.UnitType.CAVALRY)
	var soldaat: Pawn = s._spawn_pawn(1, Vector2i(6, 10), Constants.UnitType.INFANTRY)
	var sterke: Pawn = s._spawn_pawn(1, Vector2i(7, 10), Constants.UnitType.CAVALRY)
	s._spawn_pawn(2, Vector2i(5, 0), Constants.UnitType.INFANTRY)
	var zwak1 := Card.new(s.next_card_id(), 1, 1, 5, 1, 1)
	var zwak2 := Card.new(s.next_card_id(), 1, 1, 5, 1, 1)
	var sterk := Card.new(s.next_card_id(), 1, 1, 1, 4, 3)
	for k in [zwak1, zwak2, sterk]:
		s.all_cards[k.id] = k
	s.cards_revealed[1] = [zwak1, zwak2, sterk]
	assert_true(bool(Reducer.apply(s, Actions.make_link(zwak1.id, ruiter.id), 1).ok))
	assert_eq(ruiter.remaining_stamina, 2, "ruiter met een 1-stamina-kaart: 2")
	assert_eq(ruiter.max_stamina, 2)
	assert_eq(ruiter.attack_value, 2, "en 2 attack")
	assert_eq(ruiter.current_hp, 7, "C12 blijft: 5 van de kaart + 2 basis")
	assert_true(bool(Reducer.apply(s, Actions.make_link(zwak2.id, soldaat.id), 1).ok))
	assert_eq(soldaat.remaining_stamina, 1, "infanterie houdt gewoon de kaart")
	assert_eq(soldaat.attack_value, 1)
	assert_true(bool(Reducer.apply(s, Actions.make_link(sterk.id, sterke.id), 1).ok))
	assert_eq(sterke.remaining_stamina, 4, "een sterkere kaart wordt niet afgekapt")
	assert_eq(sterke.attack_value, 3)
	# Zonder de knop (4.1 en oude configs): de kaart zoals hij is.
	var kaal := GameState.new()
	kaal.doctrines[1] = Constants.Doctrine.MENS
	var r41: Pawn = kaal._spawn_pawn(1, Vector2i(5, 10), Constants.UnitType.CAVALRY)
	r41.link_card(Card.new(kaal.next_card_id(), 1, 0, 5, 1, 1))
	assert_eq(r41.remaining_stamina, 1, "zonder stat_minimum geen ondergrens")


func test_c21_aura_bereik_is_een_knop() -> void:
	var s := _c21_staat()
	s.rules.campaign["aura_bereik"] = 2
	var aanvaller: Pawn = _c21_actief(s, 1, Vector2i(5, 5), 3, 3, 1)
	var vaandel: Pawn = s._spawn_pawn(1, Vector2i(3, 7), Constants.UnitType.INFANTRY)
	vaandel.rol = "flag"
	assert_eq(Rules.effectieve_attack(s, aanvaller), 2, "bereik 2: twee vakken diagonaal telt")
	var ver: Pawn = _c21_actief(s, 1, Vector2i(6, 4), 3, 3, 1)
	assert_eq(Rules.effectieve_attack(s, ver), 1, "drie vakken ver valt erbuiten")
