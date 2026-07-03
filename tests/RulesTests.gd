extends "res://tests/TestSuite.gd"

func _class_name() -> String:
	return "RulesTests"

func _make_state() -> GameState:
	var s := GameState.new()
	s.setup_initial_pawns()
	return s

func _link_simple(state: GameState, pawn: Pawn, hp: int, speed: int, attack: int, hp_bonus: int = 0) -> Card:
	var card := Card.new(state.next_card_id(), pawn.owner_id, state.round_number, hp, speed, attack)
	state.all_cards[card.id] = card
	pawn.link_card(card, hp_bonus)
	return card

func _spawn(state: GameState, owner_id: int, pos: Vector2i, unit_type: int = Constants.UnitType.INFANTRY) -> Pawn:
	return state._spawn_pawn(owner_id, pos, unit_type)

# =========================================================================
# Opstelling en samenstelling
# =========================================================================

func test_initial_board_has_44_pawns() -> void:
	var state := _make_state()
	assert_eq(state.pawns.size(), 44)
	assert_eq(state.get_alive_pawns_for(Constants.PLAYER_1).size(), 22)
	assert_eq(state.get_alive_pawns_for(Constants.PLAYER_2).size(), 22)

func test_default_placement_mens_composition() -> void:
	var state := _make_state()
	var counts: Array = [0, 0, 0]
	for pawn in state.get_alive_pawns_for(Constants.PLAYER_1):
		counts[pawn.unit_type] += 1
	assert_eq(counts[Constants.UnitType.INFANTRY], 13)
	assert_eq(counts[Constants.UnitType.CAVALRY], 6)
	assert_eq(counts[Constants.UnitType.ARTILLERY], 3)

func test_default_placement_valid_for_all_doctrines() -> void:
	for doctrine in Constants.DOCTRINE_DATA.keys():
		var state := GameState.new()
		state.doctrines[Constants.PLAYER_1] = doctrine
		state.doctrines[Constants.PLAYER_2] = doctrine
		var placement_p1: Array = state.default_placement(Constants.PLAYER_1)
		assert_true(state.is_valid_placement(Constants.PLAYER_1, placement_p1),
			"placement P1 " + Constants.doctrine_name(doctrine))
		state.apply_placement(Constants.PLAYER_1, placement_p1)
		var placement_p2: Array = state.default_placement(Constants.PLAYER_2)
		assert_true(state.is_valid_placement(Constants.PLAYER_2, placement_p2),
			"placement P2 " + Constants.doctrine_name(doctrine))
		state.apply_placement(Constants.PLAYER_2, placement_p2)
		assert_eq(state.pawns.size(), Constants.pawn_total(doctrine) * 2)

func test_leeuw_has_18_pawns() -> void:
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.LEEUW
	state.apply_placement(Constants.PLAYER_1, state.default_placement(Constants.PLAYER_1))
	assert_eq(state.get_alive_pawns_for(Constants.PLAYER_1).size(), 18)

func test_invalid_placement_outside_home_rows() -> void:
	var state := GameState.new()
	var placements: Array = state.default_placement(Constants.PLAYER_1)
	placements[0] = {"type": placements[0].type, "pos": Vector2i(5, 5)}
	assert_false(state.is_valid_placement(Constants.PLAYER_1, placements))

func test_invalid_placement_wrong_composition() -> void:
	var state := GameState.new()
	var placements: Array = state.default_placement(Constants.PLAYER_1)
	placements[0] = {"type": Constants.UnitType.INFANTRY, "pos": placements[0].pos}
	# Mens: 3 artillerie verwacht; nu is er één infanterist te veel.
	assert_false(state.is_valid_placement(Constants.PLAYER_1, placements))

func test_haven_p1_coords() -> void:
	assert_true(Rules.is_haven_for_player(Vector2i(0, 0), Constants.PLAYER_1))
	assert_true(Rules.is_haven_for_player(Vector2i(5, 0), Constants.PLAYER_1))
	assert_true(Rules.is_haven_for_player(Vector2i(10, 0), Constants.PLAYER_1))
	assert_false(Rules.is_haven_for_player(Vector2i(5, 0), Constants.PLAYER_2))
	assert_false(Rules.is_haven_for_player(Vector2i(1, 0), Constants.PLAYER_1))

# =========================================================================
# Bewegen (één actie per pion per cyclus)
# =========================================================================

func test_valid_moves_empty_board() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	_link_simple(state, pawn, 3, 3, 1)
	var moves: Array = Rules.get_valid_moves(state, pawn.id)
	assert_has(moves, Vector2i(5, 2))
	assert_has(moves, Vector2i(8, 5))
	assert_has(moves, Vector2i(6, 6))
	assert_false(moves.has(Vector2i(5, 5)))

