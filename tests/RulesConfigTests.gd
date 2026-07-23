extends "res://tests/TestSuite.gd"

# F0.2 — rules_config: elke knop een test. De bestaande suites bewijzen dat de
# defaults exact het 4.1.9-hr-gedrag geven; hier testen we de niet-default standen.


func _class_name() -> String:
	return "RulesConfigTests"


## Leeg bord met default-config (Varken vs Varken).
func _empty_state() -> GameState:
	return GameState.new()


## Actieve (gekoppelde) pion met eigen kaartstats.
func _active(state: GameState, owner: int, pos: Vector2i, unit_type: int, hp: int, speed: int, attack: int) -> Pawn:
	var pawn: Pawn = state._spawn_pawn(owner, pos, unit_type)
	var card := Card.new(state.next_card_id(), owner, state.round_number, hp, speed, attack)
	state.all_cards[card.id] = card
	pawn.link_card(card)
	return pawn


## Inactieve pion (standbeeld): gespawnd zonder kaart.
func _statue(state: GameState, owner: int, pos: Vector2i) -> Pawn:
	return state._spawn_pawn(owner, pos, Constants.UnitType.INFANTRY)


# --- (e) round-trip ---------------------------------------------------------

func test_config_roundtrip_json() -> void:
	var original: Dictionary = RulesConfig.defaults().to_dict()
	var json: String = JSON.stringify(original)
	var parsed: Dictionary = JSON.parse_string(json)
	var rebuilt: Dictionary = RulesConfig.from_dict(parsed).to_dict()
	assert_eq(JSON.stringify(rebuilt), JSON.stringify(original), "dict → JSON → dict moet identiek zijn")


func test_config_from_dict_respects_overrides() -> void:
	var cfg := RulesConfig.from_dict({"pawns_in_haven_to_win": 3, "retaliation": {"cav": 5}})
	assert_eq(cfg.pawns_in_haven_to_win, 3)
	assert_eq(cfg.retaliation_for(Constants.UnitType.CAVALRY), 5)
	# Niet-genoemde velden houden hun default.
	assert_eq(cfg.inf_shot_range, 2)


# --- (a) fire_hits_inactive -------------------------------------------------

func test_fire_hits_inactive_off_statue_untargetable() -> void:
	var s := _empty_state()
	var shooter := _active(s, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 2, 2)
	_statue(s, Constants.PLAYER_2, Vector2i(5, 3))
	# Default: standbeeld op exact afstand 2 is raakbaar.
	assert_eq(Rules.get_valid_shot_targets(s, shooter.id).size(), 1)
	# Knop uit: onraakbaar.
	s.rules = RulesConfig.new()
	s.rules.fire_hits_inactive = false
	assert_eq(Rules.get_valid_shot_targets(s, shooter.id).size(), 0, "standbeeld moet onraakbaar zijn")


func test_fire_hits_inactive_off_statue_still_blocks() -> void:
	var s := _empty_state()
	s.rules.fire_hits_inactive = false
	var shooter := _active(s, Constants.PLAYER_1, Vector2i(5, 9), Constants.UnitType.ARTILLERY, 3, 2, 3)
	_statue(s, Constants.PLAYER_2, Vector2i(5, 6))
	_active(s, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY, 3, 2, 2)
	# Het standbeeld (afstand 3) is geen doelwit, maar blokkeert de lijn nog wél.
	assert_eq(Rules.get_valid_shot_targets(s, shooter.id).size(), 0)


# --- (b) statue_threshold ---------------------------------------------------

func test_statue_threshold_blocks_chip_shots() -> void:
	var s := _empty_state()
	s.rules.statue_threshold = 2
	var shooter := _active(s, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 3, 1)
	var statue := _statue(s, Constants.PLAYER_2, Vector2i(5, 3))
	var result: Dictionary = Rules.apply_shot(s, shooter.id, statue.id)
	assert_true(result.success, "schot is legaal (maar verspild)")
	assert_false(result.eliminated, "schade 1 mag een standbeeld niet elimineren bij drempel 2")
	assert_false(statue.is_eliminated)


func test_statue_threshold_met_eliminates() -> void:
	var s := _empty_state()
	s.rules.statue_threshold = 2
	var shooter := _active(s, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 3, 2)
	var statue := _statue(s, Constants.PLAYER_2, Vector2i(5, 3))
	var result: Dictionary = Rules.apply_shot(s, shooter.id, statue.id)
	assert_true(result.eliminated, "schade 2 haalt de drempel")


func test_statue_threshold_applies_to_melee() -> void:
	var s := _empty_state()
	s.rules.statue_threshold = 2
	var attacker := _active(s, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 3, 1)
	var statue := _statue(s, Constants.PLAYER_2, Vector2i(5, 4))
	var result: Dictionary = Rules.apply_melee(s, attacker.id, statue.id)
	assert_true(result.success)
	assert_false(result.eliminated, "melee-schade 1 mag een standbeeld niet elimineren bij drempel 2")
	assert_false(result.forced_move)
	assert_eq(attacker.position, Vector2i(5, 5), "geen verplichte verplaatsing zonder eliminatie")


