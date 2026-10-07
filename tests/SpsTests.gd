extends TestSuite

# 4.3.8 (5 oktober, Max: "rock paper scissor bij gelijk spel bid"):
# steen-papier-schaar bij een volledig gelijk initiatief-bod. Waarheidstabel,
# de route door de reducer (keuze, uitslag, gelijk = opnieuw, bevestiging),
# de validator, de geseede keuze bij een kale ack, de knop uit, een ronde met
# een lege hand, de view (de keuze van de ander blijft blind), de serializer,
# de herbouw van de clientstaat, GameSession en de timeout.


func _class_name() -> String:
	return "SpsTests"


## Campagne-staat in de eerste define-ronde: 1 vrije pion per kant (zoals CpTests).
func _define_staat(sps_aan: bool = true) -> GameState:
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {"initiatief_sps": sps_aan}})
	s.phase = Phase.Type.SETUP_1_DEFINE
	s.current_player = 1
	s._spawn_pawn(1, Vector2i(5, 9))
	s._spawn_pawn(2, Vector2i(5, 1))
	s.init_pools()
	return s


## Een kaart met attack 1 en stamina 1 (bod 0 op beide), hp vangt de rest.
func _kaart(s: GameState, speler: int) -> Dictionary:
	return {"hp": int(s.doctrine_data_of(speler).budget) - 2, "stamina": 1, "attack": 1}


## Beide spelers definieren dezelfde kaart: volledig gelijk bod, reveal open.
## Geeft de events van de tweede define terug.
func _naar_reveal(s: GameState) -> Array:
	var r1: Dictionary = Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1)]), 1)
	assert_true(r1.ok, "define P1")
	var r2: Dictionary = Reducer.apply(s, Actions.make_define_cards([_kaart(s, 2)]), 2)
	assert_true(r2.ok, "define P2")
	return r2.events


func _event(events: Array, type: String) -> Dictionary:
	for ev in events:
		if String(ev.type) == type:
			return ev
	return {}


func _ack(s: GameState, speler: int, keuze: int = -1) -> Dictionary:
	var a := Actions.make_ack_reveal(keuze, s.sps_poging if keuze >= 0 else -1)
	var res: Dictionary = Reducer.apply(s, a, speler)
	assert_true(res.ok, "ack van %d (keuze %d): %s" % [speler, keuze, String(res.get("error", ""))])
	return res


func test_winnaar_tabel() -> void:
	# 0 steen, 1 papier, 2 schaar
	assert_eq(Rules.sps_winnaar(1, 0), 1, "papier slaat steen")
	assert_eq(Rules.sps_winnaar(2, 1), 1, "schaar slaat papier")
	assert_eq(Rules.sps_winnaar(0, 2), 1, "steen slaat schaar")
	assert_eq(Rules.sps_winnaar(0, 1), 2)
	assert_eq(Rules.sps_winnaar(1, 2), 2)
	assert_eq(Rules.sps_winnaar(2, 0), 2)
	for k in 3:
		assert_eq(Rules.sps_winnaar(k, k), -1, "gelijk")


func test_versie_en_knop() -> void:
	# Het label volgt de nieuwste knop die aan staat: 4.3.9 (bod per volle hand)
	# boven 4.3.8 (deze regel); de knop zelf staat in het blok.
	assert_eq(RulesConfig.from_dict({"campaign": {}}).rules_version, "4.3.9", "campaign = 4.3.9")
	assert_eq(RulesConfig.from_dict({"campaign": {"initiatief_per_hand": false}}).rules_version, "4.3.8",
		"zonder het bod per hand = 4.3.8")
	assert_eq(RulesConfig.from_dict({"campaign": {"initiatief_per_hand": false, "initiatief_sps": false}}).rules_version, "4.3.7",
		"ook deze knop uit = 4.3.7")
	assert_false(bool(RulesConfig.from_dict({"campaign": {"initiatief_sps": false}}).campaign.initiatief_sps), "de knop staat in het blok")
	assert_eq(RulesConfig.from_dict({"rules_version": "4.3.7", "campaign": {}}).rules_version, "4.3.9",
		"een oud bestand met het blok gaat mee naar de nieuwste versie")