func test_valid_moves_blocked_by_pawn() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var _blocker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 4))
	_link_simple(state, pawn, 3, 5, 1)
	var moves: Array = Rules.get_valid_moves(state, pawn.id)
	assert_false(moves.has(Vector2i(5, 4)))
	# Met Speed 5 mag omlopen (bv. via (6,4)).
	assert_true(moves.has(Vector2i(5, 3)))

func test_valid_moves_speed_limit() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	_link_simple(state, pawn, 5, 1, 1)
	var moves: Array = Rules.get_valid_moves(state, pawn.id)
	assert_has(moves, Vector2i(5, 4))
	assert_false(moves.has(Vector2i(5, 3)))

func test_move_spends_stamina_per_step() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	_link_simple(state, pawn, 3, 3, 1)
	# 2 stappen kost 2 stamina; met de rest mag de pion later opnieuw handelen.
	assert_true(Rules.apply_move(state, pawn.id, Vector2i(5, 3)))
	assert_eq(pawn.remaining_stamina, 1)
	# Nog 1 stap kan; verder dan dat niet.
	assert_false(Rules.get_valid_moves(state, pawn.id).has(Vector2i(5, 1)))
	assert_true(Rules.apply_move(state, pawn.id, Vector2i(5, 2)))
	assert_eq(pawn.remaining_stamina, 0)
	# Op: geen acties meer deze cyclus.
	assert_false(Rules.apply_move(state, pawn.id, Vector2i(5, 1)))
	assert_eq(Rules.get_valid_melee_targets(state, pawn.id).size(), 0)

func test_artillery_moves_max_one_step() -> void:
	var state := GameState.new()
	var gun := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.ARTILLERY)
	_link_simple(state, gun, 1, 5, 1)
	var moves: Array = Rules.get_valid_moves(state, gun.id)
	assert_has(moves, Vector2i(5, 4))
	assert_has(moves, Vector2i(6, 5))
	assert_false(moves.has(Vector2i(5, 3)))
	assert_eq(moves.size(), 4)

func test_muis_moves_through_own_pawns() -> void:
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MUIS
	var mouse := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var _friend := _spawn(state, Constants.PLAYER_1, Vector2i(5, 4))
	_link_simple(state, mouse, 1, 2, 2)
	var moves: Array = Rules.get_valid_moves(state, mouse.id)
	# Door de eigen pion heen; het gepasseerde vak telt als stap.
	assert_has(moves, Vector2i(5, 3))
	# Eindigen op een bezet vak mag nooit.
	assert_false(moves.has(Vector2i(5, 4)))

func test_muis_blocked_by_enemy() -> void:
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MUIS
	var mouse := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var _enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, mouse, 1, 2, 2)
	var moves: Array = Rules.get_valid_moves(state, mouse.id)
	assert_false(moves.has(Vector2i(5, 3)))

func test_non_muis_infantry_cannot_move_through_own() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var _friend := _spawn(state, Constants.PLAYER_1, Vector2i(5, 4))
	_link_simple(state, pawn, 3, 2, 1)
	var moves: Array = Rules.get_valid_moves(state, pawn.id)
	assert_false(moves.has(Vector2i(5, 3)))

func test_cavalry_jumps_over_own_pawns() -> void:
	# Cavalerie springt (bij elke doctrine) over eigen pionnen heen.
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	var _friend := _spawn(state, Constants.PLAYER_1, Vector2i(5, 4))
	_link_simple(state, cav, 3, 2, 1)
	var moves: Array = Rules.get_valid_moves(state, cav.id)
	assert_has(moves, Vector2i(5, 3))
	# Eindigen op het bezette vak mag nooit.
	assert_false(moves.has(Vector2i(5, 4)))

func test_cavalry_blocked_by_enemy_unless_wolf() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	var _enemy_inf := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	_link_simple(state, cav, 3, 2, 1)
	# Standaard blokkeert vijandelijke infanterie gewoon.
	assert_false(Rules.get_valid_moves(state, cav.id).has(Vector2i(5, 3)))
	# Wolf-doctrine: cavalerie springt óók over vijandelijke INFANTERIE.
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.WOLF
	assert_has(Rules.get_valid_moves(state, cav.id), Vector2i(5, 3))

