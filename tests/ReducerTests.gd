extends TestSuite

# F0.4b — reducer-tests: per-speler ACK (het gedichte single-ack-gat) en de
# fold-test: een handgeschreven actielijst van opstelling t/m actiefase,
# rechtstreeks op Reducer.apply — zónder GameSession-Node. Dit is het bewijs
# dat de kern standalone draait (arena F1, workers F4).


func _class_name() -> String:
	return "ReducerTests"


## Kale match-staat zoals de server/arena hem zou opzetten: geen Node.
func _fresh_state(d1: int = Constants.Doctrine.MENS, d2: int = Constants.Doctrine.MENS) -> GameState:
	var s := GameState.new()
	s.doctrines[Constants.PLAYER_1] = d1
	s.doctrines[Constants.PLAYER_2] = d2
	s.phase = Phase.Type.PLACEMENT
	return s


func _apply_ok(state: GameState, action: Dictionary, player: int, label: String) -> Dictionary:
	var res: Dictionary = Reducer.apply(state, action, player)
	assert_true(res.ok, "%s hoort te slagen (kreeg: %s)" % [label, res.error])
	return res


func test_per_player_ack() -> void:
	var s := _fresh_state()
	_apply_ok(s, Actions.make_place(s.default_placement(1)), 1, "place p1")
	_apply_ok(s, Actions.make_place(s.default_placement(2)), 2, "place p2")
	var cards: Array = [{"hp": 3, "stamina": 2, "attack": 2},
		{"hp": 2, "stamina": 2, "attack": 3}, {"hp": 2, "stamina": 3, "attack": 2}]
	_apply_ok(s, Actions.make_define_cards(cards), 1, "define p1")
	_apply_ok(s, Actions.make_define_cards(cards), 2, "define p2")
	assert_eq(s.phase, Phase.Type.SETUP_1_REVEAL)
	# Eén ack → fase blijft staan.
	_apply_ok(s, Actions.make_ack_reveal(), 1, "ack p1")
	assert_eq(s.phase, Phase.Type.SETUP_1_REVEAL, "na één ack blijft de reveal staan")
	# Dubbele ack van dezelfde speler → geweigerd.
	var dubbel: Dictionary = Reducer.apply(s, Actions.make_ack_reveal(), 1)
	assert_false(dubbel.ok, "tweede ack van dezelfde speler is illegaal")
	assert_eq(dubbel.error, "Al bevestigd")
	# Tweede speler ackt → door naar koppelen.
	_apply_ok(s, Actions.make_ack_reveal(), 2, "ack p2")
	assert_true(Phase.is_linking(s.phase), "na beide acks begint het koppelen")


func test_fold_setup_to_action_without_node() -> void:
	# Handgeschreven actielijst: volledige cyclus-setup, puur via Reducer.apply.
	var s := _fresh_state()
	var acties_gedaan := 0
	_apply_ok(s, Actions.make_place(s.default_placement(1)), 1, "place p1")
	assert_eq(s.phase, Phase.Type.PLACEMENT, "wachten op p2")
	_apply_ok(s, Actions.make_place(s.default_placement(2)), 2, "place p2")
	assert_eq(s.phase, Phase.Type.SETUP_1_DEFINE, "beide opstellingen binnen -> define r1")
	# 3 setup-rondes: define (commit-gate) -> reveal -> acks -> koppelen.
	var cards: Array = [{"hp": 3, "stamina": 2, "attack": 2},
		{"hp": 2, "stamina": 2, "attack": 3}, {"hp": 2, "stamina": 3, "attack": 2}]
	for ronde in [1, 2, 3]:
		assert_eq(s.round_number, ronde)
		assert_true(Phase.is_define(s.phase), "ronde %d start met define" % ronde)
		_apply_ok(s, Actions.make_define_cards(cards), 1, "define p1 r%d" % ronde)
		assert_true(Phase.is_define(s.phase), "commit-gate: wachten op p2")
		_apply_ok(s, Actions.make_define_cards(cards), 2, "define p2 r%d" % ronde)
		assert_true(Phase.is_reveal(s.phase), "beide binnen -> reveal r%d" % ronde)
		_apply_ok(s, Actions.make_ack_reveal(), 1, "ack p1 r%d" % ronde)
		_apply_ok(s, Actions.make_ack_reveal(), 2, "ack p2 r%d" % ronde)
		assert_true(Phase.is_linking(s.phase), "beide acks -> koppelen r%d" % ronde)
		# Koppelen tot de fase doorschuift (staartkoppel-volgorde via de validator).
		var guard := 0
		while Phase.is_linking(s.phase) and guard < 20:
			guard += 1
			var speler: int = s.current_player
			var opties: Array = Validator.legal_actions(s, speler)
			assert_true(not opties.is_empty(), "koppelbeurt zonder opties mag niet bestaan")
			_apply_ok(s, opties[0], speler, "link r%d" % ronde)
			acties_gedaan += 1
	# Na ronde 3: de actiefase, initiatiefhouder aan zet.
	assert_eq(s.phase, Phase.Type.ACTION, "na 3 rondes begint de actiefase")
	assert_eq(s.current_player, s.initiative_player)
	assert_eq(acties_gedaan, 18, "3 rondes x 3 kaarten x 2 spelers = 18 koppelingen")
	assert_eq(s.get_active_pawns_for(1).size(), 9)
	assert_eq(s.get_active_pawns_for(2).size(), 9)
	# En de reducer speelt ook gewoon een zet zonder Node.
	var zetten: Array = Validator.legal_actions(s, s.current_player)
	assert_true(not zetten.is_empty())
	_apply_ok(s, zetten[0], s.current_player, "eerste actiefase-zet")


