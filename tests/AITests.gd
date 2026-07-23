extends "res://tests/TestSuite.gd"

func _class_name() -> String:
	return "AITests"

func _make_initial_state() -> GameState:
	var state := GameState.new()
	state.setup_initial_pawns()
	return state

func _fake_reveal_cards(state: GameState, player_id: int) -> void:
	state.cards_revealed[player_id] = []
	for i in Constants.CARDS_PER_ROUND:
		var c := Card.new(state.next_card_id(), player_id, 1, 2, 3, 2)
		state.cards_revealed[player_id].append(c)
		state.all_cards[c.id] = c

# AI moet in ronde 1 nooit een achterste-rij-pion koppelen als er een
# voorste-rij-pion beschikbaar is, want die zit ingeklemd.
func test_ai_easy_picks_front_row_in_round_one() -> void:
	var ai = preload("res://scripts/ai/AIEasy.gd").new()
	ai.player_id = Constants.PLAYER_2
	var state: GameState = _make_initial_state()
	_fake_reveal_cards(state, Constants.PLAYER_2)
	for i in 30:
		var choice: Dictionary = ai.choose_link(state)
		assert_true(choice.has("pawn_id"))
		var picked: Pawn = state.pawns[choice.pawn_id]
		# Row 1 is de voorste rij voor P2 (dichter bij het midden).
		assert_eq(picked.position.y, 1)

func test_ai_medium_picks_front_row_in_round_one() -> void:
	var ai = preload("res://scripts/ai/AIMedium.gd").new()
	ai.player_id = Constants.PLAYER_2
	var state: GameState = _make_initial_state()
	_fake_reveal_cards(state, Constants.PLAYER_2)
	var choice: Dictionary = ai.choose_link(state)
	assert_true(choice.has("pawn_id"))
	var picked: Pawn = state.pawns[choice.pawn_id]
	assert_eq(picked.position.y, 1)

# Als de hele voorste rij al gelinkt of verwijderd is, moet de AI wel
# terugvallen op de resterende pionnen.
func test_ai_easy_falls_back_when_no_movable_pawns() -> void:
	var ai = preload("res://scripts/ai/AIEasy.gd").new()
	ai.player_id = Constants.PLAYER_2
	var state := GameState.new()
	# Zet pionnen naast elkaar in een hoek zodat ze ingeklemd zijn.
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(0, 0))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(1, 0))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(0, 1))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(1, 1))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(2, 0))
	state._spawn_pawn(Constants.PLAYER_2, Vector2i(2, 1))
	_fake_reveal_cards(state, Constants.PLAYER_2)
	# Niet crashen, wel een keuze teruggeven.
	var choice: Dictionary = ai.choose_link(state)
	assert_true(choice.has("pawn_id"))
	assert_true(state.pawns.has(choice.pawn_id))

# =========================================================================
# v4.1: kaartgeneratie per doctrine
# =========================================================================

func _assert_cards_valid(cards: Array, doctrine: int) -> void:
	var data: Dictionary = Constants.doctrine_data(doctrine)
	assert_eq(cards.size(), int(data.cards))
	for c in cards:
		assert_true(Card.is_valid_stats(int(c.hp), int(c.stamina), int(c.attack), data.budget, data.speed_max),
			"kaart %s doctrine %s" % [str(c), Constants.doctrine_name(doctrine)])

func test_generate_cards_respects_doctrine_budgets() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	for doctrine in Constants.DOCTRINE_DATA.keys():
		var state := GameState.new()
		state.doctrines[Constants.PLAYER_1] = doctrine
		state.setup_initial_pawns()  # 4.1.10-hr: kaart-aantal hangt van vrije pionnen af
		var cards: Array = ai.generate_cards(state)
		_assert_cards_valid(cards, doctrine)

func test_choose_link_prefers_attack_card_on_artillery() -> void:
	# Type-bewust koppelen: de aanvalskaart hoort op het kanon (zware granaten),
	# niet de sprinterkaart.
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	var gun: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.ARTILLERY)
	var atk_card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 1, 1, 5)
	var spd_card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 1, 5, 1)
	state.all_cards[atk_card.id] = atk_card
	state.all_cards[spd_card.id] = spd_card
	state.cards_revealed[Constants.PLAYER_1] = [spd_card, atk_card]
	var choice: Dictionary = ai.choose_link(state)
	assert_eq(choice.pawn_id, gun.id)
	assert_eq(choice.card_id, atk_card.id)

func test_choose_placement_weights_put_artillery_front() -> void:
	# Met de default opstellings-gewichten staan kanonnen op de voorste rij.
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_2
	var state := GameState.new()
	var placements: Array = ai.choose_placement(state)
	var front_row: int = Constants.get_start_rows_for_player(Constants.PLAYER_2)[1]
	for entry in placements:
		if int(entry.type) == Constants.UnitType.ARTILLERY:
			assert_eq(entry.pos.y, front_row)

func test_choose_placement_is_valid() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_2
	for doctrine in [Constants.Doctrine.MENS, Constants.Doctrine.LEEUW, Constants.Doctrine.MUIS]:
		var state := GameState.new()
		state.doctrines[Constants.PLAYER_2] = doctrine
		var placements: Array = ai.choose_placement(state)
		assert_true(state.is_valid_placement(Constants.PLAYER_2, placements))

# =========================================================================
# v4.1: actie-enumeratie met schoten en charges
# =========================================================================

func test_enumerate_includes_shots() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	var shooter: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var enemy: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 3))
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 1, 3)
	state.all_cards[card.id] = card
	shooter.link_card(card)
	var found_shot := false
	for a in ai.enumerate_actions(state, Constants.PLAYER_1):
		if a.type == "shot" and a.target_id == enemy.id:
			found_shot = true
	assert_true(found_shot)

func test_enumerate_includes_charges() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	var cav: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 6), Constants.UnitType.CAVALRY)
	var enemy: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 3))
	# Speed 3: 2 stappen + aanval past in de charge-kosten.
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 3, 2)
	state.all_cards[card.id] = card
	cav.link_card(card)
	var found_charge := false
	for a in ai.enumerate_actions(state, Constants.PLAYER_1):
		if a.type == "charge" and a.defender_id == enemy.id and a.move_target == Vector2i(5, 4):
			found_charge = true
	assert_true(found_charge)

func test_simulate_handles_all_action_types() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	var shooter: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var _enemy: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 3))
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 1, 3)
	state.all_cards[card.id] = card
	shooter.link_card(card)
	for a in ai.enumerate_actions(state, Constants.PLAYER_1):
		var copy: GameState = ai.simulate(state, a)
		# De actie moet in de kopie zijn uitgevoerd (stamina besteed), niet in het origineel.
		assert_true(copy.pawns[shooter.id].remaining_stamina < state.pawns[shooter.id].remaining_stamina)
		assert_eq(state.pawns[shooter.id].remaining_stamina, 1)

func test_choose_wolf_step_returns_valid_or_skip() -> void:
	var ai = preload("res://scripts/ai/AIController.gd").new()
	ai.player_id = Constants.PLAYER_1
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.WOLF
	var wolf: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 2, 2)
	state.all_cards[card.id] = card
	wolf.link_card(card)
	state.pending_wolf_step_pawn = wolf.id
	var choice: Dictionary = ai.choose_wolf_step(state)
	if choice.has("target"):
		var target: Vector2i = choice.target
		var dist: int = absi(target.x - 5) + absi(target.y - 5)
		assert_eq(dist, 1)
		assert_true(state.is_tile_empty(target))
	else:
		assert_true(choice.is_empty())
