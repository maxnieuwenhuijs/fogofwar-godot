extends TestSuite

# F1.1 — agents op views. De kern-checks uit het masterplan:
# (1) L0 speelt volledige partijen zonder crash of illegale actie,
# (2) de view-reconstructie geeft puntschattingen (geen "?"-sentinels),
# (3) L1 pakt een kill als die er is,
# (4) de B8-ablatie draait: L2-op-view vs L2-full-state, delta wordt gelogd.


func _class_name() -> String:
	return "AgentTests"


## Begrensde regels zodat random partijen gegarandeerd eindigen.
func _arena_rules(limiet: int = 12) -> RulesConfig:
	var r := RulesConfig.new()
	r.cycle_limit = limiet
	return r


func test_l0_speelt_20_volledige_partijen_legaal() -> void:
	var doctrines: Array = Constants.DOCTRINE_DATA.keys()
	var klaar: int = 0
	for g in 20:
		var runner := AgentRunner.new(AgentL0.new(), AgentL0.new(),
			doctrines[g % doctrines.size()], doctrines[(g + 3) % doctrines.size()],
			9000 + g, _arena_rules())
		runner.run()
		assert_true(runner.done, "partij %d hoort te eindigen" % g)
		assert_eq(runner.illegal_count, 0, "partij %d: L0 mag nooit iets illegaals kiezen" % g)
		assert_eq(runner.fallback_count, 0, "partij %d: L0 hoort altijd zelf te kiezen" % g)
		assert_true(runner.winner in [-1, 1, 2])
		klaar += 1
	assert_eq(klaar, 20)


func test_reconstructie_geeft_puntschatting() -> void:
	var s := GameState.new()
	s.doctrines[Constants.PLAYER_2] = Constants.Doctrine.VOS
	s.phase = Phase.Type.ACTION
	# Twee onthulde vijandelijke kaarten (3/2/2 en 1/2/4) -> schatting 2/2/3.
	var pawn: Pawn = s._spawn_pawn(2, Vector2i(5, 5))
	var c1 := Card.new(s.next_card_id(), 2, 1, 3, 2, 2)
	var c2 := Card.new(s.next_card_id(), 2, 1, 1, 2, 4)
	s.all_cards[c1.id] = c1
	s.all_cards[c2.id] = c2
	s.cards_revealed[2] = [c1, c2]
	pawn.link_card(c1)
	pawn.card_revealed = false  # gedekt
	var extra: Pawn = s._spawn_pawn(2, Vector2i(7, 5))
	extra.link_card(c2)
	extra.card_revealed = false
	var view: Dictionary = View.for_player(s, 1)
	assert_eq(view.pawns[str(pawn.id)].current_hp, View.HIDDEN, "view verbergt")
	var recon: GameState = Agent.reconstruct_state(view)
	var rp: Pawn = recon.pawns[pawn.id]
	assert_eq(rp.current_hp, 2, "puntschatting hp = round((3+1)/2)")
	assert_eq(rp.remaining_stamina, 2)
	assert_eq(rp.attack_value, 3, "puntschatting atk = round((2+4)/2)")
	assert_true(rp.is_active, "actief-zijn is publieke info")
	# Eigen pionnen en onthulde info blijven exact.
	var eigen: Pawn = s._spawn_pawn(1, Vector2i(2, 2))
	var ec := Card.new(s.next_card_id(), 1, 1, 5, 1, 1)
	s.all_cards[ec.id] = ec
	eigen.link_card(ec)
	recon = Agent.reconstruct_state(View.for_player(s, 1))
	assert_eq(recon.pawns[eigen.id].current_hp, 5, "eigen stats exact")


func test_l1_pakt_de_kill() -> void:
	var s := GameState.new()
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var aanvaller: Pawn = s._spawn_pawn(1, Vector2i(5, 5))
	var kaart := Card.new(s.next_card_id(), 1, 1, 3, 3, 3)
	s.all_cards[kaart.id] = kaart
	aanvaller.link_card(kaart)
	var zwak: Pawn = s._spawn_pawn(2, Vector2i(5, 4))
	var zk := Card.new(s.next_card_id(), 2, 1, 2, 2, 3)
	s.all_cards[zk.id] = zk
	zwak.link_card(zk)  # 2 HP, aanvaller heeft 3 attack: kill beschikbaar
	s.cards_revealed[2] = [zk]
	s._spawn_pawn(2, Vector2i(0, 0))
	var agent := AgentL1.new()
	agent.player_id = 1
	var legal: Array = Validator.legal_actions(s, 1)
	var keuze: Dictionary = agent.decide(View.for_player(s, 1), legal, SeededRng.new(1))
	assert_eq(String(keuze.type), Actions.MELEE, "L1 hoort de kill te pakken")
	assert_eq(int(keuze.defender_id), zwak.id)


func test_l2_ablatie_view_vs_full_state() -> void:
	# B8: zelfde eval, één kant ziet fog (view), de ander alles (full_state).
	# Krokodil vs Krokodil maximaliseert de verborgen informatie. De delta is
	# een MEETWAARDE (gelogd), geen assert — de arena (F1.6) trekt conclusies.
	var view_wint: int = 0
	var full_wint: int = 0
	var remises: int = 0
	for g in 4:
		var kijker := AgentL2.new()
		var alwetend := AgentL2.new()
		alwetend.full_state = true
		# Wissel van kant per partij (kleurvoordeel uitmiddelen).
		var runner: AgentRunner
		if g % 2 == 0:
			runner = AgentRunner.new(kijker, alwetend, Constants.Doctrine.VOS, Constants.Doctrine.VOS, 7000 + g, _arena_rules(8))
		else:
			runner = AgentRunner.new(alwetend, kijker, Constants.Doctrine.VOS, Constants.Doctrine.VOS, 7000 + g, _arena_rules(8))
		runner.max_steps = 900
		runner.run()
		var kijker_speler: int = 1 if g % 2 == 0 else 2
		if runner.winner == -1:
			remises += 1
		elif runner.winner == kijker_speler:
			view_wint += 1
		else:
			full_wint += 1
		assert_true(runner.done)
		assert_eq(runner.illegal_count, 0, "L2 mag nooit iets illegaals kiezen (partij %d)" % g)
	print("    [ABLATIE] L2-view %d — L2-full_state %d — remise %d (4 potjes, Krokodil-spiegel)" % [
		view_wint, full_wint, remises])
	assert_eq(view_wint + full_wint + remises, 4)
