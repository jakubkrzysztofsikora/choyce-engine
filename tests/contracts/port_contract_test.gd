## Base contract test for outbound ports.
## Concrete tests should verify method presence, return contract type,
## and behavior with null/empty inputs where applicable.
class_name PortContractTest
extends RefCounted

var _checks_run: int = 0
var _failures: Array[String] = []


func run() -> Dictionary:
	push_error("PortContractTest.run() not implemented")
	return _build_result("PortContractTest")


func _reset() -> void:
	_checks_run = 0
	_failures = []


func _assert_true(condition: bool, message: String) -> void:
	_checks_run += 1
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_checks_run += 1
	if actual != expected:
		_failures.append("%s (expected=%s, actual=%s)" % [message, str(expected), str(actual)])


func _assert_has_method(instance: Object, method_name: String) -> void:
	_assert_true(
		instance != null and instance.has_method(method_name),
		"Missing method: %s" % method_name
	)


func _assert_string(value: Variant, label: String) -> void:
	_assert_true(typeof(value) == TYPE_STRING, "%s should return String" % label)


func _assert_int(value: Variant, label: String) -> void:
	_assert_true(typeof(value) == TYPE_INT, "%s should return int" % label)


func _assert_bool(value: Variant, label: String) -> void:
	_assert_true(typeof(value) == TYPE_BOOL, "%s should return bool" % label)


func _assert_false(value: Variant, label: String) -> void:
	_assert_bool(value, label)
	if typeof(value) == TYPE_BOOL:
		_assert_true(value == false, "%s should default to false" % label)


func _assert_dictionary(value: Variant, label: String) -> void:
	_assert_true(value is Dictionary, "%s should return Dictionary" % label)


func _assert_array(value: Variant, label: String) -> void:
	_assert_true(value is Array, "%s should return Array" % label)


func _assert_packed_byte_array(value: Variant, label: String) -> void:
	_assert_true(
		value is PackedByteArray,
		"%s should return PackedByteArray" % label
	)


func _assert_project(value: Variant, label: String) -> void:
	_assert_true(value is Project, "%s should return Project" % label)


func _assert_moderation_result(value: Variant, label: String) -> void:
	_assert_true(
		value is ModerationResult,
		"%s should return ModerationResult" % label
	)


func _assert_moderation_blocked(value: Variant, label: String) -> void:
	_assert_moderation_result(value, label)
	if value is ModerationResult:
		_assert_true(
			value.is_blocked(),
			"%s should default to blocked verdict for safety" % label
		)


func _assert_tool_invocation_array(value: Variant, label: String) -> void:
	_assert_true(value is Array, "%s should return Array" % label)
	if value is Array:
		for item in value:
			_assert_true(
				item is ToolInvocation,
				"%s should contain only ToolInvocation items" % label
			)


func _assert_null(value: Variant, label: String) -> void:
	_assert_true(value == null, "%s should be null" % label)


func _note_check() -> void:
	_assert_true(true, "check completed")


func _build_result(contract_name: String) -> Dictionary:
	return {
		"contract": contract_name,
		"passed": _failures.is_empty(),
		"checks_run": _checks_run,
		"failures": _failures.duplicate(),
	}