func test_resign_in_elke_fase() -> void:
	# PLACEMENT: P1 geeft op → P2 wint.
	var s := _fresh_state()
	_apply_ok(s, Actions.make_resign(), 1, "resign in placement")
	assert_eq(s.phase, Phase.Type.GAME_OVER)
	assert_eq(s.winner, Constants.PLAYER_2)
	# DEFINE: P2 geeft op → P1 wint.
	s = _fresh_state()
	_apply_ok(s, Actions.make_place(s.default_placement(1)), 1, "place p1")
	_apply_ok(s, Actions.make_place(s.default_placement(2)), 2, "place p2")
	assert_true(Phase.is_define(s.phase))
	_apply_ok(s, Actions.make_resign(), 2, "resign in define")
	assert_eq(s.winner, Constants.PLAYER_1)
	# REVEAL, LINKING en ACTION: doorspelen tot elke fase en opgeven.
	var cards: Array = [{"hp": 3, "stamina": 2, "attack": 2},
		{"hp": 2, "stamina": 2, "attack": 3}, {"hp": 2, "stamina": 3, "attack": 2}]
	for doel_fase in ["reveal", "linking", "action"]:
		s = _fresh_state()
		_apply_ok(s, Actions.make_place(s.default_placement(1)), 1, "place p1")
		_apply_ok(s, Actions.make_place(s.default_placement(2)), 2, "place p2")
		for ronde in [1, 2, 3]:
			_apply_ok(s, Actions.make_define_cards(cards), 1, "define p1")
			_apply_ok(s, Actions.make_define_cards(cards), 2, "define p2")
			if doel_fase == "reveal" and ronde == 1:
				break
			_apply_ok(s, Actions.make_ack_reveal(), 1, "ack p1")
			_apply_ok(s, Actions.make_ack_reveal(), 2, "ack p2")
			if doel_fase == "linking" and ronde == 1:
				break
			var guard := 0
			while Phase.is_linking(s.phase) and guard < 20:
				guard += 1
				_apply_ok(s, Validator.legal_actions(s, s.current_player)[0], s.current_player, "link")
		_apply_ok(s, Actions.make_resign(), 1, "resign in " + doel_fase)
		assert_eq(s.winner, Constants.PLAYER_2, "opgeven in %s geeft P2 de winst" % doel_fase)
	# GAME_OVER: opgeven kan niet meer.
	var na: Dictionary = Reducer.apply(s, Actions.make_resign(), 2)
	assert_false(na.ok, "resign na afloop is illegaal")


## V0 (3 augustus): de cycluslimiet en de tiebreak zijn vervangen door de
## uitputtingsklok. Deze twee tests legden het oude gedrag vast en zijn
## omgebouwd naar de honger. Wat ze bewaken is hetzelfde: een partij MOET
## eindigen, en de uitkomst mag niet van de invoegvolgorde afhangen.

