extends TestSuite

# F0.3 — actietaal + validator. Kern: de property-test speelt partijen met
# random keuzes uit legal_actions en eist dat (1) élke opgesomde actie door
# is_legal komt, (2) élke is_legal-actie door de engine geaccepteerd wordt,
# en (3) actie → JSON → actie identiek is.

const GameSessionScript := preload("res://scripts/core/GameSession.gd")


func _class_name() -> String:
	return "ValidatorTests"


func _roundtrip_ok(a: Dictionary) -> bool:
	var json: String = JSON.stringify(Actions.to_dict(a))
	var back: Dictionary = Actions.from_dict(JSON.parse_string(json))
	return JSON.stringify(Actions.to_dict(back)) == json


## Actie → engine-aanroep. Retourneert het accepted-oordeel van de engine.
func _dispatch(engine, player: int, a: Dictionary) -> bool:
	match String(a.type):
		Actions.PLACE:
			return engine.submit_placement(player, a.placements)
		Actions.DEFINE_CARDS:
			return engine.submit_define_cards(player, a.cards)
		Actions.ACK_REVEAL:
			return engine.submit_ack_reveal(player)
		Actions.LINK:
			return engine.submit_link(player, a.card_id, a.pawn_id)
		Actions.MOVE:
			return engine.submit_move(player, a.pawn_id, a.target)
		Actions.MELEE:
			return engine.submit_attack(player, a.attacker_id, a.defender_id)
		Actions.SHOOT:
			return engine.submit_shot(player, a.shooter_id, a.target_id)
		Actions.CHARGE:
			return engine.submit_charge(player, a.pawn_id, a.move_target, a.defender_id)
		Actions.WOLF_STEP:
			return engine.submit_wolf_step(player, a.target)
		Actions.SKIP_WOLF_STEP:
			return engine.skip_wolf_step(player)
	return false


func test_action_json_roundtrip_all_types() -> void:
	var samples: Array = [
		Actions.make_place([{"type": 0, "pos": Vector2i(3, 9)}, {"type": 2, "pos": Vector2i(5, 10)}]),
		Actions.make_define_cards([{"hp": 3, "stamina": 2, "attack": 2}]),
		Actions.make_ack_reveal(),
		Actions.make_link(4, 17),
		Actions.make_move(3, Vector2i(5, 6)),
		Actions.make_melee(3, 25),
		Actions.make_shoot(7, 30),
		Actions.make_charge(9, Vector2i(4, 4), 28),
		Actions.make_wolf_step(Vector2i(2, 3)),
		Actions.make_skip_wolf_step(),
		Actions.make_resign(),
		Actions.make_claim_timeout(),
	]
	for a in samples:
		assert_true(Actions.is_wellformed(a), "welgevormd: %s" % String(a.type))
		assert_true(_roundtrip_ok(a), "JSON-roundtrip: %s" % String(a.type))


func test_is_wellformed_rejects_garbage() -> void:
	assert_false(Actions.is_wellformed(null))
	assert_false(Actions.is_wellformed({}))
	assert_false(Actions.is_wellformed({"type": "bestaat_niet"}))
	assert_false(Actions.is_wellformed({"type": Actions.MOVE, "pawn_id": 1}))  # target ontbreekt
	assert_false(Actions.is_wellformed({"type": Actions.MOVE, "pawn_id": 1, "target": [1, 2]}))  # geen Vector2i


func test_claim_timeout_always_illegal() -> void:
	var engine = GameSessionScript.new()
	engine.start_new_game_default()
	var verdict: Dictionary = Validator.is_legal(engine.state, Actions.make_claim_timeout(), Constants.PLAYER_1)
	assert_false(verdict.legal, "CLAIM_TIMEOUT is illegaal tot F0.8")
	engine.free()


func test_sample_card_sets_valid_for_all_doctrines() -> void:
	for doctrine in Constants.DOCTRINE_DATA.keys():
		var s := GameState.new()
		s.doctrines[Constants.PLAYER_1] = doctrine
		var doctrine_data: Dictionary = s.doctrine_data_of(Constants.PLAYER_1)
		var sets: Array = Validator._sample_card_sets(s, Constants.PLAYER_1)
		assert_true(sets.size() >= 1, "minstens 1 geldige voorbeeldset voor %s" % String(doctrine_data.name))
		for cards in sets:
			assert_eq(cards.size(), int(doctrine_data.cards))
			for c in cards:
				assert_true(Card.is_valid_stats(c.hp, c.stamina, c.attack, doctrine_data.budget, doctrine_data.speed_max, 0),
					"voorbeeldkaart geldig voor %s" % String(doctrine_data.name))


## De F0.3-property-test: 50 partijen random spelen uit legal_actions.
func test_random_play_from_legal_actions() -> void:
	var rng := SeededRng.new(20260710)
	var doctrine_ids: Array = Constants.DOCTRINE_DATA.keys()
	var games_with_violations: int = 0
	var total_actions: int = 0
	var detail: String = ""
	for g in 50:
		var engine = GameSessionScript.new()
		var d1: int = doctrine_ids[rng.randi_range(0, doctrine_ids.size() - 1)]
		var d2: int = doctrine_ids[rng.randi_range(0, doctrine_ids.size() - 1)]
		engine.start_new_game(d1, d2)
		var violations: Array = []
		for step in 250:
			if engine.state.phase == Phase.Type.GAME_OVER:
				break
			# Wie mag er iets? (simultane fasen: beide; beurtfasen: één.)
			var order: Array = [Constants.PLAYER_1, Constants.PLAYER_2]
			if rng.randi_range(0, 1) == 1:
				order.reverse()
			var acted := false
			for player in order:
				var acts: Array = Validator.legal_actions(engine.state, player)
				if acts.is_empty():
					continue
				var a: Dictionary = acts[rng.randi_range(0, acts.size() - 1)]
				if not _roundtrip_ok(a):
					violations.append("roundtrip faalde: %s" % JSON.stringify(Actions.to_dict(a)))
				var verdict: Dictionary = Validator.is_legal(engine.state, a, player)
				if not verdict.legal:
					violations.append("legal_actions gaf illegale actie (%s): %s" % [verdict.reason, JSON.stringify(Actions.to_dict(a))])
				elif not _dispatch(engine, player, a):
					violations.append("engine weigerde is_legal-actie: %s" % JSON.stringify(Actions.to_dict(a)))
				total_actions += 1
				acted = true
				break
			if not acted:
				break  # niemand kan iets (mag alleen vlak voor een cyclus-reset)
		if not violations.is_empty():
			games_with_violations += 1
			if detail == "":
				detail = "game %d (d%d vs d%d): %s" % [g, d1, d2, violations[0]]
		engine.free()
	assert_eq(games_with_violations, 0, "0 partijen met schendingen verwacht; eerste: %s" % detail)
	assert_true(total_actions > 2000, "de property-test hoort duizenden acties te dekken (kreeg %d)" % total_actions)
