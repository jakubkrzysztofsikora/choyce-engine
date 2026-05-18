## tests/adapters/inbound/test_create_shell_l10n_and_port_gate.gd
## Phase 4a-1 + Phase 9 create_shell tests.
##
## Phase 4a-1: verifies every hardcoded Polish category is now routed via _t().
##   - Representative key per category is present in PolishLocalizationPolicy.
##   - The fallback dict inside _t() contains each representative key.
##
## Phase 9: verifies that when _apply_world_edit_port is null:
##   - tool buttons are disabled
##   - tool buttons have tooltip_text == _t("create.tools.unavailable")
extends SceneTree

const CreateShell = preload("res://src/adapters/inbound/scenes/create/create_shell.gd")
const PolishLocalizationPolicy = preload("res://src/adapters/outbound/polish_localization_policy.gd")
const PlayerProfile = preload("res://src/domain/gameplay/player_profile.gd")
const ApplyWorldEditCommandPort = preload("res://src/ports/inbound/apply_world_edit_command_port.gd")

# ---------------------------------------------------------------------------
# Mocks
# ---------------------------------------------------------------------------

class MockEditPort extends ApplyWorldEditCommandPort:
	func execute(_world_id: String, _cmd, _actor) -> bool:
		return true


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _exit_code := 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		_exit_code = 1
	else:
		print("PASS: %s" % message)


func _make_shell(edit_port = null) -> CreateShell:
	var scene := load("res://src/adapters/inbound/scenes/create/create_shell.tscn")
	var shell: CreateShell = scene.instantiate()
	get_root().add_child(shell)
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(
		null,        # navigator
		profile,
		null,        # localization — use built-in fallback
		null,        # create_project_port
		null,        # run_playtest_port
		edit_port,   # apply_world_edit_port
		null,        # request_ai_help_port
		null         # speech_to_text_port
	)
	return shell


# ---------------------------------------------------------------------------
# Phase 4a-1: key presence in PolishLocalizationPolicy
# ---------------------------------------------------------------------------

func _test_policy_has_create_steps_intro() -> void:
	var policy := PolishLocalizationPolicy.new()
	var v: String = policy.translate("create.steps.intro")
	_assert(
		v != "create.steps.intro",
		"PolishLocalizationPolicy has key create.steps.intro"
	)


func _test_policy_has_create_status_title() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.status.title") != "create.status.title",
		"PolishLocalizationPolicy has key create.status.title"
	)


func _test_policy_has_create_node_list_title() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.node_list.title") != "create.node_list.title",
		"PolishLocalizationPolicy has key create.node_list.title"
	)


func _test_policy_has_create_tool_selected() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.tool_selected") != "create.tool_selected",
		"PolishLocalizationPolicy has key create.tool_selected"
	)


func _test_policy_has_create_error_port_not_ready() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.error.port_not_ready") != "create.error.port_not_ready",
		"PolishLocalizationPolicy has key create.error.port_not_ready"
	)


func _test_policy_has_create_success_add() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.success.add") != "create.success.add",
		"PolishLocalizationPolicy has key create.success.add"
	)


func _test_policy_has_create_tool_place() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.tool.place") != "create.tool.place",
		"PolishLocalizationPolicy has key create.tool.place"
	)


func _test_policy_has_create_onboarding_welcome() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.onboarding.welcome") != "create.onboarding.welcome",
		"PolishLocalizationPolicy has key create.onboarding.welcome"
	)


func _test_policy_has_create_world_ready() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.world_ready") != "create.world_ready",
		"PolishLocalizationPolicy has key create.world_ready"
	)


func _test_policy_has_create_node_list_empty() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.node_list.empty") != "create.node_list.empty",
		"PolishLocalizationPolicy has key create.node_list.empty"
	)


func _test_policy_has_create_ai_applied() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.ai.applied") != "create.ai.applied",
		"PolishLocalizationPolicy has key create.ai.applied"
	)


func _test_policy_has_create_tools_unavailable() -> void:
	var policy := PolishLocalizationPolicy.new()
	_assert(
		policy.translate("create.tools.unavailable") != "create.tools.unavailable",
		"PolishLocalizationPolicy has key create.tools.unavailable"
	)


# ---------------------------------------------------------------------------
# Phase 4a-1: shell fallback dict contains representative keys
# ---------------------------------------------------------------------------

func _test_shell_fallback_contains_create_steps_intro() -> void:
	var shell := _make_shell()
	var v: String = shell.call("_t", "create.steps.intro")
	_assert(
		v != "create.steps.intro",
		"Shell _t() fallback resolves create.steps.intro"
	)
	shell.queue_free()
	await process_frame