func test_honger_eet_de_achterhoede() -> void:
	# De pion die het VERST van zijn doelhaven staat verhongert het eerst.
	# P1 moet naar y=0, dus zijn achterhoede staat op een hoge y.
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.honger_vanaf_cyclus = 1
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var mover: Pawn = s._spawn_pawn(1, Vector2i(5, 8))
	var card := Card.new(s.next_card_id(), 1, 1, 3, 1, 1)  # speed 1: een stap en klaar
	s.all_cards[card.id] = card
	mover.link_card(card)
	var voorhoede: Pawn = s._spawn_pawn(1, Vector2i(5, 1))   # bijna in de haven
	var achterhoede: Pawn = s._spawn_pawn(1, Vector2i(5, 10))  # helemaal achteraan
	s._spawn_pawn(2, Vector2i(0, 5))
	s._spawn_pawn(2, Vector2i(10, 5))
	var res: Dictionary = Reducer.apply(s, Actions.make_move(mover.id, Vector2i(5, 7)), 1)
	assert_true(res.ok)
	assert_true(achterhoede.is_eliminated, "de achterste pion van P1 verhongert")
	assert_false(voorhoede.is_eliminated, "de voorhoede blijft staan")


func test_honger_kiest_deterministisch_bij_gelijke_afstand() -> void:
	# Twee pionnen even ver: de laagste id gaat, ongeacht invoegvolgorde.
	var uitslagen: Array = []
	for volgorde in [0, 1]:
		var s := GameState.new()
		s.rules = RulesConfig.new()
		s.rules.honger_vanaf_cyclus = 1
		s.phase = Phase.Type.ACTION
		s.current_player = 1
		var mover: Pawn = s._spawn_pawn(1, Vector2i(5, 8))
		var card := Card.new(s.next_card_id(), 1, 1, 3, 1, 1)
		s.all_cards[card.id] = card
		mover.link_card(card)
		# Twee even ver weg (beide y=10), in wisselende volgorde geplaatst.
		var a: Pawn = s._spawn_pawn(1, Vector2i(3, 10) if volgorde == 0 else Vector2i(7, 10))
		var b: Pawn = s._spawn_pawn(1, Vector2i(7, 10) if volgorde == 0 else Vector2i(3, 10))
		s._spawn_pawn(2, Vector2i(0, 5))
		Reducer.apply(s, Actions.make_move(mover.id, Vector2i(5, 7)), 1)
		uitslagen.append("a" if a.is_eliminated else ("b" if b.is_eliminated else "geen"))
	assert_eq(uitslagen[0], "a", "de laagste pion-id verhongert")
	assert_eq(uitslagen[1], "a", "en dat hangt niet aan de invoegvolgorde")


func test_honger_beslist_de_partij_zonder_remise() -> void:
	# P2 heeft nog een pion, P1 verhongert zijn laatste: P2 wint. Geen -1.
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.honger_vanaf_cyclus = 1
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var mover: Pawn = s._spawn_pawn(1, Vector2i(5, 8))
	var card := Card.new(s.next_card_id(), 1, 1, 3, 1, 1)
	s.all_cards[card.id] = card
	mover.link_card(card)
	s._spawn_pawn(2, Vector2i(0, 5))
	s._spawn_pawn(2, Vector2i(10, 5))
	var res: Dictionary = Reducer.apply(s, Actions.make_move(mover.id, Vector2i(5, 7)), 1)
	assert_true(res.ok)
	assert_eq(s.phase, Phase.Type.GAME_OVER, "de honger maakt een einde aan de partij")
	assert_eq(s.winner, Constants.PLAYER_2, "P1 heeft geen pionnen meer: P2 wint")
	assert_eq(String(s.eind_reden), "eliminatie", "en dat is een eliminatie, geen remise")


