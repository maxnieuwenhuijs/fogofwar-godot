extends "res://tests/TestSuite.gd"

func _class_name() -> String:
	return "GameSessionTests"

func _cards_for(hp1: int, s1: int, a1: int, hp2: int, s2: int, a2: int, hp3: int, s3: int, a3: int) -> Array:
	return [
		{"hp": hp1, "stamina": s1, "attack": a1},
		{"hp": hp2, "stamina": s2, "attack": a2},
		{"hp": hp3, "stamina": s3, "attack": a3},
	]

# =========================================================================
# Opstelling (PLACEMENT-fase)
# =========================================================================

func test_start_new_game_enters_placement() -> void:
	GameSession.start_new_game()
	assert_eq(GameSession.state.phase, Phase.Type.PLACEMENT)
	assert_eq(GameSession.state.pawns.size(), 0)

func test_placement_both_players_starts_cycle() -> void:
	GameSession.start_new_game()
	assert_true(GameSession.submit_default_placement(Constants.PLAYER_1))
	assert_eq(GameSession.state.phase, Phase.Type.PLACEMENT)
	assert_true(GameSession.submit_default_placement(Constants.PLAYER_2))
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_DEFINE)
	assert_eq(GameSession.state.pawns.size(), 44)
	assert_eq(GameSession.state.cycle, 1)
	assert_eq(GameSession.state.round_number, 1)

func test_start_new_game_default_shortcut() -> void:
	GameSession.start_new_game_default()
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_DEFINE)
	assert_eq(GameSession.state.pawns.size(), 44)

func test_placement_rejected_twice() -> void:
	GameSession.start_new_game()
	assert_true(GameSession.submit_default_placement(Constants.PLAYER_1))
	assert_false(GameSession.submit_default_placement(Constants.PLAYER_1))

func test_invalid_placement_rejected() -> void:
	GameSession.start_new_game()
	var placements: Array = GameSession.state.default_placement(Constants.PLAYER_1)
	placements[0] = {"type": placements[0].type, "pos": Vector2i(5, 5)}
	assert_false(GameSession.submit_placement(Constants.PLAYER_1, placements))

func test_doctrines_stored_per_player() -> void:
	GameSession.start_new_game_default(Constants.Doctrine.MUIS, Constants.Doctrine.LEEUW)
	assert_eq(GameSession.state.doctrine_of(Constants.PLAYER_1), Constants.Doctrine.MUIS)
	assert_eq(GameSession.state.doctrine_of(Constants.PLAYER_2), Constants.Doctrine.LEEUW)
	assert_eq(GameSession.state.get_alive_pawns_for(Constants.PLAYER_1).size(), 22)
	assert_eq(GameSession.state.get_alive_pawns_for(Constants.PLAYER_2).size(), 18)

# =========================================================================
# Kaartdefinitie en onthulling
# =========================================================================

func test_submit_define_invalid_stats_rejected() -> void:
	GameSession.start_new_game_default()
	var ok: bool = GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(3, 3, 3, 1, 1, 5, 2, 2, 3))
	assert_false(ok)

func test_submit_define_wrong_count_rejected() -> void:
	GameSession.start_new_game_default()
	var ok: bool = GameSession.submit_define_cards(Constants.PLAYER_1, [
		{"hp": 5, "stamina": 1, "attack": 1},
		{"hp": 3, "stamina": 2, "attack": 2},
	])
	assert_false(ok)

func test_muis_defines_four_cards_budget_five() -> void:
	GameSession.start_new_game_default(Constants.Doctrine.MUIS, Constants.Doctrine.MENS)
	# Budget 7-kaarten zijn ongeldig voor de Muis.
	assert_false(GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(5, 1, 1, 3, 2, 2, 1, 1, 5)))
	var four_cards: Array = [
		{"hp": 1, "stamina": 1, "attack": 3},
		{"hp": 3, "stamina": 1, "attack": 1},
		{"hp": 1, "stamina": 3, "attack": 1},
		{"hp": 2, "stamina": 2, "attack": 1},
	]
	assert_true(GameSession.submit_define_cards(Constants.PLAYER_1, four_cards))

func test_beer_speed_cap_enforced() -> void:
	GameSession.start_new_game_default(Constants.Doctrine.BEER, Constants.Doctrine.MENS)
	assert_false(GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(1, 5, 1, 3, 2, 2, 3, 2, 2)))
	assert_true(GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(3, 3, 1, 3, 2, 2, 5, 1, 1)))