func test_wolf_cavalry_does_not_jump_enemy_cavalry_or_artillery() -> void:
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.WOLF
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	var _enemy_cav := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.CAVALRY)
	var _enemy_gun := _spawn(state, Constants.PLAYER_2, Vector2i(4, 5), Constants.UnitType.ARTILLERY)
	_link_simple(state, cav, 3, 2, 1)
	var moves: Array = Rules.get_valid_moves(state, cav.id)
	assert_false(moves.has(Vector2i(5, 3)))
	assert_false(moves.has(Vector2i(3, 5)))

# =========================================================================
# Melee en terugslag
# =========================================================================

func test_melee_targets_adjacent_enemy() -> void:
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, attacker, 3, 2, 2)
	_link_simple(state, enemy, 3, 2, 2)
	var targets: Array = Rules.get_valid_melee_targets(state, attacker.id)
	assert_has(targets, enemy.id)

func test_melee_reduces_hp_and_costs_one_stamina() -> void:
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.CAVALRY)
	_link_simple(state, attacker, 3, 2, 2)
	_link_simple(state, enemy, 5, 1, 1)
	var result: Dictionary = Rules.apply_melee(state, attacker.id, enemy.id)
	assert_true(result.success)
	assert_eq(enemy.current_hp, 3)
	assert_false(enemy.is_eliminated)
	assert_eq(attacker.remaining_stamina, 1)
	# Genoeg stamina over: direct nóg een melee mag.
	var result2: Dictionary = Rules.apply_melee(state, attacker.id, enemy.id)
	assert_true(result2.success)
	assert_eq(enemy.current_hp, 1)
	assert_eq(attacker.remaining_stamina, 0)
	# Op = klaar.
	assert_false(Rules.apply_melee(state, attacker.id, enemy.id).success)

func test_melee_eliminates_and_forces_move() -> void:
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, attacker, 3, 2, 5)
	_link_simple(state, enemy, 3, 1, 3)
	var result: Dictionary = Rules.apply_melee(state, attacker.id, enemy.id)
	assert_true(result.success)
	assert_true(result.eliminated)
	assert_true(result.forced_move)
	assert_eq(attacker.position, Vector2i(5, 4))
	assert_true(enemy.is_eliminated)

func test_melee_inactive_pawn_dies_any_damage() -> void:
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, attacker, 3, 2, 1)
	var result: Dictionary = Rules.apply_melee(state, attacker.id, enemy.id)
	assert_true(result.success)
	assert_true(result.eliminated)

func test_retaliation_when_active_infantry_survives() -> void:
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	var defender := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	_link_simple(state, attacker, 3, 2, 2)
	_link_simple(state, defender, 5, 1, 1)
	var result: Dictionary = Rules.apply_melee(state, attacker.id, defender.id)
	assert_true(result.success)
	assert_true(result.retaliation)
	assert_eq(defender.current_hp, 3)
	# Altijd exact 1 schade, ongeacht de Attack van de verdediger.
	assert_eq(attacker.current_hp, 2)
	assert_false(attacker.is_eliminated)

func test_no_retaliation_when_defender_dies() -> void:
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var defender := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	_link_simple(state, attacker, 3, 2, 5)
	_link_simple(state, defender, 2, 1, 4)
	var result: Dictionary = Rules.apply_melee(state, attacker.id, defender.id)
	assert_true(result.eliminated)
	assert_false(result.retaliation)
	assert_eq(attacker.current_hp, 3)

func test_retaliation_by_defender_type() -> void:
	# Huisregel: terugslag hangt af van de overlevende verdediger —
	# infanterie −1 (elders getest), cavalerie −2, artillerie −0.
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var cav := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.CAVALRY)
	var gun := _spawn(state, Constants.PLAYER_2, Vector2i(6, 5), Constants.UnitType.ARTILLERY)
	_link_simple(state, attacker, 5, 3, 1)
	_link_simple(state, cav, 5, 1, 1)
	_link_simple(state, gun, 5, 1, 1)
	# Paard overleeft → −2 op de aanvaller.
	var r1: Dictionary = Rules.apply_melee(state, attacker.id, cav.id)
	assert_true(r1.success)
	assert_true(r1.retaliation)
	assert_eq(int(r1.retaliation_damage), 2)
	assert_eq(attacker.current_hp, 3)
	# Kanon overleeft → geen terugslag.
	var r2: Dictionary = Rules.apply_melee(state, attacker.id, gun.id)
	assert_true(r2.success)
	assert_false(r2.retaliation)
	assert_eq(attacker.current_hp, 3)

func test_no_retaliation_from_inactive_infantry() -> void:
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var defender := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	_link_simple(state, attacker, 1, 2, 1)
	# Inactieve verdediger sterft (geen kaart) en slaat nooit terug.
	var result: Dictionary = Rules.apply_melee(state, attacker.id, defender.id)
	assert_true(result.eliminated)
	assert_false(result.retaliation)