func test_honger_staat_uit_op_nul() -> void:
	# honger_vanaf_cyclus 0 = geen klok: niemand verhongert.
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.honger_vanaf_cyclus = 0
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var mover: Pawn = s._spawn_pawn(1, Vector2i(5, 8))
	var card := Card.new(s.next_card_id(), 1, 1, 3, 1, 1)
	s.all_cards[card.id] = card
	mover.link_card(card)
	var achterhoede: Pawn = s._spawn_pawn(1, Vector2i(5, 10))
	s._spawn_pawn(2, Vector2i(0, 5))
	Reducer.apply(s, Actions.make_move(mover.id, Vector2i(5, 7)), 1)
	assert_false(achterhoede.is_eliminated, "zonder klok verhongert er niets")


func test_resign_telt_als_eliminatie() -> void:
	# V0: opgeven levert de winnaar het eliminatie-tarief op, en de reden staat
	# in de staat zodat de campagnelaag hem niet hoeft te raden.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {}})
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	s._spawn_pawn(1, Vector2i(5, 8))
	s._spawn_pawn(2, Vector2i(5, 3))
	var res: Dictionary = Reducer.apply(s, Actions.make_resign(), 1)
	assert_true(res.ok)
	assert_eq(s.winner, Constants.PLAYER_2, "wie opgeeft verliest")
	assert_eq(String(s.eind_reden), "resign")
	var tarief := 0
	for ev in res.events:
		if String(ev.type) == Reducer.EV_CP_EARNED:
			tarief = int(ev.payload.amount)
	assert_eq(tarief, int(s.rules.campaign.get("cp_eliminatie", 4)),
		"de winnaar krijgt het eliminatie-tarief, niet niets")


func test_gelijk_bod_geeft_p1_initiatief_in_cyclus1() -> void:
	# Identieke kaartsets -> gelijk bod -> deterministisch: P1 (cyclus 1 ronde 1).
	var s := _fresh_state()
	_apply_ok(s, Actions.make_place(s.default_placement(1)), 1, "place p1")
	_apply_ok(s, Actions.make_place(s.default_placement(2)), 2, "place p2")
	var cards: Array = [{"hp": 3, "stamina": 2, "attack": 2},
		{"hp": 2, "stamina": 2, "attack": 3}, {"hp": 2, "stamina": 3, "attack": 2}]
	_apply_ok(s, Actions.make_define_cards(cards), 1, "define p1")
	_apply_ok(s, Actions.make_define_cards(cards), 2, "define p2")
	_apply_ok(s, Actions.make_ack_reveal(), 1, "ack p1")
	_apply_ok(s, Actions.make_ack_reveal(), 2, "ack p2")
	assert_eq(s.initiative_player, Constants.PLAYER_1)


# --- 4.1.10-hr: kaarten definiëren begrensd door vrije pionnen ---------------

func _pion_met_kaart(s: GameState, owner: int, pos: Vector2i) -> Pawn:
	var pawn: Pawn = s._spawn_pawn(owner, pos)
	var kaart := Card.new(s.next_card_id(), owner, 1, 3, 2, 2)
	s.all_cards[kaart.id] = kaart
	pawn.link_card(kaart)
	return pawn


func test_define_begrensd_door_vrije_pionnen() -> void:
	var s := GameState.new()
	s.phase = Phase.Type.SETUP_2_DEFINE
	s.round_number = 2
	# P1: 2 vrije pionnen + 1 gekoppelde -> verwacht 2 kaarten (Varken: 3).
	s._spawn_pawn(1, Vector2i(5, 9))
	s._spawn_pawn(1, Vector2i(6, 9))
	_pion_met_kaart(s, 1, Vector2i(4, 9))
	# P2: 3 vrije -> verwacht gewoon 3.
	s._spawn_pawn(2, Vector2i(5, 1))
	s._spawn_pawn(2, Vector2i(6, 1))
	s._spawn_pawn(2, Vector2i(7, 1))
	assert_eq(Validator.expected_define_count(s, 1), 2)
	assert_eq(Validator.expected_define_count(s, 2), 3)
	var drie: Array = [{"hp": 3, "stamina": 2, "attack": 2},
		{"hp": 2, "stamina": 2, "attack": 3}, {"hp": 2, "stamina": 3, "attack": 2}]
	var twee: Array = [{"hp": 3, "stamina": 2, "attack": 2}, {"hp": 2, "stamina": 2, "attack": 3}]
	var res: Dictionary = Reducer.apply(s, Actions.make_define_cards(drie), 1)
	assert_false(res.ok, "3 kaarten met 2 vrije pionnen moet geweigerd worden")
	assert_eq(res.error, "Moet 2 kaarten definiëren")
	res = Reducer.apply(s, Actions.make_define_cards(twee), 1)
	assert_true(res.ok, "2 kaarten past precies")
	assert_true(Phase.is_define(s.phase), "P2 moet nog")
	res = Reducer.apply(s, Actions.make_define_cards(drie), 2)
	assert_true(res.ok)
	assert_true(Phase.is_reveal(s.phase), "beide binnen -> reveal")