func test_gelijk_bod_opent_steen_papier_schaar() -> void:
	var s := _define_staat()
	var events := _naar_reveal(s)
	assert_true(Phase.is_reveal(s.phase), "reveal")
	assert_true(s.sps_nodig, "volledig gelijk bod: steen-papier-schaar")
	assert_true(Rules.sps_open(s), "er wordt gekozen")
	var cr: Dictionary = _event(events, Reducer.EV_CARDS_REVEALED)
	assert_eq(int(cr.payload.winner), -1, "het reveal-event heeft nog geen winnaar")
	var init: Dictionary = Rules.compute_initiative(s)
	assert_true(bool(init.gelijk))
	assert_eq(int(init.winner), -1, "compute_initiative: -1 zolang er gekozen wordt")


func test_hele_route_papier_slaat_steen() -> void:
	var s := _define_staat()
	_naar_reveal(s)
	var r1: Dictionary = _ack(s, 1, 1)
	assert_false(_event(r1.events, Reducer.EV_SPS_GEKOZEN).is_empty(), "sps_gekozen")
	assert_true(_event(r1.events, Reducer.EV_SPS_UITSLAG).is_empty(), "nog geen uitslag")
	assert_true(bool(s.reveal_acks[1]))
	var r2: Dictionary = _ack(s, 2, 0)
	var uit: Dictionary = _event(r2.events, Reducer.EV_SPS_UITSLAG)
	assert_false(uit.is_empty(), "uitslag na de tweede keuze")
	assert_eq(int(uit.payload.keuzes["1"]), 1)
	assert_eq(int(uit.payload.keuzes["2"]), 0)
	assert_eq(int(uit.payload.winner), 1, "papier slaat steen")
	assert_eq(s.sps_winnaar, 1)
	assert_false(Rules.sps_open(s), "na de winnaar wordt er niet meer gekozen")
	assert_true(Phase.is_reveal(s.phase), "eerst bevestigen")
	assert_false(bool(s.reveal_acks[1]) or bool(s.reveal_acks[2]), "de acks gaan terug op false")
	assert_eq(int(s.sps_vorige[1]), 1, "de laatste uitslag blijft openbaar staan")
	assert_eq(int(Rules.compute_initiative(s).winner), 1)
	_ack(s, 1)
	_ack(s, 2)
	assert_true(Phase.is_linking(s.phase), "bevestigd: koppelen")
	assert_eq(s.initiative_player, 1, "de winnaar begint")
	assert_eq(s.last_initiative_winner, 1)
	assert_false(s.sps_nodig or s.sps_winnaar != -1 or not s.sps_vorige.is_empty(), "sps-velden leeg")


func test_zelfde_keuze_is_opnieuw() -> void:
	var s := _define_staat()
	_naar_reveal(s)
	_ack(s, 1, 2)
	var r: Dictionary = _ack(s, 2, 2)
	assert_eq(int(_event(r.events, Reducer.EV_SPS_UITSLAG).payload.winner), -1, "allebei schaar: gelijk")
	assert_eq(s.sps_poging, 1, "poging 1")
	assert_true(Rules.sps_open(s), "opnieuw kiezen")
	_ack(s, 1, 0)
	_ack(s, 2, 2)
	assert_eq(s.sps_winnaar, 1, "steen slaat schaar")
	_ack(s, 2)
	_ack(s, 1)
	assert_true(Phase.is_linking(s.phase))
	assert_eq(s.initiative_player, 1)


