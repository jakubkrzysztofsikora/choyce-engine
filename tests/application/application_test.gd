## Base test class for application layer tests.
## Similar to PortContractTest but for application services.
class_name ApplicationTest
extends RefCounted

var _checks_run: int = 0
var _failures: Array[String] = []

func run() -> Dictionary:
	push_error("ApplicationTest.run() not implemented")
	return _build_result("ApplicationTest")

func _assert_true(condition: bool, message: String) -> void:
	_checks_run += 1
	if not condition:
		_failures.append(message)

func _assert_false(condition: bool, message: String) -> void:
	_checks_run += 1
	if condition:
		_failures.append(message)

func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_checks_run += 1
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])

func _assert_ne(actual: Variant, expected: Variant, message: String) -> void:
	_checks_run += 1
	if actual == expected:
		_failures.append("%s: expected not equal to %s" % [message, str(expected)])

func _assert_null(value: Variant, message: String) -> void:
	_checks_run += 1
	if value != null:
		_failures.append("%s: expected null, got %s" % [message, str(value)])

func _assert_not_null(value: Variant, message: String) -> void:
	_checks_run += 1
	if value == null:
		_failures.append("%s: expected non-null" % message)

func _build_result(test_name: String) -> Dictionary:
	return {
		"contract": test_name,
		"passed": _failures.is_empty(),
		"checks_run": _checks_run,
		"failures": _failures.duplicate(),
	}