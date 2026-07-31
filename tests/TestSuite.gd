class_name TestSuite
extends RefCounted

var _runner: Node

func run_all() -> void:
	run_deel(0, 1)


## Draai alleen deel `i` van `n` (0-gebaseerd): zo kan een trage suite over
## meerdere processen. De volgorde blijft die van get_method_list(), dus elk
## deel is stabiel en samen dekken ze exact alle tests.
func run_deel(deel: int, aantal: int) -> void:
	var teller := 0
	for m in get_method_list():
		var name: String = m.name
		if not name.begins_with("test_"):
			continue
		if aantal > 1 and teller % aantal != deel:
			teller += 1
			continue
		teller += 1
		_runner.begin_test(_class_name() + "." + name)
		call(name)

func _class_name() -> String:
	return "TestSuite"

func assert_eq(actual, expected, message: String = "") -> void:
	_runner.assert_eq(actual, expected, message)

func assert_true(cond: bool, message: String = "") -> void:
	_runner.assert_true(cond, message)

func assert_false(cond: bool, message: String = "") -> void:
	_runner.assert_false(cond, message)

func assert_has(arr, item, message: String = "") -> void:
	_runner.assert_has(arr, item, message)