func test_define_zonder_vrije_pionnen_slaat_ronde_over() -> void:
	var s := GameState.new()
	s.phase = Phase.Type.SETUP_2_DEFINE
	s.round_number = 2
	_pion_met_kaart(s, 1, Vector2i(5, 9))  # P1: alles gekoppeld -> 0 vrij
	s._spawn_pawn(2, Vector2i(5, 1))       # P2: 1 vrij
	var res: Dictionary = Reducer.apply(s, Actions.make_define_cards(
		[{"hp": 3, "stamina": 2, "attack": 2}]), 1)
	assert_false(res.ok, "definiëren zonder vrije pionnen is illegaal")
	assert_eq(res.error, "Geen vrije pionnen — deze ronde sla je over")
	# De tegenstander gaat gewoon: één define en de fase schuift door.
	res = Reducer.apply(s, Actions.make_define_cards(
		[{"hp": 3, "stamina": 2, "attack": 2}]), 2)
	assert_true(res.ok)
	assert_true(Phase.is_reveal(s.phase), "P1 is vrijgesteld; alleen P2 telde voor de gate")


func test_define_beide_zonder_vrije_pionnen_schuift_meteen_door() -> void:
	var s := GameState.new()
	s.phase = Phase.Type.SETUP_2_DEFINE
	s.round_number = 2
	_pion_met_kaart(s, 1, Vector2i(5, 9))
	_pion_met_kaart(s, 2, Vector2i(5, 1))
	# De fase-entry-gate (aangeroepen bij het betreden van elke define-fase).
	Reducer._check_define_gate(s, [])
	assert_true(Phase.is_reveal(s.phase), "niemand hoeft te definiëren -> meteen door")


# =========================================================================
# F4.0 -- blinde factie-keuze in PRE_GAME (de eerste online-bouwsteen)
# =========================================================================

func test_f4_doctrine_keuze_blinde_gate() -> void:
	var s := GameState.new()  # verse staat start in PRE_GAME
	assert_eq(s.phase, Phase.Type.PRE_GAME)
	# Buiten PRE_GAME is de keuze illegaal.
	var laat := _fresh_state()
	var fout: Dictionary = Reducer.apply(laat, Actions.make_choose_doctrine(Constants.Doctrine.VOS), 1)
	assert_false(fout.ok, "kiezen na de start is illegaal")
	assert_eq(fout.error, "De facties liggen al vast")
	# Onbekende factie geweigerd.
	assert_false(Reducer.apply(s, Actions.make_choose_doctrine(99), 1).ok, "factie 99 bestaat niet")
	# P1 kiest: blind, fase blijft staan, geen reveal-event.
	var res1: Dictionary = _apply_ok(s, Actions.make_choose_doctrine(Constants.Doctrine.VOS), 1, "keuze p1")
	assert_eq(s.phase, Phase.Type.PRE_GAME, "na een keuze blijft PRE_GAME staan")
	for ev in res1.events:
		assert_true(String(ev.type) != Reducer.EV_DOCTRINES_REVEALED, "geen reveal na een keuze")
	# Dubbel kiezen geweigerd, ook een andere factie.
	var dubbel: Dictionary = Reducer.apply(s, Actions.make_choose_doctrine(Constants.Doctrine.MUIS), 1)
	assert_false(dubbel.ok, "een keuze is definitief")
	assert_eq(dubbel.error, "Al een factie gekozen")
	# P2 kiest: gate rond -- doctrines toegepast, commits leeg, opstelfase open.
	var res2: Dictionary = _apply_ok(s, Actions.make_choose_doctrine(Constants.Doctrine.BEER), 2, "keuze p2")
	assert_eq(s.phase, Phase.Type.PLACEMENT, "beide binnen: de opstelfase opent")
	assert_eq(int(s.doctrines[1]), Constants.Doctrine.VOS)
	assert_eq(int(s.doctrines[2]), Constants.Doctrine.BEER)
	assert_true(s.doctrine_commits.is_empty(), "commits zijn opgeruimd na de reveal")
	var reveal_gezien := false
	for ev in res2.events:
		if String(ev.type) == Reducer.EV_DOCTRINES_REVEALED:
			reveal_gezien = true
			assert_eq(int(ev.payload.doctrines["1"]), Constants.Doctrine.VOS)
			assert_eq(int(ev.payload.doctrines["2"]), Constants.Doctrine.BEER)
	assert_true(reveal_gezien, "de onthulling is een event (voor de event-stream)")
	# En de partij speelt gewoon door vanaf hier.
	_apply_ok(s, Actions.make_place(s.default_placement(1)), 1, "place p1 na keuze")
	_apply_ok(s, Actions.make_place(s.default_placement(2)), 2, "place p2 na keuze")
	assert_eq(s.phase, Phase.Type.SETUP_1_DEFINE)


