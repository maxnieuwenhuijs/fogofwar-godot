extends TestSuite

# Strategy mode (21 oktober, Max: "ongeacht factie heeft ieder leger een Budget
# voor het gevecht, een speler mag dan helemaal zelf kiezen hoe hij deze vult
# ... Je ziet wel nog je 3d modellen van de factie maar verder geen speciale
# regels"). De regelknop zelf (uit = byte-gelijk), de neutrale facties, de
# legerkeuze in de opstelling (budget, bord, blind), de reserve en CP zonder
# factiebonus, elk type te koop, de view, de serializer en de agents, de bots,
# volledige partijen, fuzz, en de campagne in Strategy mode.


func _class_name() -> String:
	return "StrategieTests"


## Een los potje in Strategy mode op de echte 1v1-regels (v42_default.json).
func _staat(d1: int = Constants.Doctrine.MUIS, d2: int = Constants.Doctrine.WOLF, blok: Dictionary = {}) -> GameState:
	var s := GameState.new()
	s.rules = RulesConfig.load_from_file("res://arena/arena_configs/v42_default.json")
	s.rules.doctrines = CRules.facties_uit_bestand()
	s.rules.strategie = RulesConfig.normaliseer_strategie(blok)
	s.doctrines[1] = d1
	s.doctrines[2] = d2
	s.phase = Phase.Type.PLACEMENT
	s.init_pools()
	return s


func test_uit_is_byte_gelijk() -> void:
	var r := RulesConfig.from_dict({"campaign": {}})
	assert_false(r.strategie_actief(), "zonder blok uit")
	assert_false(r.to_dict().has("strategie"), "to_dict noemt hem niet (goldens en hashes blijven gelijk)")
	var s := GameState.new()
	s.rules = r
	s.setup_initial_pawns()
	assert_false(Serializer.state_to_dict(s).has("leger"), "geen leger in het snapshot")
	assert_false(View.for_player(s, 1).has("leger"), "geen leger in de view")


func test_blok_rondreis_en_defaults() -> void:
	var r := RulesConfig.from_dict({"strategie": {"budget": 24.0}})
	assert_true(r.strategie_actief(), "een blok zet hem aan")
	assert_eq(int(r.strategie.budget), 24, "budget overgenomen (float -> int)")
	assert_eq(int(r.strategie.kaarten), 3, "ontbrekende knoppen krijgen de default")
	var terug := RulesConfig.from_dict(r.to_dict())
	assert_eq(terug.to_dict(), r.to_dict(), "to_dict -> from_dict is stabiel")
	# Een standaardleger dat niet in het budget past wordt vervangen.
	var krap := RulesConfig.from_dict({"strategie": {"budget": 12}})
	var std: Array = krap.strategie.standaard
	assert_true(int(std[0]) + 2 * int(std[1]) + 3 * int(std[2]) <= 12, "standaard past in een krap budget: %s" % str(std))


func test_facties_zijn_neutraal() -> void:
	var s := _staat()
	for doc in Constants.DOCTRINE_DATA:
		s.doctrines[1] = int(doc)
		var d: Dictionary = s.doctrine_data_of(1)
		assert_eq(int(d.cards), 3, "kaarten gelijk voor %d" % int(doc))
		assert_eq(int(d.budget), 7, "kaartbudget gelijk voor %d" % int(doc))
		for k in RulesConfig.NEUTRALE_PERKS:
			assert_eq(d[k], RulesConfig.NEUTRALE_PERKS[k], "perk %s neutraal voor %d" % [k, int(doc)])
		assert_eq(String(d.name), String(Constants.doctrine_data(int(doc)).name), "naam (uiterlijk) blijft")
		assert_eq(d.comp, [16, 4, 2], "nog niet gekozen: het standaardleger")


func test_kiezen_in_de_opstelling() -> void:
	var s := _staat()
	var leger := [6, 0, 8]   # 6 + 24 = 30 punten, 14 pionnen
	var opst: Array = s.default_placement(1, leger)
	assert_eq(opst.size(), 14, "alles staat op het bord")
	assert_true(s.is_valid_placement(1, opst), "geldig binnen het budget")
	var res: Dictionary = Reducer.apply(s, Actions.make_place(opst), 1)
	assert_true(res.ok, "PLACE met het eigen leger: %s" % String(res.get("error", "")))
	assert_eq(s.leger.get(1), leger, "het leger is vastgelegd")
	assert_eq(s.doctrine_data_of(1).comp, leger, "doctrine_data_of rekent ermee")
	assert_eq(s.doctrine_data_of(2).comp, [16, 4, 2], "de ander nog niet gekozen")


