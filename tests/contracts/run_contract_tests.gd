extends SceneTree

const TEST_SCRIPTS: Array[Script] = [
	preload("res://tests/contracts/llm_port_contract_test.gd"),
	preload("res://tests/contracts/moderation_port_contract_test.gd"),
	preload("res://tests/contracts/speech_to_text_port_contract_test.gd"),
	preload("res://tests/contracts/text_to_speech_port_contract_test.gd"),
	preload("res://tests/contracts/audio_generation_port_contract_test.gd"),
	preload("res://tests/contracts/visual_generation_port_contract_test.gd"),
	preload("res://tests/contracts/asset_repository_port_contract_test.gd"),
	preload("res://tests/contracts/project_store_port_contract_test.gd"),
	preload("res://tests/contracts/cloud_project_sync_port_contract_test.gd"),
	preload("res://tests/contracts/telemetry_port_contract_test.gd"),
	preload("res://tests/contracts/clock_port_contract_test.gd"),
	preload("res://tests/contracts/identity_consent_port_contract_test.gd"),
	preload("res://tests/contracts/localization_policy_port_contract_test.gd"),
	preload("res://tests/contracts/prompt_template_registry_port_contract_test.gd"),
	preload("res://tests/contracts/ai_memory_store_port_contract_test.gd"),
	preload("res://tests/contracts/script_repository_port_contract_test.gd"),
	preload("res://tests/contracts/publish_store_port_contract_test.gd"),
	preload("res://tests/contracts/filesystem_project_store_adapter_contract_test.gd"),
	preload("res://tests/contracts/filesystem_asset_repository_adapter_contract_test.gd"),
	preload("res://tests/contracts/system_clock_adapter_contract_test.gd"),
	preload("res://tests/contracts/local_telemetry_adapter_contract_test.gd"),
	preload("res://tests/contracts/local_consent_store_adapter_contract_test.gd"),
	preload("res://tests/contracts/in_memory_cloud_project_sync_adapter_contract_test.gd"),
	preload("res://tests/contracts/polish_localization_policy_adapter_contract_test.gd"),
	preload("res://tests/contracts/in_repo_prompt_template_registry_adapter_contract_test.gd"),
	preload("res://tests/contracts/in_memory_ai_memory_store_adapter_contract_test.gd"),
	preload("res://tests/contracts/in_memory_script_repository_adapter_contract_test.gd"),
	preload("res://tests/contracts/in_memory_publish_store_adapter_contract_test.gd"),
	preload("res://tests/contracts/domain_event_bus_contract_test.gd"),
	preload("res://tests/contracts/event_sourced_action_log_contract_test.gd"),
	preload("res://tests/contracts/apply_world_edit_service_provenance_contract_test.gd"),
	preload("res://tests/contracts/offline_autosave_service_contract_test.gd"),
	preload("res://tests/contracts/polish_first_language_policy_service_contract_test.gd"),
	preload("res://tests/contracts/compile_block_logic_service_contract_test.gd"),
	preload("res://tests/contracts/run_playtest_service_contract_test.gd"),
	preload("res://tests/contracts/ai_failsafe_controller_contract_test.gd"),
	preload("res://tests/contracts/request_gameplay_hint_service_contract_test.gd"),
	preload("res://tests/contracts/request_ai_creation_help_service_contract_test.gd"),
	preload("res://tests/contracts/prompt_template_policy_integration_contract_test.gd"),
	preload("res://tests/contracts/ai_patch_workflow_service_contract_test.gd"),
	preload("res://tests/contracts/parent_script_editor_service_contract_test.gd"),
	preload("res://tests/contracts/ai_memory_layer_service_contract_test.gd"),
	preload("res://tests/contracts/visual_asset_generation_service_contract_test.gd"),
	preload("res://tests/contracts/ai_tool_registry_contract_test.gd"),
	preload("res://tests/contracts/deterministic_tool_execution_gateway_contract_test.gd"),
	preload("res://tests/contracts/kid_status_read_model_port_contract_test.gd"),
	preload("res://tests/contracts/parent_audit_read_model_port_contract_test.gd"),
	preload("res://tests/contracts/ai_performance_read_model_port_contract_test.gd"),
	preload("res://tests/contracts/ollama_llm_adapter_contract_test.gd"),
	preload("res://tests/contracts/local_moderation_adapter_contract_test.gd"),
	preload("res://tests/contracts/safe_preset_visual_generation_adapter_contract_test.gd"),
	preload("res://tests/contracts/elevenlabs_tts_adapter_contract_test.gd"),
	preload("res://tests/contracts/elevenlabs_audio_generation_adapter_contract_test.gd"),
	preload("res://tests/contracts/audio_governance_service_contract_test.gd"),
	preload("res://tests/contracts/audit_ledger_port_contract_test.gd"),
	preload("res://tests/contracts/in_memory_audit_ledger_adapter_contract_test.gd"),
	preload("res://tests/contracts/parent_audit_read_model_adapter_contract_test.gd"),
	preload("res://tests/contracts/kid_status_read_model_contract_test.gd"),
	preload("res://tests/contracts/parent_audit_read_model_contract_test.gd"),
	preload("res://tests/contracts/ai_performance_read_model_contract_test.gd"),
	preload("res://tests/contracts/parental_policy_store_port_contract_test.gd"),
	preload("res://tests/contracts/in_memory_parental_policy_store_adapter_contract_test.gd"),
	preload("res://tests/contracts/encrypted_parental_policy_store_adapter_contract_test.gd"),
	preload("res://tests/contracts/set_parental_controls_service_contract_test.gd"),
	preload("res://tests/contracts/voice_input_moderation_service_contract_test.gd"),
	preload("res://tests/contracts/publish_workflow_services_contract_test.gd"),
	preload("res://tests/contracts/provenance_badge_localization_contract_test.gd"),
	preload("res://tests/contracts/manifest_signature_contract_test.gd"),
	preload("res://tests/contracts/encrypted_storage_port_contract_test.gd"),
	preload("res://tests/contracts/local_encrypted_storage_adapter_contract_test.gd"),
	preload("res://tests/contracts/role_token_contract_test.gd"),
	preload("res://tests/contracts/plugin_sdk_signing_contract_test.gd"),
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
		if not (test_case_variant is PortContractTest):
			failures += 1
			print("[FAIL] %s" % test_script.resource_path)
			print("  - Test script does not extend PortContractTest.")
			continue

		var test_case: PortContractTest = test_case_variant
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
	print("Contracts: %d  Checks: %d  Failed contracts: %d" % [
		TEST_SCRIPTS.size(),
		total_checks,
		failures,
	])

	quit(1 if failures > 0 else 0)