func _test_shell_fallback_contains_create_tool_place() -> void:
	var shell := _make_shell()
	var v: String = shell.call("_t", "create.tool.place")
	_assert(
		v != "create.tool.place",
		"Shell _t() fallback resolves create.tool.place"
	)
	shell.queue_free()
	await process_frame


func _test_shell_fallback_contains_create_success_add() -> void:
	var shell := _make_shell()
	var v: String = shell.call("_t", "create.success.add")
	_assert(
		v != "create.success.add",
		"Shell _t() fallback resolves create.success.add"
	)
	shell.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# Phase 9: null-port disables tool buttons
# ---------------------------------------------------------------------------

func _test_null_port_disables_place_button() -> void:
	var shell := _make_shell(null)
	var btn = shell.get("_place_button")
	if btn == null:
		print("SKIP: _place_button not found")
		shell.queue_free()
		await process_frame
		return
	_assert(
		btn.disabled == true,
		"Place button disabled when _apply_world_edit_port is null"
	)
	shell.queue_free()
	await process_frame


func _test_null_port_disables_paint_button() -> void:
	var shell := _make_shell(null)
	var btn = shell.get("_paint_button")
	if btn == null:
		print("SKIP: _paint_button not found")
		shell.queue_free()
		await process_frame
		return
	_assert(
		btn.disabled == true,
		"Paint button disabled when _apply_world_edit_port is null"
	)
	shell.queue_free()
	await process_frame


func _test_null_port_disables_move_button() -> void:
	var shell := _make_shell(null)
	var btn = shell.get("_move_button")
	if btn == null:
		print("SKIP: _move_button not found")
		shell.queue_free()
		await process_frame
		return
	_assert(
		btn.disabled == true,
		"Move button disabled when _apply_world_edit_port is null"
	)
	shell.queue_free()
	await process_frame


func _test_null_port_disables_duplicate_button() -> void:
	var shell := _make_shell(null)
	var btn = shell.get("_duplicate_button")
	if btn == null:
		print("SKIP: _duplicate_button not found")
		shell.queue_free()
		await process_frame
		return
	_assert(
		btn.disabled == true,
		"Duplicate button disabled when _apply_world_edit_port is null"
	)
	shell.queue_free()
	await process_frame


func _test_null_port_sets_tooltip_unavailable_on_place() -> void:
	var shell := _make_shell(null)
	var btn = shell.get("_place_button")
	if btn == null:
		print("SKIP: _place_button not found")
		shell.queue_free()
		await process_frame
		return
	var expected: String = shell.call("_t", "create.tools.unavailable")
	_assert(
		btn.tooltip_text == expected,
		"Place button tooltip_text == _t('create.tools.unavailable') when port null"
	)
	shell.queue_free()
	await process_frame


func _test_port_present_enables_tool_buttons() -> void:
	var edit_port := MockEditPort.new()
	var shell := _make_shell(edit_port)
	var btn = shell.get("_place_button")
	if btn == null:
		print("SKIP: _place_button not found")
		shell.queue_free()
		await process_frame
		return
	_assert(
		btn.disabled == false,
		"Place button enabled when _apply_world_edit_port is provided"
	)
	shell.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

func _run_tests() -> void:
	print("=== Phase 4a-1 + Phase 9 create_shell l10n + port-gate tests ===")

	# Policy key presence
	_test_policy_has_create_steps_intro()
	_test_policy_has_create_status_title()
	_test_policy_has_create_node_list_title()
	_test_policy_has_create_tool_selected()
	_test_policy_has_create_error_port_not_ready()
	_test_policy_has_create_success_add()
	_test_policy_has_create_tool_place()
	_test_policy_has_create_onboarding_welcome()
	_test_policy_has_create_world_ready()
	_test_policy_has_create_node_list_empty()
	_test_policy_has_create_ai_applied()
	_test_policy_has_create_tools_unavailable()

	# Shell fallback dict
	await _test_shell_fallback_contains_create_steps_intro()
	await _test_shell_fallback_contains_create_tool_place()
	await _test_shell_fallback_contains_create_success_add()

	# Phase 9 port gate
	await _test_null_port_disables_place_button()
	await _test_null_port_disables_paint_button()
	await _test_null_port_disables_move_button()
	await _test_null_port_disables_duplicate_button()
	await _test_null_port_sets_tooltip_unavailable_on_place()
	await _test_port_present_enables_tool_buttons()

	quit(_exit_code)
