extends TestSuite

# F2.5 — agents spelen v4.2: L1, L2 en de MatchRunner (trainer-pad) spawnen,
# bieden CP en spreken de kanon-taal onder een campaign-config. Dit is de
# mini-versie van de F2.5-CHECK; de volle 50-partijen-meting draait via de
# arena-CLI met v42_check_l1/l2.json.


const AIMediumScript := preload("res://scripts/ai/AIMedium.gd")


func _class_name() -> String:
	return "V42AgentTests"


func _campaign_rules() -> RulesConfig:
	return RulesConfig.from_dict({"campaign": {}, "cycle_limit": 10})


func _speel(agent1: Agent, agent2: Agent, seed_val: int) -> Dictionary:
	var runner := AgentRunner.new(agent1, agent2, Constants.Doctrine.MENS, Constants.Doctrine.BEER, seed_val, _campaign_rules())
	runner.max_steps = 2500
	var metrics := ArenaMetrics.new()
	metrics.track_repetitions = false
	runner.metrics = metrics
	runner.run()
	var regel: Dictionary = metrics.finalize(runner, Constants.Doctrine.MENS, Constants.Doctrine.BEER, seed_val, {})
	return {"runner": runner, "regel": regel}


func test_l1_spawnt_en_biedt_onder_v42() -> void:
	var uit: Dictionary = _speel(AgentL1.new(), AgentL1.new(), 4242)
	assert_eq(uit.runner.illegal_count, 0, "geen illegale L1-keuzes onder v4.2")
	var spelers: Dictionary = uit.regel.spelers
	var spawns: int = int(spelers["1"].spawns) + int(spelers["2"].spawns)
	var cp: int = int(spelers["1"].cp_bet) + int(spelers["2"].cp_bet)
	assert_true(spawns > 0, "L1 spawnt onder v4.2 (%d)" % spawns)
	assert_true(cp > 0, "L1 biedt CP in ronde 3 (%d)" % cp)


func test_l2_spawnt_en_biedt_onder_v42() -> void:
	var uit: Dictionary = _speel(AgentL2.new(), AgentL2.new(), 4243)
	assert_eq(uit.runner.illegal_count, 0, "geen illegale L2-keuzes onder v4.2")
	var spelers: Dictionary = uit.regel.spelers
	var spawns: int = int(spelers["1"].spawns) + int(spelers["2"].spawns)
	var cp: int = int(spelers["1"].cp_bet) + int(spelers["2"].cp_bet)
	assert_true(spawns > 0, "L2 spawnt onder v4.2 (%d)" % spawns)
	assert_true(cp > 0, "L2 biedt CP in ronde 3 (%d)" % cp)


func test_matchrunner_trainerpad_speelt_v42() -> void:
	# Het trainer-pad (AIMedium via MatchRunner) mag niet klemlopen in de
	# nieuwe fasen en moet aantoonbaar spawnen en bieden.
	var runner := MatchRunner.new(AIMediumScript.new(), AIMediumScript.new(),
		Constants.Doctrine.MENS, Constants.Doctrine.MENS, 777, _campaign_rules())
	runner.max_steps = 1200
	while not runner.done:
		runner.step()
	var s: GameState = runner.state()
	assert_true(s.cycle > 1, "de partij haalt minstens cyclus 2 (spawn-fase gedraaid)")
	var comp: Array = s.doctrine_data_of(1).comp
	var start_pool: int = int(floor(int(comp[0]) * 1.5)) + int(floor(int(comp[1]) * 1.5)) + int(floor(int(comp[2]) * 1.5))
	assert_true(s.pool_total(1) < start_pool or s.pool_total(2) < start_pool,
		"minstens een kant heeft uit de pool gespawnd")
	assert_true(int(s.cp.get(1, 10)) < 10 or int(s.cp.get(2, 10)) < 10,
		"minstens een kant heeft CP geboden (ronde-3-heuristiek)")


func test_koppel_voorrang_spawn_rij() -> void:
	# Besluit Max (speeltest 25 juli): de spawn-rij moet vrijgespeeld worden —
	# achterrij-pionnen krijgen onder campaign koppel-voorrang, anders
	# blokkeren eeuwige standbeelden daar elke toekomstige spawn.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.phase = Phase.linking_for_round(1)
	s.current_player = 1
	s.initiative_player = 1
	var front: Pawn = s._spawn_pawn(1, Vector2i(5, 7))
	var achter: Pawn = s._spawn_pawn(1, Vector2i(5, 10))
	var kaart := Card.new(s.next_card_id(), 1, 1, 3, 2, 1)
	s.all_cards[kaart.id] = kaart
	s.cards_revealed[1] = [kaart]
	s._spawn_pawn(2, Vector2i(5, 0))
	var ai = AIMediumScript.new()
	ai.player_id = 1
	var link: Dictionary = ai.choose_link(s)
	assert_eq(int(link.pawn_id), achter.id, "achterrij-pion krijgt koppel-voorrang onder campaign")
	# Zonder campaign wint de front-pion (haven-afstand): 4.1-gedrag ongewijzigd.
	s.rules = RulesConfig.new()
	var link41: Dictionary = ai.choose_link(s)
	assert_eq(int(link41.pawn_id), front.id, "4.1: dichtst bij de haven wint zoals altijd")


func test_l0_speelt_v42_legaal() -> void:
	# L0 kiest random uit legal_actions — de nieuwe acties zijn gratis gedekt.
	var uit: Dictionary = _speel(AgentL0.new(), AgentL0.new(), 4244)
	assert_eq(uit.runner.illegal_count, 0, "geen illegale L0-keuzes onder v4.2")
	assert_eq(uit.runner.fallback_count, 0)
