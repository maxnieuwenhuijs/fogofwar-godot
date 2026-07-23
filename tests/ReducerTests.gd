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
