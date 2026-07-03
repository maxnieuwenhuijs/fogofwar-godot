class_name TestSuite
extends RefCounted

var _runner: Node

func run_all() -> void:
	for m in get_method_list():
		var name: String = m.name
		if name.begins_with("test_"):
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