func test_retaliation_can_eliminate_attacker() -> void:
	var state := GameState.new()
	var attacker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var defender := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	_link_simple(state, attacker, 1, 4, 2)
	_link_simple(state, defender, 5, 1, 1)
	var result: Dictionary = Rules.apply_melee(state, attacker.id, defender.id)
	assert_true(result.success)
	assert_true(result.retaliation)
	assert_true(result.attacker_eliminated)
	assert_true(attacker.is_eliminated)
	assert_false(defender.is_eliminated)

func test_artillery_cannot_melee() -> void:
	var state := GameState.new()
	var gun := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.ARTILLERY)
	var _enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, gun, 3, 3, 1)
	assert_eq(Rules.get_valid_melee_targets(state, gun.id).size(), 0)

# =========================================================================
# Infanterieschot (afstand exact 2)
# =========================================================================

func test_infantry_shot_at_distance_two() -> void:
	var state := GameState.new()
	var shooter := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	_link_simple(state, shooter, 3, 1, 3)
	_link_simple(state, enemy, 5, 1, 1)
	var targets: Array = Rules.get_valid_shot_targets(state, shooter.id)
	assert_has(targets, enemy.id)
	var result: Dictionary = Rules.apply_shot(state, shooter.id, enemy.id)
	assert_true(result.success)
	# Schade = Attack − 1; schot kost 1 stamina — dus ook met 1 stamina
	# over schiet de infanterist gewoon 2 vakken ver.
	assert_eq(enemy.current_hp, 3)
	assert_eq(shooter.remaining_stamina, 0)
	# Vuur wint geen terrein.
	assert_eq(shooter.position, Vector2i(5, 5))

func test_infantry_with_one_stamina_can_still_shoot() -> void:
	# Regressie: schot kost 1 — dus ook een infanterist die al gelopen heeft
	# en nog maar 1 stamina over heeft, schiet gewoon 2 vakken ver.
	var state := GameState.new()
	var shooter := _spawn(state, Constants.PLAYER_1, Vector2i(5, 6))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	_link_simple(state, shooter, 3, 2, 3)
	_link_simple(state, enemy, 5, 1, 1)
	# Eerst 1 stap lopen (2 → 1 stamina), daarna schieten op exact afstand 2.
	assert_true(Rules.apply_move(state, shooter.id, Vector2i(5, 5)))
	assert_eq(shooter.remaining_stamina, 1)
	assert_has(Rules.get_valid_shot_targets(state, shooter.id), enemy.id)
	var result: Dictionary = Rules.apply_shot(state, shooter.id, enemy.id)
	assert_true(result.success)
	assert_eq(enemy.current_hp, 3)
	assert_eq(shooter.remaining_stamina, 0)

func test_infantry_shot_blocked_by_any_pawn() -> void:
	var state := GameState.new()
	var shooter := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var _friend := _spawn(state, Constants.PLAYER_1, Vector2i(5, 4))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	_link_simple(state, shooter, 3, 1, 3)
	_link_simple(state, enemy, 5, 1, 1)
	# Eigen pion blokkeert het schot volledig (v4.1: zonder uitzondering).
	assert_false(Rules.get_valid_shot_targets(state, shooter.id).has(enemy.id))

func test_infantry_shot_not_at_distance_one_or_three() -> void:
	var state := GameState.new()
	var shooter := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var near := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	var far := _spawn(state, Constants.PLAYER_2, Vector2i(8, 5))
	_link_simple(state, shooter, 3, 1, 3)
	_link_simple(state, near, 5, 1, 1)
	_link_simple(state, far, 5, 1, 1)
	var targets: Array = Rules.get_valid_shot_targets(state, shooter.id)
	assert_false(targets.has(near.id))
	assert_false(targets.has(far.id))

func test_infantry_attack_one_cannot_shoot() -> void:
	var state := GameState.new()
	var shooter := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var _enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	_link_simple(state, shooter, 3, 3, 1)
	assert_eq(Rules.get_valid_shot_targets(state, shooter.id).size(), 0)

func test_shot_kills_inactive_pawn_no_forced_move() -> void:
	var state := GameState.new()
	var shooter := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var statue := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	_link_simple(state, shooter, 3, 1, 3)
	var result: Dictionary = Rules.apply_shot(state, shooter.id, statue.id)
	assert_true(result.eliminated)
	assert_false(result.forced_move)
	assert_true(state.is_tile_empty(Vector2i(5, 3)))
	assert_eq(shooter.position, Vector2i(5, 5))