func test_te_duur_of_te_groot_geweigerd() -> void:
	var s := _staat()
	assert_false(s.leger_geldig([10, 6, 3]), "10 + 12 + 9 = 31 > 30")
	assert_false(s.leger_geldig([0, 0, 0]), "een leger heeft minstens een pion")
	assert_false(s.leger_geldig([23, 0, 0]), "past niet op twee rijen")
	assert_true(s.leger_geldig([22, 0, 0]), "22 soldaten = 22 punten: geldig (de rest vervalt)")
	var te_duur: Array = s.default_placement(1, [10, 6, 3])
	assert_false(s.is_valid_placement(1, te_duur), "een te dure opstelling wordt geweigerd")
	var res: Dictionary = Reducer.apply(s, Actions.make_place(te_duur), 1)
	assert_false(res.ok, "de reducer weigert hem ook")


func test_standaard_opstelling_voor_elk_leger() -> void:
	var s := _staat()
	for leger in [[22, 0, 0], [0, 15, 0], [0, 0, 10], [6, 0, 8], [14, 8, 0], [1, 0, 0], [8, 8, 2], [0, 1, 9]]:
		if not s.leger_geldig(leger):
			continue
		var opst: Array = s.default_placement(1, leger)
		var telling := [0, 0, 0]
		for e in opst:
			telling[int(e.type)] += 1
		assert_eq(telling, leger, "standaard-opstelling zet precies %s neer" % str(leger))
		assert_true(s.is_valid_placement(1, opst), "en dat is geldig: %s" % str(leger))


func test_opstelling_facties_ongewijzigd() -> void:
	# De uitbreiding van default_placement (meer kanonnen, doorschuiven) mag de
	# opstelling van de gewone facties niet raken.
	var s := GameState.new()
	s.rules = RulesConfig.load_from_file(CRules.REGELS_BESTAND)
	for doc in Constants.DOCTRINE_DATA:
		s.doctrines[1] = int(doc)
		var opst: Array = s.default_placement(1)
		assert_true(s.is_valid_placement(1, opst), "factie %d stelt nog geldig op" % int(doc))
		var art_vooraan := 0
		for e in opst:
			if int(e.type) == Constants.UnitType.ARTILLERY:
				assert_true([0, 10, 5].has(int(e.pos.x)) and int(e.pos.y) == 9, "kanon op de oude plek")
				art_vooraan += 1
		assert_eq(art_vooraan, int(s.doctrine_data_of(1).comp[2]), "alle kanonnen vooraan")


func test_reserve_en_cp_zonder_factiebonus() -> void:
	# v42_default: potje_factor 0,35, cp_start 10. Reserve = floor(30 x 0,5) x 0,35.
	for doc in Constants.DOCTRINE_DATA:
		var s := _staat(int(doc), int(doc))
		assert_eq(int(s.pools[1].pt), int(round(15 * 0.35)), "reserve gelijk voor %d" % int(doc))
		assert_eq(int(s.cp[1]), int(round(10 * 0.35)), "CP gelijk voor %d (geen bonus)" % int(doc))


func test_elk_type_te_koop() -> void:
	var s := _staat(Constants.Doctrine.MUIS, Constants.Doctrine.BEER)
	assert_true(s.kent_type(1, Constants.UnitType.ARTILLERY), "een Muis mag in Strategy mode kanonnen")
	assert_true(s.kent_type(2, Constants.UnitType.ARTILLERY), "een Beer ook")
	var gewoon := GameState.new()
	gewoon.rules = RulesConfig.load_from_file(CRules.REGELS_BESTAND)
	gewoon.doctrines[1] = Constants.Doctrine.MUIS
	assert_false(gewoon.kent_type(1, Constants.UnitType.ARTILLERY), "buiten Strategy mode nog steeds niet")


