extends TestSuite

# L4 neuraal (22 september): kenmerken, het netje en de agent.
# (1) de kenmerkrij heeft de aangekondigde lengte en is deterministisch,
# (2) NeuraalNet rekent een handgemaakt netje goed uit (en de proef),
# (3) AgentL4 zonder netje speelt exact als L2,
# (4) AgentL4 met een netje speelt een hele partij legaal via het netje,
# (5) BeslisLog schrijft de kop en records in het beloofde formaat.


func _class_name() -> String:
	return "L4Tests"


func _regels(limiet: int = 12) -> RulesConfig:
	var r := RulesConfig.new()
	r.honger_vanaf_cyclus = limiet
	return r


## Een staat midden in een partij: L0 vs L0 een aantal stappen.
func _staat_na(stappen: int, seed_val: int = 4242) -> GameState:
	var runner := AgentRunner.new(AgentL0.new(), AgentL0.new(),
		Constants.Doctrine.MUIS, Constants.Doctrine.WOLF, seed_val, _regels())
	for i in stappen:
		if runner.done:
			break
		runner.step()
	return runner.state()


## Handgemaakt netje: mu 0, sigma 1, een verborgen laag van 2 (relu(x0),
## relu(-x0)) en uitvoer h0 - h1 = x0. De waarde is dus precies het eerste
## kenmerk (me_alive): "meer eigen pionnen is beter".
func _schrijf_proefnet(pad: String) -> void:
	var n: int = Kenmerken.aantal()
	var mu: Array = []
	var sigma: Array = []
	var w1: Array = []
	for i in n:
		mu.append(0.0)
		sigma.append(1.0)
		w1.append([1.0, -1.0] if i == 0 else [0.0, 0.0])
	var invoer: Array = []
	for i in n:
		invoer.append(float(i) * 0.25 - 1.0)
	var data := {
		"versie": 1,
		"kenmerk_versie": Kenmerken.KENMERK_VERSIE,
		"kenmerken": n,
		"mu": mu,
		"sigma": sigma,
		"lagen": [
			{"w": w1, "b": [0.0, 0.0]},
			{"w": [[1.0], [-1.0]], "b": [0.5]},
		],
		"proef": {"invoer": invoer, "uitvoer": invoer[0] + 0.5},
	}
	var f := FileAccess.open(pad, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	NeuraalNet.wis_cache()


func test_kenmerken_lengte_en_deterministisch() -> void:
	assert_eq(Kenmerken.namen().size(), Kenmerken.aantal(), "namen() en aantal() horen gelijk te zijn")
	var s: GameState = _staat_na(40)
	var voor: String = Zobrist.state_hash(s)
	var r1: PackedFloat32Array = Kenmerken.van_staat(s, Constants.PLAYER_1)
	var r2: PackedFloat32Array = Kenmerken.van_staat(s, Constants.PLAYER_1)
	assert_eq(r1.size(), Kenmerken.aantal())
	assert_true(r1 == r2, "twee keer dezelfde staat hoort dezelfde rij te geven")
	assert_eq(Zobrist.state_hash(s), voor, "kenmerken berekenen mag de staat niet veranderen")
	# De doctrine-one-hots kloppen: muis (1) voor rood, wolf (4) voor blauw.
	var namen: Array[String] = Kenmerken.namen()
	assert_eq(r1[namen.find("doc_me_1")], 1.0)
	assert_eq(r1[namen.find("doc_opp_4")], 1.0)
	assert_eq(r1[namen.find("doc_me_0")], 0.0)
	# Gezien vanuit blauw wisselen ik en de vijand van plaats.
	var r_blauw: PackedFloat32Array = Kenmerken.van_staat(s, Constants.PLAYER_2)
	assert_eq(r_blauw[namen.find("me_alive")], r1[namen.find("opp_alive")])
	assert_eq(r_blauw[namen.find("opp_alive")], r1[namen.find("me_alive")])


func test_kandidaten_volgen_enumerate_actions() -> void:
	var s: GameState = _staat_na(60)
	# Zoek een actiefase-moment.
	var runner := AgentRunner.new(AgentL0.new(), AgentL0.new(),
		Constants.Doctrine.MUIS, Constants.Doctrine.WOLF, 4243, _regels())
	var st: GameState = runner.state()
	var pogingen: int = 0
	while not runner.done and not (st.phase == Phase.Type.ACTION and st.pending_wolf_step_pawn == -1) and pogingen < 400:
		runner.step()
		st = runner.state()
		pogingen += 1
	assert_eq(st.phase, Phase.Type.ACTION, "hoort een actiefase te vinden")
	var ai = preload("res://scripts/ai/AIMedium.gd").new()
	ai.player_id = st.current_player
	var k: Dictionary = Kenmerken.kandidaten(ai, st, st.current_player)
	assert_eq((k.acties as Array).size(), (k.kenmerken as Array).size())
	assert_true((k.acties as Array).size() > 0, "een actiefase hoort kandidaten te hebben")
	assert_eq((k.acties as Array).size(), (ai.enumerate_actions(st, st.current_player) as Array).size())
	assert_true(s != null)


func test_neuraal_net_rekent_proefnet() -> void:
	var pad := "user://l4tests_net.json"
	_schrijf_proefnet(pad)
	var net: NeuraalNet = NeuraalNet.laad(pad)
	assert_true(net != null, "proefnet hoort te laden")
	assert_eq(net.kenmerken, Kenmerken.aantal())
	assert_true(net.proef_ok(), "de proef-vector hoort te kloppen")
	var x := PackedFloat32Array()
	x.resize(Kenmerken.aantal())
	x[0] = 0.7
	assert_true(absf(net.waarde(x) - 1.2) < 1e-6, "waarde hoort x0 + 0.5 te zijn, is %f" % net.waarde(x))
	x[0] = -0.3
	assert_true(absf(net.waarde(x) - 0.2) < 1e-6, "relu-tak: waarde hoort x0 + 0.5 te zijn, is %f" % net.waarde(x))
	# Verkeerde kenmerk-versie: de agent weigert en speelt als L2.
	var f := FileAccess.open(pad, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	d.kenmerk_versie = Kenmerken.KENMERK_VERSIE + 1
	f = FileAccess.open("user://l4tests_net_oud.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	NeuraalNet.wis_cache()
	var oud := AgentL4.new("user://l4tests_net_oud.json")
	assert_false(oud.heeft_net(), "een netje van een andere kenmerk-versie hoort geweigerd te worden")


func test_l4_zonder_net_speelt_als_l2() -> void:
	NeuraalNet.wis_cache()
	var a := AgentL4.new("user://bestaat_niet_l4.json")
	assert_false(a.heeft_net())
	var r4 := AgentRunner.new(a, AgentL2.new(), Constants.Doctrine.MUIS, Constants.Doctrine.WOLF, 777, _regels())
	r4.run()
	var r2 := AgentRunner.new(AgentL2.new(), AgentL2.new(), Constants.Doctrine.MUIS, Constants.Doctrine.WOLF, 777, _regels())
	r2.run()
	assert_eq(r4.winner, r2.winner)
	assert_eq(r4.steps, r2.steps)
	assert_eq(Zobrist.state_hash(r4.state()), Zobrist.state_hash(r2.state()), "zonder netje is L4 byte-identiek L2")
	assert_eq(a.beslissingen, 0)


func test_l4_met_net_speelt_legaal() -> void:
	var pad := "user://l4tests_net.json"
	_schrijf_proefnet(pad)
	var a := AgentL4.new(pad)
	assert_true(a.heeft_net())
	var runner := AgentRunner.new(a, AgentL2.new(), Constants.Doctrine.WOLF, Constants.Doctrine.MUIS, 778, _regels())
	runner.max_steps = 2500
	runner.run()
	assert_true(runner.done)
	assert_eq(runner.illegal_count, 0, "L4 mag nooit iets illegaals kiezen")
	assert_eq(runner.fallback_count, 0, "L4 hoort altijd zelf te kiezen")
	assert_true(a.beslissingen > 0, "het netje hoort beslissingen te nemen")
	assert_true(a.kandidaten_totaal >= a.beslissingen)


func test_beslislog_formaat() -> void:
	var pad := "user://l4tests_beslissingen.bin"
	var log := BeslisLog.new(pad)
	assert_true(log.open())
	var s: GameState = _staat_na(40)
	var rij: PackedFloat32Array = Kenmerken.van_staat(s, Constants.PLAYER_1)
	log.schrijf_beslissing(3, 1, Constants.Doctrine.MUIS, [rij, rij, rij], 2)
	log.schrijf_uitslag(3, 2, Constants.Doctrine.MUIS, Constants.Doctrine.WOLF, 9)
	log.sluit()
	assert_eq(log.beslissingen, 1)
	assert_eq(log.kandidaten, 3)
	var f := FileAccess.open(pad, FileAccess.READ)
	f.big_endian = false
	var magic: String = f.get_buffer(4).get_string_from_ascii()
	assert_eq(magic, "FOWL")
	assert_eq(f.get_16(), BeslisLog.FORMAAT_VERSIE)
	assert_eq(f.get_16(), Kenmerken.KENMERK_VERSIE)
	var n: int = f.get_16()
	assert_eq(n, Kenmerken.aantal())
	assert_eq(f.get_8(), 1)
	assert_eq(f.get_32(), 3)
	assert_eq(f.get_8(), 1)
	assert_eq(f.get_8(), int(Constants.Doctrine.MUIS))
	assert_eq(f.get_16(), 3)
	assert_eq(f.get_16(), 2)
	var terug: PackedFloat32Array = f.get_buffer(n * 4).to_float32_array()
	assert_true(terug == rij, "de eerste kandidaat hoort byte-identiek terug te komen")
	f.seek(f.get_position() + n * 4 * 2)
	assert_eq(f.get_8(), 2)
	assert_eq(f.get_32(), 3)
	assert_eq(f.get_8(), 2)
	assert_eq(f.get_8(), int(Constants.Doctrine.MUIS))
	assert_eq(f.get_8(), int(Constants.Doctrine.WOLF))
	assert_eq(f.get_16(), 9)
	assert_true(f.eof_reached() or f.get_position() == f.get_length())
	f.close()