# --- (c) stamina_model one_action -------------------------------------------

func test_one_action_model_single_action_per_cycle() -> void:
	var s := _empty_state()
	s.rules.stamina_model = "one_action"
	var pawn := _active(s, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 3, 2)
	assert_true(Rules.apply_move(s, pawn.id, Vector2i(5, 4)))
	assert_eq(pawn.remaining_stamina, 0, "na één actie is de pion klaar voor deze cyclus")
	assert_false(Rules.can_pawn_act(s, pawn.id), "tweede actie moet onmogelijk zijn")
	assert_false(Rules.apply_move(s, pawn.id, Vector2i(5, 3)))


func test_one_action_model_charge_without_extra_cost() -> void:
	var s := _empty_state()
	s.rules.stamina_model = "one_action"
	var cav := _active(s, Constants.PLAYER_1, Vector2i(5, 7), Constants.UnitType.CAVALRY, 3, 2, 2)
	_active(s, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY, 5, 2, 1)
	# Speed 2: 2 stappen + aanval. Pool-model zou 3 stamina eisen; one_action
	# behandelt de charge als één actie (stappen <= Speed volstaat).
	var result: Dictionary = Rules.apply_charge(s, cav.id, Vector2i(5, 5), s.get_pawn_at(Vector2i(5, 4)).id)
	assert_true(result.success, "charge 2 stappen + aanval moet legaal zijn onder one_action")
	assert_eq(cav.remaining_stamina, 0)


# --- (d) inf_shot_over_pawn -------------------------------------------------

func test_inf_shot_over_pawn() -> void:
	var s := _empty_state()
	var shooter := _active(s, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 2, 2)
	_active(s, Constants.PLAYER_1, Vector2i(5, 4), Constants.UnitType.INFANTRY, 3, 2, 2)  # eigen tussenpion
	var enemy := _active(s, Constants.PLAYER_2, Vector2i(5, 3), Constants.UnitType.INFANTRY, 3, 2, 2)
	assert_eq(Rules.get_valid_shot_targets(s, shooter.id).size(), 0, "default: tussenpion blokkeert")
	s.rules = RulesConfig.new()
	s.rules.inf_shot_over_pawn = true
	var targets: Array = Rules.get_valid_shot_targets(s, shooter.id)
	assert_eq(targets.size(), 1, "met de knop aan is het schot over één tussenpion legaal")
	assert_eq(targets[0], enemy.id)


func test_inf_shot_over_pawn_not_for_artillery() -> void:
	var s := _empty_state()
	s.rules.inf_shot_over_pawn = true
	var art := _active(s, Constants.PLAYER_1, Vector2i(5, 9), Constants.UnitType.ARTILLERY, 3, 2, 3)
	_active(s, Constants.PLAYER_1, Vector2i(5, 8), Constants.UnitType.INFANTRY, 3, 2, 2)
	_active(s, Constants.PLAYER_2, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 2, 2)
	assert_eq(Rules.get_valid_shot_targets(s, art.id).size(), 0, "de knop geldt alleen voor infanterie")


# --- fire_blocked uit (boogvuur, het uit/uit-alternatief) --------------------

func test_arc_fire_ignores_blockers() -> void:
	var s := _empty_state()
	s.rules.fire_blocked = false
	var art := _active(s, Constants.PLAYER_1, Vector2i(5, 9), Constants.UnitType.ARTILLERY, 3, 2, 3)
	_active(s, Constants.PLAYER_1, Vector2i(5, 7), Constants.UnitType.INFANTRY, 3, 2, 2)  # eigen blokker
	var far_enemy := _active(s, Constants.PLAYER_2, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 2, 2)
	var targets: Array = Rules.get_valid_shot_targets(s, art.id)
	assert_true(targets.has(far_enemy.id), "boogvuur schiet over de eigen blokker heen")


func test_arc_fire_with_inactive_off_skips_statues() -> void:
	var s := _empty_state()
	s.rules.fire_blocked = false
	s.rules.fire_hits_inactive = false
	var art := _active(s, Constants.PLAYER_1, Vector2i(5, 9), Constants.UnitType.ARTILLERY, 3, 2, 3)
	var statue := _statue(s, Constants.PLAYER_2, Vector2i(5, 6))
	var active_enemy := _active(s, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.INFANTRY, 3, 2, 2)
	var targets: Array = Rules.get_valid_shot_targets(s, art.id)
	assert_false(targets.has(statue.id), "standbeeld is geen doelwit")
	assert_true(targets.has(active_enemy.id), "actieve vijand erachter wel (uit/uit-model)")


# --- haven_score_cumulative --------------------------------------------------

