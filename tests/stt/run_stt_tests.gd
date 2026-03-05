extends SceneTree

const TEST_SCRIPTS: Array[Script] = [
	preload("res://tests/adapters/test_local_stt_adapter.gd"),
	preload("res://tests/adapters/test_cloud_stt_adapter.gd"),
	preload("res://tests/application/test_stt_fallback_chain.gd"),
	preload("res://tests/application/test_polish_intent_extractor.gd"),
]

func _init() -> void:
	var total_checks := 0
	var failures := 0

	for test_script in TEST_SCRIPTS:
		if test_script == null:
			failures += 1
			print("[FAIL] unknown")
			print("  - Test script failed to preload.")
			continue
		if not test_script.can_instantiate():
			failures += 1
			print("[FAIL] %s" % test_script.resource_path)
			print("  - Test script cannot be instantiated (parse or dependency error).")
			continue

		var test_case_variant: Variant = test_script.new()
		if not (test_case_variant is ApplicationTest):
			failures += 1
			print("[FAIL] %s" % test_script.resource_path)
			print("  - Test script does not extend ApplicationTest.")
			continue

		var test_case: ApplicationTest = test_case_variant
		var result: Dictionary = test_case.run()
		total_checks += result.get("checks_run", 0)

		if result.get("passed", false):
			print("[PASS] %s (%d checks)" % [
				result.get("contract", "unknown"),
				result.get("checks_run", 0),
			])
		else:
			failures += 1
			print("[FAIL] %s" % result.get("contract", "unknown"))
			for message in result.get("failures", []):
				print("  - %s" % message)

	print("")
	print("STT Tests: %d  Checks: %d  Failed tests: %d" % [
		TEST_SCRIPTS.size(),
		total_checks,
		failures,
	])

	quit(1 if failures > 0 else 0)