func test_submit_define_both_players_triggers_reveal() -> void:
	GameSession.start_new_game_default()
	GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(5, 1, 1, 3, 2, 2, 1, 1, 5))
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_DEFINE)
	GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(5, 1, 1, 3, 2, 2, 1, 1, 5))
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_REVEAL)
	GameSession.acknowledge_reveal()
	# v4.1: geen RPS meer — volledig gelijk bod → deterministisch (P1 in C1/R1).
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_LINKING)
	assert_eq(GameSession.state.initiative_player, Constants.PLAYER_1)

func test_linking_phase_transition_after_reveal() -> void:
	GameSession.start_new_game_default()
	GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(2, 2, 3, 2, 2, 3, 2, 2, 3))
	GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(5, 1, 1, 5, 1, 1, 5, 1, 1))
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_REVEAL)
	GameSession.acknowledge_reveal()
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_LINKING)
	assert_eq(GameSession.state.initiative_player, Constants.PLAYER_1)
	assert_eq(GameSession.state.current_player, Constants.PLAYER_1)

# =========================================================================
# Koppelen
# =========================================================================

func _link_one_card_for_current_player() -> bool:
	var state: GameState = GameSession.state
	var player_id: int = state.current_player
	var card_id: int = -1
	for c in state.cards_revealed[player_id]:
		if not c.is_linked():
			card_id = c.id
			break
	if card_id == -1:
		return false
	var pawn_id: int = -1
	for pawn in state.pawns.values():
		if pawn.owner_id == player_id and not pawn.is_eliminated and pawn.linked_card_id == -1:
			pawn_id = pawn.id
			break
	if pawn_id == -1:
		return false
	return GameSession.submit_link(player_id, card_id, pawn_id)

func _link_all_until_phase_change(start_phase: int) -> void:
	var safety: int = 0
	while GameSession.state.phase == start_phase and safety < 100:
		if not _link_one_card_for_current_player():
			break
		safety += 1

func _define_for(player_id: int) -> void:
	var doctrine: Dictionary = GameSession.state.doctrine_data_of(player_id)
	var cards: Array = []
	for i in int(doctrine.cards):
		var free: int = doctrine.budget - 3
		cards.append({"hp": 1, "stamina": 1, "attack": 1 + free})
	GameSession.submit_define_cards(player_id, cards)

func _advance_to_action_phase_with_p1_initiative() -> void:
	GameSession.start_new_game_default()
	for round_nr in 3:
		GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(1, 1, 5, 1, 1, 5, 1, 1, 5))
		GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(5, 1, 1, 5, 1, 1, 5, 1, 1))
		GameSession.acknowledge_reveal()
		_link_all_until_phase_change(Phase.linking_for_round(round_nr + 1))

func test_initiative_winner_starts_action_phase() -> void:
	_advance_to_action_phase_with_p1_initiative()
	assert_eq(GameSession.state.phase, Phase.Type.ACTION)
	assert_eq(GameSession.state.initiative_player, Constants.PLAYER_1)
	assert_eq(GameSession.state.current_player, Constants.PLAYER_1)

func test_unequal_card_counts_tail_linking() -> void:
	# Muis (4 kaarten) vs Leeuw (2): de Muis koppelt zijn staart achter elkaar.
	GameSession.start_new_game_default(Constants.Doctrine.MUIS, Constants.Doctrine.LEEUW)
	_define_for(Constants.PLAYER_1)
	_define_for(Constants.PLAYER_2)
	GameSession.acknowledge_reveal()
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_LINKING)
	_link_all_until_phase_change(Phase.Type.SETUP_1_LINKING)
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_2_DEFINE)
	var p1_linked: int = 0
	var p2_linked: int = 0
	for pawn in GameSession.state.pawns.values():
		if pawn.is_eliminated or pawn.linked_card_id == -1:
			continue
		if pawn.owner_id == Constants.PLAYER_1:
			p1_linked += 1
		else:
			p2_linked += 1
	assert_eq(p1_linked, 4)
	assert_eq(p2_linked, 2)

func test_round_reset_clears_cards_defined() -> void:
	GameSession.start_new_game_default()
	GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(2, 2, 3, 2, 2, 3, 2, 2, 3))
	GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(5, 1, 1, 5, 1, 1, 5, 1, 1))
	GameSession.acknowledge_reveal()
	_link_all_until_phase_change(Phase.Type.SETUP_1_LINKING)
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_2_DEFINE)
	assert_eq(GameSession.state.round_number, 2)
	assert_eq(GameSession.state.cards_defined[Constants.PLAYER_1].size(), 0)
	assert_eq(GameSession.state.cards_defined[Constants.PLAYER_2].size(), 0)
	assert_eq(GameSession.state.cards_revealed[Constants.PLAYER_1].size(), 0)
	assert_eq(GameSession.state.cards_revealed[Constants.PLAYER_2].size(), 0)
	var ok1: bool = GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(3, 2, 2, 3, 2, 2, 3, 2, 2))
	assert_true(ok1)
	var ok2: bool = GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(3, 2, 2, 3, 2, 2, 3, 2, 2))
	assert_true(ok2)
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_2_REVEAL)

