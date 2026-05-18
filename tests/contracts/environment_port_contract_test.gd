## Contract test for EnvironmentPort + OSEnvironmentAdapter.
##
## MUST-1  EnvironmentPort has get_env() method
## MUST-2  EnvironmentPort.get_env() returns the supplied default when key is absent
## MUST-3  EnvironmentPort.get_env() returns "" when called with no default
## MUST-4  OSEnvironmentAdapter extends EnvironmentPort
## MUST-5  OSEnvironmentAdapter.get_env() returns default when env var is not set
## MUST-6  OSEnvironmentAdapter.get_env() returns the env-var value when it is set
class_name EnvironmentPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	# MUST-1: port exposes get_env method
	var port := EnvironmentPort.new()
	_assert_has_method(port, "get_env")

	# MUST-2: default implementation returns the supplied default value
	var result_with_default := port.get_env("CHOYCE_PORT_CONTRACT_ABSENT_KEY_12345", "my_default")
	_assert_eq(
		result_with_default,
		"my_default",
		"EnvironmentPort.get_env() must return supplied default for absent key"
	)

	# MUST-3: default implementation returns "" when no default supplied
	var result_no_default := port.get_env("CHOYCE_PORT_CONTRACT_ABSENT_KEY_12345")
	_assert_eq(
		result_no_default,
		"",
		"EnvironmentPort.get_env() must return '' when no default and key absent"
	)

	# MUST-4: OSEnvironmentAdapter is-a EnvironmentPort
	var adapter := OSEnvironmentAdapter.new()
	_assert_true(
		adapter is EnvironmentPort,
		"OSEnvironmentAdapter must extend EnvironmentPort"
	)
	_assert_has_method(adapter, "get_env")

	# MUST-5: adapter returns default for a key that is definitely not set
	var absent_result := adapter.get_env("CHOYCE_PORT_CONTRACT_ABSENT_KEY_12345", "fallback")
	_assert_eq(
		absent_result,
		"fallback",
		"OSEnvironmentAdapter.get_env() must return default when env var is not set"
	)

	var absent_no_default := adapter.get_env("CHOYCE_PORT_CONTRACT_ABSENT_KEY_12345")
	_assert_eq(
		absent_no_default,
		"",
		"OSEnvironmentAdapter.get_env() must return '' when no default and var absent"
	)

	# MUST-6: adapter returns actual value when var IS set.
	# We cannot set env vars from GDScript at runtime, so we verify the
	# contract indirectly: if CHOYCE_AUDIT_IN_MEMORY is set to "1" in the
	# environment the test process runs in, the adapter must return "1".
	# If not set, the adapter must return the default — covered by MUST-5.
	# The round-trip with a real value is covered by OSEnvironmentAdapterTest.
	var known_value := OS.get_environment("CHOYCE_AUDIT_IN_MEMORY")
	var adapter_value := adapter.get_env("CHOYCE_AUDIT_IN_MEMORY", "__default__")
	if known_value.is_empty():
		_assert_eq(
			adapter_value,
			"__default__",
			"OSEnvironmentAdapter must return default when CHOYCE_AUDIT_IN_MEMORY is not set"
		)
	else:
		_assert_eq(
			adapter_value,
			known_value,
			"OSEnvironmentAdapter must return same value as OS.get_environment when var is set"
		)

	return _build_result("EnvironmentPort")
