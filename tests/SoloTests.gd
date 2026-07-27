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
	# Integratie: een campagne MET een raadsronde bevat nominatie-barks.
	# C10 maakt snelle campagnes mogelijk (ronde 1 + burgeroorlog, geen raad) —
	# zoek dus deterministisch een seed die ronde 2 haalt; bestaat die niet,
	# dan is dát de echte vondst (raad zou nooit meer voorkomen).
	var met_raad: SoloDriver = null
	for seed_val in [4242, 4243, 4244, 4245, 4246]:
		var kandidaat := _speel(seed_val)
		if kandidaat.c.ronde >= 2:
			met_raad = kandidaat
			break
	assert_true(met_raad != null,
		"minstens 1 van 5 seeds haalt een raadsronde (anders is de raad dood spel)")
	if met_raad != null:
		var triggers: Dictionary = {}
		for e in met_raad.feed:
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


func test_testament_van_gevallen_mens_wacht_op_ui() -> void:
	# Deadlock-regressie (27 juli): valt de MENS met bezit over, dan is zijn
	# status al "uitgevallen" op het moment dat het testament opent. De oude
	# actief-guard in wacht_op_mens() gaf dan false -> de bots sloegen het
	# mens-testament over (bewust, UI-taak) én de UI kwam nooit -> muurvast.
	var driver := SoloDriver.new(6001, 0, 6)
	driver.c.fase = CState.Fase.TESTAMENT
	driver.c.spelers[0].status = "uitgevallen"
	driver.c.pending_testamenten.append(0)
	assert_true(driver.wacht_op_mens(), "gevallen mens met open testament = UI aan zet")
	# De UI levert het testament aan; de fase moet daarna gewoon doorlopen.
	assert_true(driver.submit_mens_testament([]), "leeg testament (alles verbrandt) is geldig")
	assert_true(driver.c.fase != CState.Fase.TESTAMENT, "testament-fase rondt af")
	assert_true(driver.c.pending_testamenten.is_empty(), "geen open testamenten meer")
	assert_false(driver.wacht_op_mens(), "de gevallen mens is daarna toeschouwer")


func test_l1_route_boekt_duels_deterministisch() -> void:
	# Hang-fix (27 juli): bot-duels kunnen via AgentRunner + L1/L2 spelen (de
	# snelle arena-route). LET OP — bevinding uit dezelfde sessie: een VOLLE
	# campagne convergeert níét op L1 (haven-rushers winnen zonder slachtoffers,
	# dus niemand zakt ooit door zijn pool; uitvallen = attritie). De hub
	# gebruikt daarom "easy"; deze test dekt alleen het AgentRunner-pad zelf:
	# duels spelen, uitslagen boeken, het log foldt, en alles is deterministisch.
	var a := SoloDriver.new(4243, -1, 6)
	a.duel_ai = "l1"
	for _i in 12:
		if a.c.fase != CState.Fase.KLAAR:
			a.stap()
	assert_true(a.duels_gespeeld > 0, "AgentRunner-duels boeken uitslagen (%d)" % a.duels_gespeeld)
	assert_true(bool(CLog.fold(a.clog.meta.begin, a.clog.entries).ok),
		"het log met AgentRunner-uitslagen replayt")
	var b := SoloDriver.new(4243, -1, 6)
	b.duel_ai = "l1"
	for _i in 12:
		if b.c.fase != CState.Fase.KLAAR:
			b.stap()
	assert_eq(JSON.stringify(a.c.to_dict()), JSON.stringify(b.c.to_dict()),
		"byte-identieke staat via AgentRunner (deterministisch per seed)")


func test_mens_factie_keuze_vast_voor_campagne() -> void:
	# Besluit Max (27 juli): bij de campagnestart kies je je factie en die
	# ben je de hele campagne. De keuze gaat als constructor-param mee en
	# landt in de begin-staat (dus ook in het log/de autosave).
	var driver := SoloDriver.new(6002, 0, 6, "", Constants.Doctrine.LEEUW)
	assert_eq(int(driver.c.spelers[0].doctrine), Constants.Doctrine.LEEUW,
		"gekozen factie toegepast op de mens")
	var pool: Dictionary = driver.c.pool_van(0)
	assert_eq(int(pool.cav), int(floor(10 * driver.c.rules.start_poolfactor)),
		"reinforcements volgen de gekozen factie (Leeuw: 10 cav x poolfactor)")
	var zonder := SoloDriver.new(6002, 0, 6)
	assert_eq(int(zonder.c.spelers[0].doctrine), 0,
		"zonder keuze blijft de oude round-robin (tests/headless ongewijzigd)")


func test_vol_team_start_en_inzet_boeking() -> void:
	# Besluit Max (27 juli): elk duel start HOE DAN OOK met de volle
	# samenstelling; de pool is puur reinforcements en slinkt alleen door
	# INZET (spawns), niet door bord-verliezen.
	var driver := SoloDriver.new(7001, -1, 6)
	var comp: Array = Constants.doctrine_data(int(driver.c.spelers[0].doctrine)).comp
	# Maak speler 0 straatarm: zelfs dan start het bord vol.
	var arm: Dictionary = driver.c.pool_van(0)
	driver.c._boek("test", 0, -int(arm.inf), -int(arm.cav), -int(arm.art), 0, 0)
	var rules: RulesConfig = driver.duel_rules_voor(0, 3)
	assert_eq((rules.campaign.comp_override["1"] as Array), comp,
		"vol team op het bord, ook met lege pool")
	assert_eq(int(rules.campaign.pools["1"].inf), 0, "geen reinforcements = niets te spawnen")
	# De in-match-reserve is gecapt op de duel-inzetruimte (eliminatie blijft bereikbaar).
	var rijk: RulesConfig = SoloDriver.new(7002, -1, 6).duel_rules_voor(0, 3)
	var rp: Dictionary = rijk.campaign.pools["1"]
	assert_true(int(rp.inf) + int(rp.cav) + int(rp.art) <= driver.c.rules.duel_spawn_totaal_max,
		"in-match-reserve <= duel_spawn_totaal_max")
	# Inzet-boeking: 2 gespawnde soldaten kosten pool; verliezen niet.
	var d2 := SoloDriver.new(7003, -1, 6)
	var voor: int = d2.c.pool_totaal_van(0)
	CReducer.apply(d2.c, CActions.make_loting([[0, 3], [1, 4], [2, 5]]), -1)
	var res: Dictionary = CReducer.apply(d2.c, CActions.make_match_result(
		0, 3, "haven", {"0": {"inf": 4}, "3": {"inf": 0}},
		{}, {"0": {"inf": 2}, "3": {"inf": 0, "cav": 0, "art": 0}}), -1)
	assert_true(res.ok, "match_result met inzet-veld boekt")
	assert_eq(d2.c.pool_totaal_van(0), voor - 2,
		"pool daalt met de INZET (2), niet met de verliezen (4)")


func test_c9_loting_in_solo_campagne() -> void:
	# C9: ronde 1 loot het systeem — iedereen vecht, de paren staan in het log.
	var driver := SoloDriver.new(808, -1, 6)
	driver.duel_ai = "easy"
	driver.stap()
	assert_eq(driver.c.fase, CState.Fase.DUELS, "loting -> direct de duels in (geen donaties in ronde 1)")
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