func test_shot_never_triggers_retaliation() -> void:
	var state := GameState.new()
	var shooter := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3), Constants.UnitType.INFANTRY)
	_link_simple(state, shooter, 3, 1, 3)
	_link_simple(state, enemy, 5, 1, 5)
	var result: Dictionary = Rules.apply_shot(state, shooter.id, enemy.id)
	assert_true(result.success)
	assert_false(result.retaliation)
	assert_eq(shooter.current_hp, 3)

func test_cavalry_cannot_shoot() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	var _enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	_link_simple(state, cav, 3, 1, 3)
	assert_eq(Rules.get_valid_shot_targets(state, cav.id).size(), 0)

# =========================================================================
# Artillerie (vaste dracht 6, dode zone op 1, 1 ding per beurt)
# =========================================================================

func test_artillery_shoots_within_range() -> void:
	var state := GameState.new()
	var gun := _spawn(state, Constants.PLAYER_1, Vector2i(5, 8), Constants.UnitType.ARTILLERY)
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, gun, 1, 4, 2)
	_link_simple(state, enemy, 5, 1, 1)
	var targets: Array = Rules.get_valid_shot_targets(state, gun.id)
	assert_has(targets, enemy.id)
	var result: Dictionary = Rules.apply_shot(state, gun.id, enemy.id)
	assert_true(result.success)
	# Volle Attack; schot kost 1 stamina.
	assert_eq(enemy.current_hp, 3)
	assert_eq(gun.position, Vector2i(5, 8))
	assert_eq(gun.remaining_stamina, 3)

func test_artillery_dead_zone_distance_one() -> void:
	var state := GameState.new()
	var gun := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.ARTILLERY)
	var adjacent := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, gun, 1, 5, 1)
	_link_simple(state, adjacent, 3, 1, 1)
	assert_false(Rules.get_valid_shot_targets(state, gun.id).has(adjacent.id))

func test_leeuw_artillery_range_seven() -> void:
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.LEEUW
	var gun := _spawn(state, Constants.PLAYER_1, Vector2i(5, 9), Constants.UnitType.ARTILLERY)
	var far := _spawn(state, Constants.PLAYER_2, Vector2i(5, 2))
	_link_simple(state, gun, 5, 1, 1)
	_link_simple(state, far, 5, 1, 1)
	# Afstand 7: raakbaar voor de Leeuw (dracht 6 + 1).
	assert_has(Rules.get_valid_shot_targets(state, gun.id), far.id)
	state.remove_pawn(far)
	var too_far := _spawn(state, Constants.PLAYER_2, Vector2i(5, 1))
	_link_simple(state, too_far, 5, 1, 1)
	assert_false(Rules.get_valid_shot_targets(state, gun.id).has(too_far.id))

func test_vos_cavalry_speed_bonus_at_link() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	var card := Card.new(state.next_card_id(), Constants.PLAYER_1, 1, 3, 2, 2)
	state.all_cards[card.id] = card
	cav.link_card(card, 0, 1)  # Vos-perk: sessie geeft cavalerie +1 Speed
	assert_eq(cav.max_stamina, 3)
	assert_eq(cav.remaining_stamina, 3)

func test_artillery_fixed_range_six() -> void:
	var state := GameState.new()
	var gun := _spawn(state, Constants.PLAYER_1, Vector2i(5, 9), Constants.UnitType.ARTILLERY)
	var in_range := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	# Dracht hangt níét van Speed af: ook met Speed 1 raak je op afstand 6.
	_link_simple(state, gun, 5, 1, 1)
	_link_simple(state, in_range, 5, 1, 1)
	assert_has(Rules.get_valid_shot_targets(state, gun.id), in_range.id)
	state.remove_pawn(in_range)
	var out_of_range := _spawn(state, Constants.PLAYER_2, Vector2i(5, 2))
	_link_simple(state, out_of_range, 5, 1, 1)
	# Afstand 7 > 6: buiten de vaste dracht.
	assert_false(Rules.get_valid_shot_targets(state, gun.id).has(out_of_range.id))

func test_artillery_line_blocked_by_any_pawn() -> void:
	var state := GameState.new()
	var gun := _spawn(state, Constants.PLAYER_1, Vector2i(5, 8), Constants.UnitType.ARTILLERY)
	var _blocker := _spawn(state, Constants.PLAYER_1, Vector2i(5, 6))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, gun, 1, 4, 2)
	_link_simple(state, enemy, 5, 1, 1)
	assert_false(Rules.get_valid_shot_targets(state, gun.id).has(enemy.id))

