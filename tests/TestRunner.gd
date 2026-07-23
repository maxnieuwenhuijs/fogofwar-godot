extends Node

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []
var _current_test: String = ""

func _ready() -> void:
	print("=== FOG OF WAR TEST RUNNER ===")
	_run_all()
	print("\n=== RESULTS ===")
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
	if _failures.size() > 0:
		print("\nFailures:")
		for f in _failures:
			print("  - " + f)
	var exit_code: int = 0 if _failed == 0 else 1
	get_tree().quit(exit_code)

func _run_all() -> void:
	var test_classes: Array = [
		preload("res://tests/CardTests.gd").new(),
		preload("res://tests/RulesTests.gd").new(),
		preload("res://tests/GameSessionTests.gd").new(),
		preload("res://tests/AITests.gd").new(),
		preload("res://tests/DeterminismTests.gd").new(),
	]
	for t in test_classes:
		t._runner = self
		t.run_all()

func assert_eq(actual, expected, message: String = "") -> void:
	if actual == expected:
		_passed += 1
	else:
		_failed += 1
		var msg := "%s - expected %s, got %s" % [_current_test, str(expected), str(actual)]
		if message != "":
			msg += " (%s)" % message
		_failures.append(msg)

func assert_true(cond: bool, message: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		var msg := "%s - expected true" % _current_test
		if message != "":
			msg += " (%s)" % message
		_failures.append(msg)

func assert_false(cond: bool, message: String = "") -> void:
	assert_true(not cond, message)

func assert_has(arr, item, _message: String = "") -> void:
	if arr.has(item):
		_passed += 1
	else:
		_failed += 1
		_failures.append("%s - expected collection to contain %s" % [_current_test, str(item)])

func begin_test(test_name: String) -> void:
	_current_test = test_name
	print("  Running: " + test_name)
