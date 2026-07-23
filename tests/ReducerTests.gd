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


func test_cycle_limit_tiebreak_materiaal() -> void:
	# P1 heeft meer materiaal; bij de cycluslimiet wint P1 via de tiebreak.
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.cycle_limit = 1
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var mover: Pawn = s._spawn_pawn(1, Vector2i(5, 8))
	var card := Card.new(s.next_card_id(), 1, 1, 3, 1, 1)  # speed 1: één stap en klaar
	s.all_cards[card.id] = card
	mover.link_card(card)
	s._spawn_pawn(1, Vector2i(0, 5))  # extra standbeeld: P1 2 pionnen, P2 1
	s._spawn_pawn(2, Vector2i(10, 5))
	var res: Dictionary = Reducer.apply(s, Actions.make_move(mover.id, Vector2i(5, 7)), 1)
	assert_true(res.ok)
	assert_eq(s.phase, Phase.Type.GAME_OVER, "cycluslimiet bereikt -> partij beslist")
	assert_eq(s.winner, Constants.PLAYER_1, "tiebreak op materiaal (2 vs 1)")


func test_cycle_limit_echte_remise() -> void:
	# Perfect gespiegelde eindstand: materiaal, haven en nabijheid gelijk -> -1.
	var s := GameState.new()
	s.rules = RulesConfig.new()
	s.rules.cycle_limit = 1
	s.phase = Phase.Type.ACTION
	s.current_player = 1
	var mover: Pawn = s._spawn_pawn(1, Vector2i(5, 8))
	var card := Card.new(s.next_card_id(), 1, 1, 3, 1, 1)
	s.all_cards[card.id] = card
	mover.link_card(card)
	s._spawn_pawn(2, Vector2i(5, 3))  # spiegel van (5,7): beide 7 van hun haven
	var res: Dictionary = Reducer.apply(s, Actions.make_move(mover.id, Vector2i(5, 7)), 1)
	assert_true(res.ok)
	assert_eq(s.phase, Phase.Type.GAME_OVER)
	assert_eq(s.winner, -1, "volledig gelijk -> echte remise")


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