func test_artillery_one_thing_per_turn_until_stamina_runs_out() -> void:
	var state := GameState.new()
	var gun := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.ARTILLERY)
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	var enemy2 := _spawn(state, Constants.PLAYER_2, Vector2i(5, 2))
	_link_simple(state, gun, 5, 2, 1)
	# Speed 2 = 2 acties deze cyclus; per beurt 1 ding (max 1 stap per zet-actie).
	assert_true(Rules.get_valid_moves(state, gun.id).size() <= 4)
	var r1: Dictionary = Rules.apply_shot(state, gun.id, enemy.id)
	assert_true(r1.success)
	assert_eq(gun.remaining_stamina, 1)
	# Tweede schot mag ook nog (nieuw doelwit in de vrijgekomen lijn).
	var r2: Dictionary = Rules.apply_shot(state, gun.id, enemy2.id)
	assert_true(r2.success)
	assert_eq(gun.remaining_stamina, 0)
	# Op: niets meer.
	assert_eq(Rules.get_valid_shot_targets(state, gun.id).size(), 0)
	assert_eq(Rules.get_valid_moves(state, gun.id).size(), 0)

# =========================================================================
# Cavalerie-charge
# =========================================================================

func test_charge_move_and_attack_in_one_action() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 7), Constants.UnitType.CAVALRY)
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, cav, 3, 3, 2)
	_link_simple(state, enemy, 5, 1, 1)
	# 2 stappen + aanval = 3 stamina.
	var result: Dictionary = Rules.apply_charge(state, cav.id, Vector2i(5, 5), enemy.id)
	assert_true(result.success)
	assert_true(result.moved)
	assert_eq(enemy.current_hp, 3)
	assert_eq(cav.remaining_stamina, 0)
	assert_eq(cav.position, Vector2i(5, 5))

func test_charge_needs_stamina_for_move_plus_attack() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 8), Constants.UnitType.CAVALRY)
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, cav, 3, 3, 2)
	_link_simple(state, enemy, 5, 1, 1)
	# 3 stappen + aanval = 4 > Speed 3 → ongeldig; de aanval moet betaald kunnen worden.
	var result: Dictionary = Rules.apply_charge(state, cav.id, Vector2i(5, 5), enemy.id)
	assert_false(result.success)
	assert_eq(cav.remaining_stamina, 3)

func test_charge_kill_forced_move_extends_reach() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 7), Constants.UnitType.CAVALRY)
	var statue := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, cav, 3, 3, 2)
	# 2 stappen (2) + aanval (1) + verplichte verplaatsing (gratis) = 3 vakken winst.
	var result: Dictionary = Rules.apply_charge(state, cav.id, Vector2i(5, 5), statue.id)
	assert_true(result.eliminated)
	assert_true(result.forced_move)
	assert_eq(cav.position, Vector2i(5, 4))

func test_charge_zero_steps_without_attack_invalid() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	_link_simple(state, cav, 3, 3, 2)
	var result: Dictionary = Rules.apply_charge(state, cav.id, Vector2i(5, 5), -1)
	assert_false(result.success)
	assert_eq(cav.remaining_stamina, 3)

func test_charge_move_only_is_valid() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	_link_simple(state, cav, 3, 3, 2)
	var result: Dictionary = Rules.apply_charge(state, cav.id, Vector2i(5, 3), -1)
	assert_true(result.success)
	assert_eq(cav.position, Vector2i(5, 3))
	assert_eq(cav.remaining_stamina, 1)

func test_charge_triggers_retaliation() -> void:
	var state := GameState.new()
	var cav := _spawn(state, Constants.PLAYER_1, Vector2i(5, 7), Constants.UnitType.CAVALRY)
	var defender := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	_link_simple(state, cav, 3, 3, 2)
	_link_simple(state, defender, 5, 1, 1)
	var result: Dictionary = Rules.apply_charge(state, cav.id, Vector2i(5, 5), defender.id)
	assert_true(result.retaliation)
	assert_eq(cav.current_hp, 2)

func test_infantry_cannot_charge() -> void:
	var state := GameState.new()
	var inf := _spawn(state, Constants.PLAYER_1, Vector2i(5, 8))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, inf, 3, 3, 2)
	_link_simple(state, enemy, 5, 1, 1)
	var result: Dictionary = Rules.apply_charge(state, inf.id, Vector2i(5, 5), enemy.id)
	assert_false(result.success)

# =========================================================================
# Doctrines: Beer, Wolf, Vos
# =========================================================================

func test_beer_hp_bonus_at_link() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	_link_simple(state, pawn, 5, 1, 1, 1)
	assert_eq(pawn.current_hp, 6)
	assert_eq(pawn.max_hp, 6)