func test_validator() -> void:
	var s := _define_staat()
	_naar_reveal(s)
	var legal: Array = Validator.legal_actions(s, 1)
	assert_eq(legal.size(), 4, "kaal plus drie keuzes")
	assert_false(legal[0].has("sps"), "de kale ack vooraan (L1 laat de engine kiezen)")
	for k in 3:
		assert_eq(int(legal[k + 1].sps), k)
	assert_false(Validator.is_legal(s, Actions.make_ack_reveal(3, 0), 1).legal, "3 is geen keuze")
	assert_false(Validator.is_legal(s, Actions.make_ack_reveal(0, 1), 1).legal, "verkeerde poging")
	assert_true(Validator.is_legal(s, Actions.make_ack_reveal(0, 0), 1).legal)
	_ack(s, 1, 0)
	assert_false(Validator.is_legal(s, Actions.make_ack_reveal(1, 0), 1).legal, "al gekozen")
	_ack(s, 2, 1)
	assert_false(Validator.is_legal(s, Actions.make_ack_reveal(0, 0), 1).legal, "na de winnaar alleen kaal")
	assert_true(Validator.is_legal(s, Actions.make_ack_reveal(), 1).legal)
	assert_eq(Validator.legal_actions(s, 1).size(), 1, "bevestigen: alleen de kale ack")
	# Zonder campaign-blok (4.1/4.3.0) bestaat de keuze niet.
	var oud := GameState.new()
	oud.rules = RulesConfig.from_dict({})
	oud.phase = Phase.Type.SETUP_1_REVEAL
	oud.reveal_acks = {1: false, 2: false}
	assert_false(Validator.is_legal(oud, Actions.make_ack_reveal(0), 1).legal, "geen keuze buiten de campagne")
	assert_false(Actions.is_wellformed({"type": Actions.ACK_REVEAL, "sps": "1"}), "sps moet een int zijn")


func test_kale_ack_kiest_geseed_en_volgorde_onafhankelijk() -> void:
	var s := _define_staat()
	_naar_reveal(s)
	var a: GameState = s.clone()
	var b: GameState = s.clone()
	var c: GameState = Serializer.state_from_dict(JSON.parse_string(JSON.stringify(Serializer.state_to_dict(s))))
	Reducer.apply(a, Actions.make_ack_reveal(), 1)
	Reducer.apply(b, Actions.make_ack_reveal(), 2)   # andere volgorde
	Reducer.apply(b, Actions.make_ack_reveal(), 1)
	Reducer.apply(c, Actions.make_ack_reveal(), 1)
	var ka: int = int(a.sps_keuzes.get(1, a.sps_vorige.get(1, -1)))
	var kb: int = int(b.sps_vorige.get(1, b.sps_keuzes.get(1, -1)))
	var kc: int = int(c.sps_keuzes.get(1, c.sps_vorige.get(1, -1)))
	assert_true(ka >= 0 and ka <= 2, "de engine kiest 0..2")
	assert_eq(kb, ka, "dezelfde keuze, welke speler ook eerst ackte")
	assert_eq(kc, ka, "dezelfde keuze na een serializer-rondreis (server, replay)")


func test_knop_uit_houdt_de_oude_terugval() -> void:
	var s := _define_staat(false)
	assert_false(Rules.sps_aan(s), "knop uit")
	var events := _naar_reveal(s)
	assert_false(s.sps_nodig, "knop uit: geen steen-papier-schaar")
	assert_eq(int(_event(events, Reducer.EV_CARDS_REVEALED).payload.winner), 1, "cyclus 1, ronde 1: speler 1")
	assert_eq(Validator.legal_actions(s, 1).size(), 1, "alleen de kale ack")
	_ack(s, 1)
	_ack(s, 2)
	assert_true(Phase.is_linking(s.phase))
	assert_eq(s.initiative_player, 1)


func test_lege_hand_geen_steen_papier_schaar() -> void:
	var s := _define_staat()
	# De pion van P2 is al gekoppeld: hij definieert niets, dus een lege hand.
	var p2: Pawn = null
	for p in s.pawns.values():
		if p.owner_id == 2:
			p2 = p
	var c := Card.new(s.next_card_id(), 2, 1, 3, 1, 1)
	s.all_cards[c.id] = c
	p2.link_card(c)
	var r: Dictionary = Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1)]), 1)
	assert_true(r.ok)
	assert_true(Phase.is_reveal(s.phase), "P2 hoeft niets: meteen de reveal")
	assert_true(bool(Rules.compute_initiative(s).gelijk), "0 tegen 0: gelijk bod")
	assert_false(s.sps_nodig, "maar een lege hand: geen keuze om niets")
	assert_eq(int(_event(r.events, Reducer.EV_CARDS_REVEALED).payload.winner), 1, "de oude terugval")