func test_f4_doctrine_gate_boekt_de_pools() -> void:
	# init_pools hoort NA de keuze te draaien: de startreserve hangt aan de comp.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"campaign": {"pool_model": "punten", "pools": {"1": 30, "2": 30}}})
	_apply_ok(s, Actions.make_choose_doctrine(Constants.Doctrine.MUIS), 1, "keuze p1")
	assert_true(s.pools.is_empty(), "geen pools zolang de gate open staat")
	_apply_ok(s, Actions.make_choose_doctrine(Constants.Doctrine.MENS), 2, "keuze p2")
	assert_false(s.pools.is_empty(), "gate rond: de pools zijn geboekt")
	assert_true(s.pool_count(1, Constants.UnitType.INFANTRY) > 0, "muis kan soldaten kopen")
	assert_false(s.kent_type(1, Constants.UnitType.ARTILLERY), "en kent nog steeds geen kanon")


func test_f4_doctrine_keuze_in_legal_actions() -> void:
	var s := GameState.new()
	var opties: Array = Validator.legal_actions(s, 1)
	assert_eq(opties.size(), Constants.DOCTRINE_DATA.size(), "elke factie is een optie")
	_apply_ok(s, opties[0], 1, "eerste optie is speelbaar")
	assert_true(Validator.legal_actions(s, 1).is_empty(), "na je keuze wacht je op de ander")
	assert_eq(Validator.legal_actions(s, 2).size(), Constants.DOCTRINE_DATA.size(), "de ander kiest nog")


func test_f4_doctrine_timeout_geeft_default() -> void:
	# Klokken aan: de trage kiezer krijgt de standaard-factie, zoals de
	# default-opstelling en de default-loadout in de andere setup-fasen.
	var s := GameState.new()
	s.rules = RulesConfig.from_dict({"clock": {"bank_sec": 60, "increment_sec": 5}})
	# Met now_ms, want de klok armt pas bij een actie met tijd erbij.
	var k1: Dictionary = Reducer.apply(s, Actions.make_choose_doctrine(Constants.Doctrine.WOLF), 1, 1000)
	assert_true(k1.ok, "keuze p1 hoort te slagen (kreeg: %s)" % k1.error)
	assert_true(s.turn_deadline > 0, "de deadline staat na de eerste actie")
	# Te vroeg claimen: geweigerd (deadline is net gezet).
	var vroeg: Dictionary = Reducer.apply(s, Actions.make_claim_timeout(), 1, 1000)
	assert_false(vroeg.ok, "claim voor de deadline is illegaal")
	var claim: Dictionary = Reducer.apply(s, Actions.make_claim_timeout(), 1, s.turn_deadline + 1)
	assert_true(claim.ok, "claim na de deadline slaagt (kreeg: %s)" % claim.error)
	assert_eq(s.phase, Phase.Type.PLACEMENT, "de partij is gewoon begonnen")
	assert_eq(int(s.doctrines[1]), Constants.Doctrine.WOLF, "de kiezer houdt zijn keuze")
	assert_eq(int(s.doctrines[2]), Constants.Doctrine.MENS, "de slaper krijgt de standaard")