func test_beer_speed_cap_in_card_validation() -> void:
	assert_false(Card.is_valid_stats(2, 4, 1, 7, 3))
	assert_true(Card.is_valid_stats(2, 3, 2, 7, 3))

func test_wolf_step_available_after_melee() -> void:
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.WOLF
	var wolf := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var defender := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	_link_simple(state, wolf, 3, 2, 1)
	_link_simple(state, defender, 5, 1, 1)
	# Doelwit overleeft — juist dan ook een stap (prikken en wegstappen).
	var result: Dictionary = Rules.apply_melee(state, wolf.id, defender.id)
	assert_true(result.success)
	assert_true(result.wolf_step_available)
	assert_true(Rules.apply_wolf_step(state, wolf.id, Vector2i(4, 5)))
	assert_eq(wolf.position, Vector2i(4, 5))

func test_wolf_step_not_for_other_doctrines() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var defender := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY)
	_link_simple(state, pawn, 3, 2, 1)
	_link_simple(state, defender, 5, 1, 1)
	var result: Dictionary = Rules.apply_melee(state, pawn.id, defender.id)
	assert_false(result.wolf_step_available)

func test_wolf_step_not_after_shot() -> void:
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.WOLF
	var wolf := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 3))
	_link_simple(state, wolf, 3, 1, 3)
	_link_simple(state, enemy, 5, 1, 1)
	var result: Dictionary = Rules.apply_shot(state, wolf.id, enemy.id)
	assert_true(result.success)
	assert_false(result.wolf_step_available)

func test_vos_card_hidden_until_damage() -> void:
	var state := GameState.new()
	var vos := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(5, 4))
	_link_simple(state, vos, 3, 2, 2)
	vos.card_revealed = false  # gedekt gekoppeld (sessie doet dit voor Vos)
	_link_simple(state, enemy, 5, 1, 1)
	# Bewegen onthult niet.
	Rules.apply_move(state, vos.id, Vector2i(4, 5))
	assert_false(vos.card_revealed)
	vos.remaining_stamina = vos.max_stamina
	state.set_pawn_position(vos, Vector2i(5, 5))
	# Schade toebrengen onthult.
	Rules.apply_melee(state, vos.id, enemy.id)
	assert_true(vos.card_revealed)

# =========================================================================
# Winnen, kunnen handelen, initiatief
# =========================================================================

func test_win_when_two_pawns_in_haven() -> void:
	var state := GameState.new()
	var _p1 := _spawn(state, Constants.PLAYER_1, Vector2i(0, 0))
	var _p2 := _spawn(state, Constants.PLAYER_1, Vector2i(5, 0))
	assert_eq(Rules.check_win(state), Constants.PLAYER_1)

func test_no_win_one_pawn_in_haven() -> void:
	var state := GameState.new()
	_spawn(state, Constants.PLAYER_1, Vector2i(0, 0))
	_spawn(state, Constants.PLAYER_2, Vector2i(5, 5))
	assert_eq(Rules.check_win(state), -1)

func test_win_when_opponent_eliminated() -> void:
	var state := GameState.new()
	_spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	assert_eq(Rules.check_win(state), Constants.PLAYER_1)

func test_can_pawn_act_blocked_by_friends() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	_spawn(state, Constants.PLAYER_1, Vector2i(5, 4))
	_spawn(state, Constants.PLAYER_1, Vector2i(5, 6))
	_spawn(state, Constants.PLAYER_1, Vector2i(4, 5))
	_spawn(state, Constants.PLAYER_1, Vector2i(6, 5))
	_link_simple(state, pawn, 3, 3, 1)
	assert_false(Rules.can_pawn_act(state, pawn.id))

func test_can_pawn_act_blocked_but_can_attack() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	_spawn(state, Constants.PLAYER_1, Vector2i(5, 4))
	_spawn(state, Constants.PLAYER_1, Vector2i(5, 6))
	_spawn(state, Constants.PLAYER_1, Vector2i(4, 5))
	var enemy := _spawn(state, Constants.PLAYER_2, Vector2i(6, 5))
	_link_simple(state, pawn, 3, 3, 1)
	_link_simple(state, enemy, 3, 1, 1)
	assert_true(Rules.can_pawn_act(state, pawn.id))

func test_pawn_without_stamina_cannot_act() -> void:
	var state := GameState.new()
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5))
	_link_simple(state, pawn, 3, 1, 1)
	# Speed 1: één stap en de voorraad is op.
	Rules.apply_move(state, pawn.id, Vector2i(5, 4))
	assert_eq(pawn.remaining_stamina, 0)
	assert_false(Rules.can_pawn_act(state, pawn.id))

