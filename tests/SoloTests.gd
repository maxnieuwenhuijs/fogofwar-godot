extends TestSuite

# F3.2 — SoloDriver: een complete campagne speelt headless uit, deterministisch
# en replaybaar; barks vuren op hun triggers. Kleine campagnes (6 spelers) met
# easy-duels houden de suite snel; de volle 16-bot-CHECK draait via
# `capture.tscn -- solocheck`.


func _class_name() -> String:
	return "SoloTests"


func _speel(seed_val: int) -> SoloDriver:
	var driver := SoloDriver.new(seed_val, -1, 6)
	driver.duel_ai = "easy"
	driver.run_headless()
	return driver


func test_campagne_speelt_uit_tot_kampioen() -> void:
	var driver := _speel(4242)
	assert_eq(driver.c.fase, CState.Fase.KLAAR, "campagne eindigt")
	assert_true(driver.c.winnaar != -1, "er is een kampioen")
	assert_true(driver.duels_gespeeld > 0, "er is echt gevochten (%d duels)" % driver.duels_gespeeld)
	assert_true(driver.feed.size() > 0, "de tijdlijn heeft rapporten/barks")


func test_determinisme_zelfde_seed() -> void:
	var a := _speel(777)
	var b := _speel(777)
	assert_eq(a.c.winnaar, b.c.winnaar, "zelfde seed = zelfde kampioen")
	assert_eq(a.clog.entries.size(), b.clog.entries.size(), "zelfde actielog-lengte")
	assert_eq(JSON.stringify(a.c.to_dict()), JSON.stringify(b.c.to_dict()), "byte-identieke eindstand")


func test_campagne_log_replayt() -> void:
	var driver := _speel(31337)
	var uitkomst: Dictionary = CLog.fold(driver.clog.meta.begin, driver.clog.entries)
	assert_true(bool(uitkomst.ok), "het campagne-log replayt zonder weigeringen")
	assert_eq(JSON.stringify((uitkomst.cstate as CState).to_dict()),
		JSON.stringify(driver.c.to_dict()), "replay = byte-identieke eindstand")


func test_barks_vuren_op_triggers() -> void:
	# Mechanica-check per archetype: elke benoemde trigger levert tekst.
	for archetype in Personalities.ARCHETYPES:
		var agent := CampaignAgent.new()
		agent.profiel = (Personalities.ARCHETYPES[archetype] as Dictionary).duplicate(true)
		agent.rng = SeededRng.new(5)
		for trigger in ["nominatie_teamgenoot", "zelf_nominatie", "donatie", "testament", "testament_naar_vijand"]:
			assert_true(agent.bark(trigger) != "", "%s heeft een bark voor %s" % [archetype, trigger])
	# Integratie: een gespeelde campagne bevat nominatie-barks in de feed.
	var driver := _speel(4242)
	var triggers: Dictionary = {}
	for e in driver.feed:
		if String(e.type) == "bark":
			triggers[String(e.trigger)] = true
	assert_true(triggers.has("nominatie_teamgenoot") or triggers.has("zelf_nominatie"),
		"de raad produceert barks in het log")


func test_autosave_en_hervatten_identiek() -> void:
	# F3.4-CHECK: halverwege "afsluiten" en hervatten -> byte-identieke staat.
	var pad := "user://test_campagne_f34.jsonl"
	var driver := SoloDriver.new(9911, -1, 6, pad)
	driver.duel_ai = "easy"
	for _i in 6:
		if driver.c.fase != CState.Fase.KLAAR:
			driver.stap()
	var staat_voor: String = JSON.stringify(driver.c.to_dict())
	var entries_voor: int = driver.clog.entries.size()
	driver = null  # "afsluiten": alleen het bestand blijft over
	var terug: SoloDriver = SoloDriver.hervat(pad, -1)
	assert_true(terug != null, "autosave laadt en foldt")
	assert_eq(JSON.stringify(terug.c.to_dict()), staat_voor, "hervatte staat is byte-identiek")
	assert_eq(terug.clog.entries.size(), entries_voor, "log volledig terug")
	terug.duel_ai = "easy"
	terug.run_headless()
	assert_eq(terug.c.fase, CState.Fase.KLAAR, "na hervatten speelt de campagne gewoon uit")
	assert_true(terug.c.winnaar != -1)


func test_autosave_na_elke_actie_foldbaar() -> void:
	# Kill-garantie: op elk moment is het bestand een geldige, foldbare save.
	var pad := "user://test_campagne_f34b.jsonl"
	var driver := SoloDriver.new(9912, -1, 6, pad)
	driver.duel_ai = "easy"
	for _i in 4:
		if driver.c.fase != CState.Fase.KLAAR:
			driver.stap()
		var data: Dictionary = CLog.laad_jsonl(pad)
		assert_true(bool(data.ok), "bestand leesbaar na elke stap")
		assert_true(bool(CLog.fold(data.meta.begin, data.entries).ok), "en foldbaar")