func test_kiezen_is_blind() -> void:
	var s := _staat()
	Reducer.apply(s, Actions.make_place(s.default_placement(1, [6, 0, 8])), 1)
	var v2: Dictionary = View.for_player(s, 2)
	assert_false((v2.get("leger", {}) as Dictionary).has("1"), "de ander ziet je leger niet tijdens het opstellen")
	var v1: Dictionary = View.for_player(s, 1)
	assert_eq((v1.leger as Dictionary).get("1"), [6, 0, 8], "je eigen leger zie je wel")
	Reducer.apply(s, Actions.make_place(s.default_placement(2)), 2)
	assert_true(s.phase != Phase.Type.PLACEMENT, "de opstelfase is voorbij")
	var v2b: Dictionary = View.for_player(s, 2)
	assert_eq((v2b.leger as Dictionary).get("1"), [6, 0, 8], "daarna is het openbaar (het staat op het bord)")


func test_serializer_en_agent_herbouw() -> void:
	var s := _staat()
	Reducer.apply(s, Actions.make_place(s.default_placement(1, [14, 8, 0])), 1)
	Reducer.apply(s, Actions.make_place(s.default_placement(2, [15, 0, 5])), 2)
	var d: Dictionary = Serializer.state_to_dict(s)
	var terug: GameState = Serializer.state_from_dict(d)
	assert_eq(Zobrist.state_hash(terug), Zobrist.state_hash(s), "rondreis via de serializer")
	assert_eq(terug.doctrine_data_of(2).comp, [15, 0, 5], "het leger komt terug")
	var view: Dictionary = View.for_player(s, 1)
	var herbouwd: GameState = Agent.reconstruct_state(view)
	assert_eq(herbouwd.doctrine_data_of(1).comp, [14, 8, 0], "de agent kent zijn eigen leger")
	var data: Dictionary = Agent.doctrine_data_uit_view(view, 2)
	assert_eq(data.comp, [15, 0, 5], "en dat van de ander na de opstelfase")
	assert_false(bool(data.wolf_step), "de Wolf heeft in de view ook geen perk")


func test_legal_actions_bieden_legers() -> void:
	var s := _staat()
	var legal: Array = Validator.legal_actions(s, 1)
	assert_true(legal.size() >= 3, "meer dan alleen de standaard: %d opties" % legal.size())
	var gezien: Dictionary = {}
	for a in legal:
		assert_true(Validator.is_legal(s, a, 1).legal, "elke optie is legaal")
		var telling := [0, 0, 0]
		for e in a.placements:
			telling[int(e.type)] += 1
		gezien[str(telling)] = true
	assert_eq(gezien.size(), legal.size(), "allemaal verschillende legers")


func test_bot_kiest_binnen_budget_met_factiesmaak() -> void:
	var s := _staat(Constants.Doctrine.WOLF, Constants.Doctrine.MUIS)
	var wolf := AIController.new()
	wolf.player_id = 1
	var muis := AIController.new()
	muis.player_id = 2
	var lw: Array = wolf.kies_leger(s)
	var lm: Array = muis.kies_leger(s)
	assert_true(s.leger_geldig(lw), "wolf-leger geldig: %s" % str(lw))
	assert_true(s.leger_geldig(lm), "muis-leger geldig: %s" % str(lm))
	assert_true(int(lw[1]) > int(lm[1]), "de Wolf koopt meer ruiters dan de Muis (%s tegen %s)" % [str(lw), str(lm)])
	assert_eq(int(lm[2]), 0, "de Muis koopt uit smaak geen kanonnen")
	var opst: Array = wolf.choose_placement(s)
	assert_true(s.is_valid_placement(1, opst), "de bot-opstelling is geldig")
	wolf.weights["leger_art"] = 0.9
	wolf.weights["leger_cav"] = 0.0
	var kanonnen: Array = wolf.kies_leger(s)
	assert_true(int(kanonnen[2]) >= 8, "het gewicht leger_art stuurt de keuze: %s" % str(kanonnen))