func test_initiative_attack_bid_wins() -> void:
	var state := GameState.new()
	state.cards_revealed[Constants.PLAYER_1] = [
		Card.new(0, 1, 1, 2, 2, 3),
		Card.new(1, 1, 1, 2, 2, 3),
		Card.new(2, 1, 1, 2, 2, 3),
	]
	state.cards_revealed[Constants.PLAYER_2] = [
		Card.new(3, 2, 1, 5, 1, 1),
		Card.new(4, 2, 1, 5, 1, 1),
		Card.new(5, 2, 1, 5, 1, 1),
	]
	var result: Dictionary = Rules.compute_initiative(state)
	assert_eq(result.winner, Constants.PLAYER_1)
	assert_false(result.needs_rps)

func test_initiative_speed_bid_tiebreak() -> void:
	var state := GameState.new()
	state.cards_revealed[Constants.PLAYER_1] = [
		Card.new(0, 1, 1, 3, 1, 3),
		Card.new(1, 1, 1, 3, 1, 3),
		Card.new(2, 1, 1, 3, 1, 3),
	]
	state.cards_revealed[Constants.PLAYER_2] = [
		Card.new(3, 2, 1, 1, 3, 3),
		Card.new(4, 2, 1, 1, 3, 3),
		Card.new(5, 2, 1, 1, 3, 3),
	]
	var result: Dictionary = Rules.compute_initiative(state)
	assert_eq(result.winner, Constants.PLAYER_2)

func test_initiative_full_tie_is_deterministic() -> void:
	var state := GameState.new()
	state.cards_revealed[Constants.PLAYER_1] = [
		Card.new(0, 1, 1, 3, 2, 2),
		Card.new(1, 1, 1, 3, 2, 2),
		Card.new(2, 1, 1, 3, 2, 2),
	]
	state.cards_revealed[Constants.PLAYER_2] = [
		Card.new(3, 2, 1, 3, 2, 2),
		Card.new(4, 2, 1, 3, 2, 2),
		Card.new(5, 2, 1, 3, 2, 2),
	]
	# Ronde 1 van Cyclus 1: Speler 1 wint de tiebreak.
	var result: Dictionary = Rules.compute_initiative(state)
	assert_false(result.needs_rps)
	assert_eq(result.winner, Constants.PLAYER_1)
	# Later in de partij: de vorige initiatiefhouder wint.
	state.cycle = 2
	state.last_initiative_winner = Constants.PLAYER_2
	var result2: Dictionary = Rules.compute_initiative(state)
	assert_eq(result2.winner, Constants.PLAYER_2)

func test_initiative_bid_normalizes_budgets() -> void:
	# IJkpunten uit v4.1 §4.3-B: alles-op-attack = bod 1.0 bij elke doctrine.
	var muis_cards: Array = []
	for i in 4:
		muis_cards.append(Card.new(i, 1, 1, 1, 1, 3))
	assert_eq(Rules.compute_bid(muis_cards, 5, "attack"), 1.0)
	var leeuw_cards: Array = [
		Card.new(0, 2, 1, 1, 1, 7),
		Card.new(1, 2, 1, 1, 1, 7),
	]
	assert_eq(Rules.compute_bid(leeuw_cards, 9, "attack"), 1.0)
	var mens_cards: Array = [
		Card.new(0, 1, 1, 1, 1, 5),
		Card.new(1, 1, 1, 1, 1, 5),
		Card.new(2, 1, 1, 1, 1, 5),
	]
	assert_eq(Rules.compute_bid(mens_cards, 7, "attack"), 1.0)

func test_gamestate_clone_independence() -> void:
	var state := GameState.new()
	state.doctrines[Constants.PLAYER_1] = Constants.Doctrine.WOLF
	var pawn := _spawn(state, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.CAVALRY)
	_link_simple(state, pawn, 3, 3, 2)
	var copy: GameState = state.clone()
	copy.pawns[pawn.id].position = Vector2i(0, 0)
	copy.pawns[pawn.id].current_hp = 999
	copy.pawns[pawn.id].remaining_stamina = 0
	copy.doctrines[Constants.PLAYER_1] = Constants.Doctrine.MENS
	assert_eq(state.pawns[pawn.id].position, Vector2i(5, 5))
	assert_eq(state.pawns[pawn.id].current_hp, 3)
	assert_eq(state.pawns[pawn.id].remaining_stamina, 3)
	assert_eq(state.pawns[pawn.id].unit_type, Constants.UnitType.CAVALRY)
	assert_eq(state.doctrine_of(Constants.PLAYER_1), Constants.Doctrine.WOLF)