func test_mens_duel_pauzeert_en_bord_uitslag_boekt() -> void:
	# F3.4b: de driver pauzeert op het mens-duel; het "bord" (hier: een runner
	# met exact de brug-config) speelt het uit en de uitslag boekt terug.
	var easy := preload("res://scripts/ai/AIEasy.gd")
	var driver := SoloDriver.new(2026, 0, 6)
	driver.duel_ai = "easy"
	driver.duel_cycle_limit = 4
	driver.duel_max_steps = 400
	var op_bord := 0
	var vangnet := 0
	while driver.c.fase != CState.Fase.KLAAR and vangnet < 900:
		vangnet += 1
		if not driver.wacht_op_mens():
			driver.stap()
			continue
		match driver.c.fase:
			CState.Fase.NOMINATIE:
				var eigen_ll: Array = []
				for lid in driver.c.actieve_leden(int(driver.c.spelers[0].team)):
					if not driver.c.al_genomineerd.has(lid):
						eigen_ll.append(lid)
				var vij_ll: Array = []
				for lid in driver.c.actieve_leden(1 - int(driver.c.spelers[0].team)):
					if not driver.c.al_genomineerd.has(lid):
						vij_ll.append(lid)
				var eigen: int = 0 if driver.c.actieve_leden(int(driver.c.spelers[0].team)).size() == 1 else int(eigen_ll[0])
				assert_true(driver.submit_mens_nominatie(eigen, int(vij_ll[0])), "mens-stem geldig")
			CState.Fase.DONATIE:
				driver.submit_mens_klaar_met_doneren()
			CState.Fase.TESTAMENT:
				driver.submit_mens_testament([])
			CState.Fase.DUELS, CState.Fase.BURGEROORLOG:
				var d: Dictionary = driver.mens_duel()
				assert_true(int(d.p1) == 0 or int(d.p2) == 0, "de pauze is echt het mens-duel")
				op_bord += 1
				var b: int = int(d.p2) if int(d.p1) == 0 else int(d.p1)
				var cp_a: int = driver.c.cp_van(0)
				var cp_b: int = driver.c.cp_van(b)
				var rules: RulesConfig = driver.duel_rules_voor(0, b)
				var runner := MatchRunner.new(easy.new(), easy.new(),
					int(driver.c.spelers[0].doctrine), int(driver.c.spelers[b].doctrine),
					4242 + op_bord, rules)
				runner.max_steps = 400
				while not runner.done:
					runner.step()
				assert_true(driver.verwerk_duel_uitslag(int(d.idx), 0, b, cp_a, cp_b,
					runner.state(), runner.winner), "bord-uitslag boekt in de campagne")
	assert_eq(driver.c.fase, CState.Fase.KLAAR, "campagne met mens-duels speelt uit")
	assert_true(op_bord > 0, "de mens heeft echt op het bord gevochten (%d duels)" % op_bord)
	assert_true(driver.c.winnaar != -1)
	var uitkomst: Dictionary = CLog.fold(driver.clog.meta.begin, driver.clog.entries)
	assert_true(bool(uitkomst.ok), "ook met bord-uitslagen replayt het log")


func test_c9_loting_in_solo_campagne() -> void:
	# C9: ronde 1 loot het systeem — iedereen vecht, de paren staan in het log.
	var driver := SoloDriver.new(808, -1, 6)
	driver.duel_ai = "easy"
	driver.stap()
	assert_eq(driver.c.fase, CState.Fase.DONATIE, "loting sluit de nominatie meteen")
	assert_eq(driver.c.duels_deze_ronde.size(), 3, "3v3: iedereen vecht in ronde 1")
	assert_eq(String((driver.clog.entries[0].action as Dictionary).type), "loting",
		"de loting staat als data in het log (replaybaar)")


func test_grootboek_sortering() -> void:
	# F3.3-rest: het Grootboek sorteert stabiel op elke kolom.
	var driver := _speel(555)  # uitgespeelde campagne: ook gevallen spelers
	for kolom in ["punten", "pool", "cp", "inf"]:
		var rijen: Array = LedgerScreen.rijen(driver.c, kolom)
		assert_eq(rijen.size(), 6, "elke speler een rij")
		for i in range(1, rijen.size()):
			assert_true(int(rijen[i - 1][kolom]) >= int(rijen[i][kolom]),
				"kolom %s aflopend" % kolom)
	var op_naam: Array = LedgerScreen.rijen(driver.c, "naam")
	for i in range(1, op_naam.size()):
		assert_true(String(op_naam[i - 1].naam) <= String(op_naam[i].naam), "naam oplopend")
	var op_status: Array = LedgerScreen.rijen(driver.c, "status")
	var gevallen_gezien := false
	for rij in op_status:
		if String(rij.status) != "actief":
			gevallen_gezien = true
		else:
			assert_true(not gevallen_gezien, "actieve spelers boven de gevallenen")


func test_arm_start_comp_gecapt() -> void:
	# C7: een duel-config met minder voorraad dan comp start kleiner.
	var rules := RulesConfig.from_dict({"campaign": {
		"comp_override": {"1": [3, 1, 0], "2": [5, 2, 1]},
		"pools": {"1": {"inf": 0, "cav": 0, "art": 0}, "2": {"inf": 2, "cav": 0, "art": 0}},
		"cp": {"1": 2, "2": 7},
	}})
	var s := GameState.new()
	s.rules = rules
	s.doctrines[1] = Constants.Doctrine.MENS
	s.doctrines[2] = Constants.Doctrine.MENS
	assert_eq((s.doctrine_data_of(1).comp as Array), [3, 1, 0], "comp per speler overschreven")
	var opstelling: Array = s.default_placement(1)
	assert_eq(opstelling.size(), 4, "arm = kleiner starten (3 inf + 1 cav)")
	s.setup_initial_pawns()
	assert_eq(int(s.cp[1]), 2, "per-speler CP uit de campagnelaag")
	assert_eq(int(s.cp[2]), 7)
	assert_eq(s.pool_total(2), 2, "expliciete reserve")