func test_volledige_partijen() -> void:
	var rules := RulesConfig.load_from_file(CRules.REGELS_BESTAND)
	rules.strategie = RulesConfig.normaliseer_strategie({})
	var paren := [[Constants.Doctrine.WOLF, Constants.Doctrine.MUIS, "l2", "l1"],
		[Constants.Doctrine.LEEUW, Constants.Doctrine.BEER, "l1", "l2"],
		[Constants.Doctrine.VOS, Constants.Doctrine.MENS, "l2", "l2"]]
	for i in paren.size():
		var p: Array = paren[i]
		var a1: Agent = AgentL2.new() if String(p[2]) == "l2" else AgentL1.new()
		var a2: Agent = AgentL2.new() if String(p[3]) == "l2" else AgentL1.new()
		var runner := AgentRunner.new(a1, a2, int(p[0]), int(p[1]), 4100 + i, rules)
		runner.max_steps = 3000
		runner.run()
		assert_false(runner.afgekapt, "partij %d eindigt echt (niet op de noodstop)" % i)
		assert_true(runner.winner == 1 or runner.winner == 2, "partij %d heeft een winnaar" % i)
		assert_eq(runner.illegal_count + runner.fallback_count, 0, "partij %d zonder illegale of terugval-keuzes" % i)
		var st: GameState = runner.state()
		assert_true(st.leger.has(1) and st.leger.has(2), "partij %d: beide legers vastgelegd" % i)
		for kant in [1, 2]:
			assert_true(st.leger_geldig(st.leger[kant]), "partij %d kant %d binnen budget: %s" % [i, kant, str(st.leger[kant])])


func test_fuzz_in_strategy_mode() -> void:
	var uitkomst: Dictionary = ArenaFuzz.run(8, 712000, "user://fuzz_strategie", false, true)
	assert_eq(int(uitkomst.violations), 0, "fuzz schoon in Strategy mode: %s" % str(uitkomst.repro_paden))


func test_campagne_start_gelijk_zonder_bonus() -> void:
	var regels := CRules.new()
	regels.strategie = RulesConfig.normaliseer_strategie({})
	var c := CState.new()
	var lijst: Array = []
	for i in 12:
		lijst.append({"naam": "S%d" % i, "doctrine": i % 6})
	c.setup(lijst, regels)
	var eerste: int = c.pool_totaal_van(0)
	assert_eq(eerste, 15, "versterkingen = 30 x 0,5")
	for i in 12:
		assert_eq(c.pool_totaal_van(i), eerste, "speler %d dezelfde voorraad" % i)
		assert_eq(c.cp_van(i), regels.start_cp, "speler %d dezelfde CP" % i)
	var terug := CRules.from_dict(regels.to_dict())
	assert_true(terug.strategie_actief(), "Strategy mode bevroren in de save")
	assert_false(CRules.from_dict(CRules.new().to_dict()).strategie_actief(), "een gewone save blijft gewoon")
	assert_false(CRules.new().to_dict().has("strategie"), "en noemt hem niet")


func test_campagne_duelregels() -> void:
	var driver := SoloDriver.new(31, -1, 16, "", -1, true)
	assert_true(driver.c.rules.strategie_actief(), "de driver speelt Strategy mode")
	var rules: RulesConfig = driver.duel_rules_voor(0, 8)
	assert_true(rules.strategie_actief(), "het duel krijgt het blok mee")
	assert_false((rules.campaign as Dictionary).has("comp_override") and rules.campaign.comp_override != null,
		"geen vaste startopstelling: het leger kies je in het duel")
	var s := GameState.new()
	s.rules = rules
	s.doctrines[1] = int(driver.c.spelers[0].doctrine)
	s.doctrines[2] = int(driver.c.spelers[8].doctrine)
	s.init_pools()
	assert_eq(int(s.pools[1].pt), 15, "de reserve komt uit het campagnebezit")
	assert_eq(int(s.pools[2].pt), 15, "voor beide kanten gelijk")


func test_campagne_speelt_uit() -> void:
	var driver := SoloDriver.new(57, -1, 16, "", -1, true)
	driver.duel_ai = "l1"
	var kampioen: int = driver.run_headless(600)
	assert_true(kampioen >= 0, "de Strategy-campagne krijgt een kampioen")
	var rapporten := 0
	for e in driver.feed:
		if String(e.get("type", "")) == "report":
			rapporten += 1
	assert_true(rapporten >= 8, "er zijn duels gespeeld: %d" % rapporten)
	for sid in driver.c.spelers:
		var p: Dictionary = driver.c.pool_van(int(sid))
		assert_true(int(p.inf) >= 0 and int(p.cav) >= 0 and int(p.art) >= 0, "geen negatieve voorraad bij %d" % int(sid))
