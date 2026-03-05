extends SceneTree

const TEST_SCRIPTS: Array[Script] = [
	preload("res://tests/contracts/prompt_template_registry_port_contract_test.gd"),
	preload("res://tests/contracts/in_repo_prompt_template_registry_adapter_contract_test.gd"),
	preload("res://tests/contracts/prompt_template_policy_integration_contract_test.gd"),
]


func _init() -> void:
	var total_checks := 0
	var failures := 0

	for test_script in TEST_SCRIPTS:
		var test_case: PortContractTest = test_script.new()
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
	print("Tests: %d  Checks: %d  Failed tests: %d" % [
		TEST_SCRIPTS.size(),
		total_checks,
		failures,
	])

	quit(1 if failures > 0 else 0)