func _eliminate_all_pawns_except(state: GameState, player_id: int, keep_count: int) -> void:
	var kept: int = 0
	for pawn in state.pawns.values():
		if pawn.owner_id != player_id:
			continue
		if kept < keep_count:
			kept += 1
			continue
		state.remove_pawn(pawn)

func test_linking_with_fewer_pawns_other_player_continues() -> void:
	GameSession.start_new_game_default()
	_eliminate_all_pawns_except(GameSession.state, Constants.PLAYER_1, 2)
	GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(1, 1, 5, 1, 1, 5, 1, 1, 5))
	GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(5, 1, 1, 5, 1, 1, 5, 1, 1))
	GameSession.acknowledge_reveal()
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_1_LINKING)
	_link_all_until_phase_change(Phase.Type.SETUP_1_LINKING)
	assert_eq(GameSession.state.phase, Phase.Type.SETUP_2_DEFINE)
	var p1_linked: int = 0
	var p2_linked: int = 0
	for pawn in GameSession.state.pawns.values():
		if pawn.is_eliminated or pawn.linked_card_id == -1:
			continue
		if pawn.owner_id == Constants.PLAYER_1:
			p1_linked += 1
		else:
			p2_linked += 1
	assert_eq(p1_linked, 2)
	assert_eq(p2_linked, 3)

func test_beer_link_gets_hp_bonus() -> void:
	GameSession.start_new_game_default(Constants.Doctrine.BEER, Constants.Doctrine.MENS)
	GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(5, 1, 1, 3, 2, 2, 3, 3, 1))
	GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(1, 1, 5, 1, 1, 5, 1, 1, 5))
	GameSession.acknowledge_reveal()
	# P2 heeft initiatief (hoger bod); koppel tot we bij P1 zijn.
	_link_all_until_phase_change(Phase.Type.SETUP_1_LINKING)
	var found_beer_bonus := false
	for pawn in GameSession.state.pawns.values():
		if pawn.owner_id == Constants.PLAYER_1 and pawn.is_active:
			var card: Card = GameSession.state.all_cards[pawn.linked_card_id]
			assert_eq(pawn.max_hp, card.hp + 1)
			found_beer_bonus = true
	assert_true(found_beer_bonus)

func test_vos_links_hidden() -> void:
	GameSession.start_new_game_default(Constants.Doctrine.VOS, Constants.Doctrine.MENS)
	GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(3, 2, 2, 3, 2, 2, 3, 2, 2))
	GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(3, 2, 2, 3, 2, 2, 3, 2, 2))
	GameSession.acknowledge_reveal()
	_link_all_until_phase_change(Phase.Type.SETUP_1_LINKING)
	for pawn in GameSession.state.pawns.values():
		if not pawn.is_active:
			continue
		if pawn.owner_id == Constants.PLAYER_1:
			assert_false(pawn.card_revealed)
		else:
			assert_true(pawn.card_revealed)

func test_vos_cavalry_gets_speed_bonus_via_session() -> void:
	GameSession.start_new_game_default(Constants.Doctrine.VOS, Constants.Doctrine.MENS)
	GameSession.submit_define_cards(Constants.PLAYER_1, _cards_for(3, 2, 2, 3, 2, 2, 3, 2, 2))
	GameSession.submit_define_cards(Constants.PLAYER_2, _cards_for(1, 1, 5, 1, 1, 5, 1, 1, 5))
	GameSession.acknowledge_reveal()
	# P2 heeft het initiatief (hoger bod); koppel tot P1 aan de beurt is.
	var safety := 0
	while GameSession.state.current_player != Constants.PLAYER_1 and safety < 10:
		_link_one_card_for_current_player()
		safety += 1
	var state: GameState = GameSession.state
	var cav: Pawn = null
	for p in state.get_alive_pawns_for(Constants.PLAYER_1):
		if p.unit_type == Constants.UnitType.CAVALRY:
			cav = p
			break
	var card_id := -1
	for c in state.cards_revealed[Constants.PLAYER_1]:
		if not c.is_linked():
			card_id = c.id
			break
	assert_true(GameSession.submit_link(Constants.PLAYER_1, card_id, cav.id))
	# Kaart-Speed 2 + Vos-cavalerieperk 1 = 3.
	assert_eq(cav.max_stamina, 3)