func test_view_houdt_de_keuze_van_de_ander_blind() -> void:
	var s := _define_staat()
	_naar_reveal(s)
	var r: Dictionary = _ack(s, 1, 2)
	var v2: Dictionary = View.for_player(s, 2)
	assert_eq(int(v2.own_sps_keuze), -1, "P2 ziet zijn eigen (nog geen) keuze")
	assert_true(bool(v2.enemy_sps_gekozen), "P2 ziet DAT P1 koos")
	var tekst := JSON.stringify(MatchLog._jsonify(v2))
	assert_false(tekst.contains("sps_keuzes"), "geen keuzelijst in de view")
	var v1: Dictionary = View.for_player(s, 1)
	assert_eq(int(v1.own_sps_keuze), 2, "P1 ziet zijn eigen keuze")
	for ev in View.client_events(r.events):
		if String(ev.type) == Reducer.EV_SPS_GEKOZEN:
			assert_eq((ev.payload as Dictionary).keys(), ["player_id"], "sps_gekozen draagt alleen wie koos")


func test_serializer_rondreis_en_rust() -> void:
	var rust := _define_staat()
	var d0: Dictionary = Serializer.state_to_dict(rust)
	assert_false(d0.has("sps") or d0.has("sps_keuzes"), "buiten een sps-ronde geen sleutels (hash-identiek)")
	var s := _define_staat()
	_naar_reveal(s)
	_ack(s, 1, 2)
	var d: Dictionary = JSON.parse_string(JSON.stringify(Serializer.state_to_dict(s)))
	var t: GameState = Serializer.state_from_dict(d)
	assert_eq(Zobrist.state_hash(t), Zobrist.state_hash(s), "rondreis midden in het kiezen: dezelfde hash")
	assert_eq(int(t.sps_keuzes[1]), 2)
	assert_true(t.sps_nodig and Rules.sps_open(t))


func test_clientstaat_herbouwt_de_stand_zonder_de_keuze_van_de_ander() -> void:
	var s := _define_staat()
	_naar_reveal(s)
	_ack(s, 1, 2)
	var recon: GameState = ClientState.uit_view(JSON.parse_string(JSON.stringify(MatchLog._jsonify(View.for_player(s, 2)))))
	assert_true(recon.sps_nodig)
	assert_eq(recon.sps_winnaar, -1)
	assert_eq(recon.sps_poging, s.sps_poging)
	assert_true(recon.sps_keuzes.is_empty(), "de keuze van P1 staat er niet in")
	var echt: Array = Validator.legal_actions(s, 2)
	var herbouwd: Array = Validator.legal_actions(recon, 2)
	assert_eq(JSON.stringify(herbouwd), JSON.stringify(echt), "dezelfde legale acties voor P2")


func test_gamesession_kiest_en_acknowledge_reveal_loopt_door() -> void:
	var s := _define_staat()
	_naar_reveal(s)
	var oud: GameState = GameSession.state
	GameSession.state = s
	var uitslagen: Array = []
	var luister := func(keuzes: Dictionary, winner: int, poging: int) -> void:
		uitslagen.append([keuzes, winner, poging])
	GameSession.sps_uitslag.connect(luister)
	GameSession.submit_ack_reveal(1, 1)
	GameSession.submit_ack_reveal(2, 0)
	assert_eq(uitslagen.size(), 1, "een uitslag")
	if uitslagen.size() == 1:
		assert_eq(int(uitslagen[0][1]), 1, "papier slaat steen")
		assert_eq(int((uitslagen[0][0] as Dictionary)["1"]), 1, "keuzes met string-sleutels")
	GameSession.acknowledge_reveal()
	assert_true(Phase.is_linking(s.phase), "acknowledge_reveal bevestigt en opent het koppelen")
	# En een kale acknowledge_reveal midden in het kiezen loopt in een keer door.
	var s2 := _define_staat()
	_naar_reveal(s2)
	GameSession.state = s2
	GameSession.acknowledge_reveal()
	assert_true(Phase.is_linking(s2.phase), "de engine kiest voor beide en het koppelen begint")
	GameSession.sps_uitslag.disconnect(luister)
	GameSession.state = oud


