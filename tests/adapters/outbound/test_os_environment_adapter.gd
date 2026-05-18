## Adapter test for OSEnvironmentAdapter.
##
## MUST-1  absent key returns supplied default
## MUST-2  absent key with no default returns ""
## MUST-3  value from process environment returned when var is set (verified via
##          cross-check against raw OS.get_environment() call)
## MUST-4  adapter is-a EnvironmentPort
extends SceneTree


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	var adapter := OSEnvironmentAdapter.new()

	# MUST-4: type hierarchy
	checks += 1
	if not (adapter is EnvironmentPort):
		failures.append("MUST-4: OSEnvironmentAdapter must extend EnvironmentPort")

	# MUST-1: absent key → supplied default
	var absent := adapter.get_env("CHOYCE_TEST_ABSENT_ADAPTER_KEY_XYZ", "default_val")
	checks += 1
	if absent != "default_val":
		failures.append("MUST-1: absent key must return supplied default, got: " + absent)

	# MUST-2: absent key, no default → ""
	var absent_no_default := adapter.get_env("CHOYCE_TEST_ABSENT_ADAPTER_KEY_XYZ")
	checks += 1
	if absent_no_default != "":
		failures.append("MUST-2: absent key with no default must return '', got: " + absent_no_default)

	# MUST-3: cross-check against raw OS.get_environment for a key that may
	# or may not be set in the test process environment.
	# We use CHOYCE_AUDIT_IN_MEMORY as it is commonly toggled in CI.
	var raw := OS.get_environment("CHOYCE_AUDIT_IN_MEMORY")
	var via_adapter := adapter.get_env("CHOYCE_AUDIT_IN_MEMORY", "__missing__")
	checks += 1
	if raw.is_empty():
		if via_adapter != "__missing__":
			failures.append(
				"MUST-3: unset var — adapter must return default '__missing__', got: " + via_adapter
			)
	else:
		if via_adapter != raw:
			failures.append(
				"MUST-3: set var — adapter must return '%s', got: '%s'" % [raw, via_adapter]
			)

	if failures.is_empty():
		print("[PASS] OSEnvironmentAdapter (%d checks)" % checks)
		quit(0)
	else:
		print("[FAIL] OSEnvironmentAdapter")
		for item in failures:
			print("  - %s" % item)
		quit(1)
