extends "res://tests/TestSuite.gd"

func _class_name() -> String:
	return "CardTests"

func test_valid_stats_sum_seven_default() -> void:
	assert_true(Card.is_valid_stats(5, 1, 1))
	assert_true(Card.is_valid_stats(3, 2, 2))
	assert_true(Card.is_valid_stats(1, 1, 5))

func test_invalid_stats_wrong_sum() -> void:
	assert_false(Card.is_valid_stats(3, 3, 3))
	assert_false(Card.is_valid_stats(2, 2, 2))

func test_invalid_stats_zero() -> void:
	assert_false(Card.is_valid_stats(0, 3, 4))
	assert_false(Card.is_valid_stats(7, 0, 0))

func test_invalid_stats_negative() -> void:
	assert_false(Card.is_valid_stats(-1, 4, 4))

func test_doctrine_budgets() -> void:
	# Muis: budget 5 (extreem 1/1/3); Leeuw: budget 9 (extreem 1/1/7).
	assert_true(Card.is_valid_stats(1, 1, 3, 5))
	assert_false(Card.is_valid_stats(1, 1, 5, 5))
	assert_true(Card.is_valid_stats(1, 1, 7, 9))
	assert_true(Card.is_valid_stats(3, 3, 3, 9))
	assert_false(Card.is_valid_stats(1, 1, 5, 9))

func test_no_per_stat_cap_within_budget() -> void:
	# v4.1 §2.3: geen aparte maximum-cap per stat ("min 1, som = budget").
	assert_true(Card.is_valid_stats(1, 5, 1, 7))
	assert_true(Card.is_valid_stats(1, 1, 7, 9))

func test_beer_speed_cap() -> void:
	assert_false(Card.is_valid_stats(1, 5, 1, 7, 3))
	assert_false(Card.is_valid_stats(2, 4, 1, 7, 3))
	assert_true(Card.is_valid_stats(3, 3, 1, 7, 3))
	assert_true(Card.is_valid_stats(5, 1, 1, 7, 3))
