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

## Alleen deze suites draaien: `-- suites=SoloTests,CampaignTests`. Zonder
## argument draait alles, precies zoals voorheen. Hiermee kan de batterij over
## meerdere processen verdeeld worden (tests.ps1), wat op deze machine het
## verschil is tussen ~12 minuten en ~2 (Max, 30 juli: "kun je die batterijen
## niet wat sneller laten gaan").
func _gevraagde_suites() -> Array:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("suites="):
			var uit: Array = []
			for deel in s.substr(7).split(",", false):
				var naam := String(deel).strip_edges()
				if naam != "":
					uit.append(naam)
			return uit
	return []


## `-- deel=2/3` draait alleen elke derde test (nummer 2 van 3). Zo kan ook EEN
## trage suite over meerdere processen: SoloTests speelt complete campagnes uit
## en bepaalde in zijn eentje de wachttijd.
func _deel_filter() -> Array:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("deel="):
			var stukken := s.substr(5).split("/")
			if stukken.size() == 2 and String(stukken[0]).is_valid_int() 					and String(stukken[1]).is_valid_int():
				return [int(stukken[0]), maxi(1, int(stukken[1]))]
	return []


func _run_all() -> void:
	var alleen: Array = _gevraagde_suites()
	var deel: Array = _deel_filter()
	var test_classes: Array = [
		preload("res://tests/CardTests.gd").new(),
		preload("res://tests/RulesTests.gd").new(),
		preload("res://tests/GameSessionTests.gd").new(),
		preload("res://tests/AITests.gd").new(),
		preload("res://tests/DeterminismTests.gd").new(),
		preload("res://tests/RulesConfigTests.gd").new(),
		preload("res://tests/ValidatorTests.gd").new(),
		preload("res://tests/ReducerTests.gd").new(),
		preload("res://tests/SerializerTests.gd").new(),
		preload("res://tests/ViewTests.gd").new(),
		preload("res://tests/GoldenReplayTests.gd").new(),
		preload("res://tests/ClockTests.gd").new(),
		preload("res://tests/AgentTests.gd").new(),
		preload("res://tests/FuzzTests.gd").new(),
		preload("res://tests/SpawnTests.gd").new(),
		preload("res://tests/CpTests.gd").new(),
		preload("res://tests/CannonTests.gd").new(),
		preload("res://tests/V42AgentTests.gd").new(),
		preload("res://tests/CampaignTests.gd").new(),
		preload("res://tests/SoloTests.gd").new(),
	]
	for t in test_classes:
		if not alleen.is_empty():
			var naam := String(t.get_script().resource_path.get_file().get_basename())
			if not alleen.has(naam):
				continue
		t._runner = self
		if deel.is_empty():
			t.run_all()
		else:
			t.run_deel(int(deel[0]), int(deel[1]))

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