func test_haven_cumulative_counts_touches() -> void:
	var s := _empty_state()
	s.rules.haven_score_cumulative = true
	_statue(s, Constants.PLAYER_2, Vector2i(5, 10))  # P2 leeft → geen uitroeiingswinst
	var p1 := _active(s, Constants.PLAYER_1, Vector2i(4, 1), Constants.UnitType.INFANTRY, 3, 5, 1)
	var p2 := _active(s, Constants.PLAYER_1, Vector2i(6, 1), Constants.UnitType.INFANTRY, 3, 5, 1)
	# Pion 1 raakt de haven aan en loopt weer weg.
	s.set_pawn_position(p1, Vector2i(4, 0))
	s.set_pawn_position(p1, Vector2i(4, 5))
	assert_eq(Rules.count_pawns_in_haven(s, Constants.PLAYER_1), 1, "touch blijft tellen na weglopen")
	assert_eq(Rules.check_win(s), -1, "één touch is nog geen winst")
	# Pion 2 raakt aan → 2 touches → winst.
	s.set_pawn_position(p2, Vector2i(6, 0))
	assert_eq(Rules.check_win(s), Constants.PLAYER_1)


func test_haven_default_requires_simultaneous_presence() -> void:
	var s := _empty_state()
	_statue(s, Constants.PLAYER_2, Vector2i(5, 10))  # P2 leeft → geen uitroeiingswinst
	var p1 := _active(s, Constants.PLAYER_1, Vector2i(4, 1), Constants.UnitType.INFANTRY, 3, 5, 1)
	var p2 := _active(s, Constants.PLAYER_1, Vector2i(6, 1), Constants.UnitType.INFANTRY, 3, 5, 1)
	s.set_pawn_position(p1, Vector2i(4, 0))
	s.set_pawn_position(p1, Vector2i(4, 5))  # weer weg
	s.set_pawn_position(p2, Vector2i(6, 0))
	assert_eq(Rules.count_pawns_in_haven(s, Constants.PLAYER_1), 1)
	assert_eq(Rules.check_win(s), -1, "default: touches tellen niet")


# --- per_stat_cap -------------------------------------------------------------

func test_per_stat_cap() -> void:
	assert_true(Card.is_valid_stats(3, 1, 1, 5, 0, 0), "zonder cap geldig")
	assert_false(Card.is_valid_stats(3, 1, 1, 5, 0, 2), "stat 3 boven cap 2")
	assert_true(Card.is_valid_stats(2, 2, 1, 5, 0, 2), "alles binnen cap 2")


# --- retaliation-config -------------------------------------------------------

func test_retaliation_config_override() -> void:
	var s := _empty_state()
	s.rules.retaliation = {"inf": 1, "cav": 0, "art": 0}
	var attacker := _active(s, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 5, 2, 1)
	var cav := _active(s, Constants.PLAYER_2, Vector2i(5, 4), Constants.UnitType.CAVALRY, 5, 2, 1)
	var result: Dictionary = Rules.apply_melee(s, attacker.id, cav.id)
	assert_true(result.success)
	assert_false(result.eliminated, "verdediger overleeft (5 HP - 1)")
	assert_false(result.retaliation, "cav-terugslag staat op 0 in deze config")
	assert_eq(attacker.current_hp, 5)


# --- inf_shot_full_attack uit (Attack-1, v4.1-doc-variant) --------------------

func test_inf_shot_attack_minus_one() -> void:
	var s := _empty_state()
	s.rules.inf_shot_full_attack = false
	var weak := _active(s, Constants.PLAYER_1, Vector2i(5, 5), Constants.UnitType.INFANTRY, 3, 3, 1)
	_active(s, Constants.PLAYER_2, Vector2i(5, 3), Constants.UnitType.INFANTRY, 5, 2, 1)
	assert_eq(Rules.get_valid_shot_targets(s, weak.id).size(), 0, "Aanval 1 → schade 0 → geen schot")
	var strong := _active(s, Constants.PLAYER_1, Vector2i(3, 5), Constants.UnitType.INFANTRY, 1, 3, 3)
	var enemy2 := _active(s, Constants.PLAYER_2, Vector2i(3, 3), Constants.UnitType.INFANTRY, 5, 2, 1)
	var result: Dictionary = Rules.apply_shot(s, strong.id, enemy2.id)
	assert_true(result.success)
	assert_eq(result.damage, 2, "Aanval 3 → schade 2 onder Attack-1")
	assert_eq(enemy2.current_hp, 3)


# --- doctrine-override ---------------------------------------------------------

func test_doctrine_override_via_config() -> void:
	var s := _empty_state()
	s.rules.doctrines = {Constants.Doctrine.MENS: {"budget": 9, "art_range_bonus": 2}}
	var data: Dictionary = s.doctrine_data_of(Constants.PLAYER_1)
	assert_eq(int(data.budget), 9, "override wint van DOCTRINE_DATA")
	assert_eq(int(data.art_range_bonus), 2)
	assert_eq(String(data.name), "Varken", "niet-overschreven velden blijven")