# =========================================================================
# Actiefase
# =========================================================================

func test_action_move_alternates_turns() -> void:
	_advance_to_action_phase_with_p1_initiative()
	var state: GameState = GameSession.state
	var pawn: Pawn = null
	for p in state.get_active_pawns_for(Constants.PLAYER_1):
		if Rules.can_pawn_act(state, p.id) and not Rules.get_valid_moves(state, p.id).is_empty():
			pawn = p
			break
	assert_true(pawn != null)
	var target: Vector2i = Rules.get_valid_moves(state, pawn.id)[0]
	assert_true(GameSession.submit_move(Constants.PLAYER_1, pawn.id, target))
	assert_true(state.pawns[pawn.id].remaining_stamina < state.pawns[pawn.id].max_stamina)
	assert_eq(state.current_player, Constants.PLAYER_2)

func test_wolf_step_pending_flow() -> void:
	GameSession.start_new_game_default(Constants.Doctrine.WOLF, Constants.Doctrine.MENS)
	# Bouw een gecontroleerde situatie in de actiefase na, los van de opstelling.
	var state: GameState = GameSession.state
	state.phase = Phase.Type.ACTION
	state.current_player = Constants.PLAYER_1
	var wolf: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var victim: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 4))
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, state.round_number, 3, 2, 2)
	state.all_cards[card.id] = card
	wolf.link_card(card)
	# Inactief doelwit sterft → verplichte verplaatsing → daarna de gratis stap (§7).
	assert_true(GameSession.submit_attack(Constants.PLAYER_1, wolf.id, victim.id))
	assert_eq(state.pawns[wolf.id].position, Vector2i(5, 4))
	assert_eq(state.pending_wolf_step_pawn, wolf.id)
	# Beurt is nog niet gewisseld; eerst de stap afronden (of overslaan).
	assert_eq(state.current_player, Constants.PLAYER_1)
	assert_false(GameSession.submit_move(Constants.PLAYER_1, wolf.id, Vector2i(4, 4)))
	assert_true(GameSession.submit_wolf_step(Constants.PLAYER_1, Vector2i(5, 3)))
	assert_eq(state.pawns[wolf.id].position, Vector2i(5, 3))

func test_shot_via_session() -> void:
	GameSession.start_new_game_default()
	var state: GameState = GameSession.state
	state.phase = Phase.Type.ACTION
	state.current_player = Constants.PLAYER_1
	var shooter: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 5))
	var target: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 3))
	# Geef P2 óók een actieve pion, anders eindigt de cyclus direct na het schot.
	var p2_mover: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(0, 5))
	var p2_card := Card.new(state.next_card_id(), Constants.PLAYER_2, state.round_number, 3, 2, 2)
	state.all_cards[p2_card.id] = p2_card
	p2_mover.link_card(p2_card)
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, state.round_number, 3, 1, 3)
	state.all_cards[card.id] = card
	shooter.link_card(card)
	assert_true(GameSession.submit_shot(Constants.PLAYER_1, shooter.id, target.id))
	assert_true(target.is_eliminated)
	assert_eq(shooter.remaining_stamina, 0)
	assert_eq(state.current_player, Constants.PLAYER_2)

func test_charge_via_session() -> void:
	GameSession.start_new_game_default()
	var state: GameState = GameSession.state
	state.phase = Phase.Type.ACTION
	state.current_player = Constants.PLAYER_1
	var cav: Pawn = state._spawn_pawn(Constants.PLAYER_1, Vector2i(5, 6), Constants.UnitType.CAVALRY)
	var target: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(5, 3))
	var p2_mover: Pawn = state._spawn_pawn(Constants.PLAYER_2, Vector2i(0, 5))
	var p2_card := Card.new(state.next_card_id(), Constants.PLAYER_2, state.round_number, 3, 2, 2)
	state.all_cards[p2_card.id] = p2_card
	p2_mover.link_card(p2_card)
	# Speed 3: 2 stappen + aanval = 3 stamina.
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, state.round_number, 3, 3, 2)
	state.all_cards[card.id] = card
	cav.link_card(card)
	assert_true(GameSession.submit_charge(Constants.PLAYER_1, cav.id, Vector2i(5, 4), target.id))
	assert_true(target.is_eliminated)
	# Verplichte verplaatsing na de kill.
	assert_eq(cav.position, Vector2i(5, 3))
	assert_eq(cav.remaining_stamina, 0)