func test_timeout_maakt_de_reveal_in_een_claim_af() -> void:
	var s := _define_staat()
	s.rules.clock = {"bank_sec": 60, "increment_sec": 5, "reconnect_grace_sec": 20}
	Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1)]), 1, 1000)
	Reducer.apply(s, Actions.make_define_cards([_kaart(s, 2)]), 2, 2000)
	assert_true(Rules.sps_open(s))
	Reducer.apply(s, Actions.make_ack_reveal(1, 0), 1, 3000)
	var res: Dictionary = Reducer.apply(s, Actions.make_claim_timeout(), 1, s.turn_deadline + 500)
	assert_true(res.ok, "claim")
	assert_true(Phase.is_linking(s.phase), "een claim kiest voor P2, bevestigt en opent het koppelen")


## Speel ronde 1 uit tot de lege reveal van ronde 2 (beide pionnen gekoppeld,
## niemand heeft nog iets te definieren).
func _naar_lege_reveal_ronde2(s: GameState, t0: int = -1) -> void:
	var t: int = t0
	Reducer.apply(s, Actions.make_define_cards([_kaart(s, 1)]), 1, t)
	Reducer.apply(s, Actions.make_define_cards([_kaart(s, 2)]), 2, t)
	Reducer.apply(s, Actions.make_ack_reveal(1, 0), 1, t)
	Reducer.apply(s, Actions.make_ack_reveal(0, 0), 2, t)
	Reducer.apply(s, Actions.make_ack_reveal(), 1, t)
	Reducer.apply(s, Actions.make_ack_reveal(), 2, t)
	var veilig := 0
	while Phase.is_linking(s.phase) and veilig < 10:
		var opties: Array = Validator.legal_actions(s, s.current_player)
		if opties.is_empty():
			break
		Reducer.apply(s, opties[0], s.current_player, t)
		veilig += 1


func test_timeout_claim_blijft_binnen_zijn_eigen_reveal() -> void:
	# Review 5 oktober: de claim-lus mag de lege reveal van de volgende ronde
	# niet meenemen (daarvoor stond de staat daarna in ACTION in plaats van in
	# de reveal van ronde 3).
	var s := _define_staat()
	s.rules.clock = {"bank_sec": 60, "increment_sec": 5, "reconnect_grace_sec": 20}
	_naar_lege_reveal_ronde2(s, 1000)
	assert_eq(s.round_number, 2, "ronde 2")
	assert_true(Phase.is_reveal(s.phase), "lege reveal van ronde 2")
	assert_false(s.sps_nodig, "lege handen: geen steen-papier-schaar")
	Reducer.apply(s, Actions.make_ack_reveal(), 1, 2000)
	var res: Dictionary = Reducer.apply(s, Actions.make_claim_timeout(), 1, s.turn_deadline + 500)
	assert_true(res.ok, "claim")
	assert_eq(s.round_number, 3, "door naar ronde 3")
	assert_true(Phase.is_reveal(s.phase), "maar de reveal van ronde 3 wacht weer op beide spelers")


func test_acknowledge_reveal_blijft_binnen_zijn_eigen_reveal() -> void:
	var s := _define_staat()
	_naar_lege_reveal_ronde2(s)
	assert_true(Phase.is_reveal(s.phase) and s.round_number == 2)
	var oud: GameState = GameSession.state
	GameSession.state = s
	GameSession.acknowledge_reveal()
	assert_eq(s.round_number, 3)
	assert_true(Phase.is_reveal(s.phase), "de reveal van ronde 3 krijgt de mens nog te zien")
	GameSession.state = oud
