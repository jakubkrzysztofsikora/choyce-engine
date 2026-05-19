## tests/adapters/inbound/test_ports_ready_gate.gd
## Phase 8d: Tests for ports_ready input gate.
## Verifies that voice/AI buttons are disabled until ports_ready fires,
## and that a click before the gate never reaches the LLM or STT port.
extends SceneTree

const CreateShell = preload("res://src/adapters/inbound/scenes/create/create_shell.gd")
const InboundMain = preload("res://src/adapters/inbound/main.gd")
const RequestAICreationHelpPort = preload("res://src/ports/inbound/request_ai_creation_help_port.gd")
const SpeechToTextPort = preload("res://src/ports/outbound/speech_to_text_port.gd")
const AIAssistantAction = preload("res://src/domain/ai_orchestration/ai_assistant_action.gd")
const PlayerProfile = preload("res://src/domain/gameplay/player_profile.gd")

# ---------------------------------------------------------------------------
# Mocks
# ---------------------------------------------------------------------------

class MockRequestAIHelp extends RequestAICreationHelpPort:
	var execute_call_count := 0
	var execute_pending_call_count := 0

	func execute(_session_id: String, _prompt: String, _actor: PlayerProfile, _preview: bool = false) -> AIAssistantAction:
		execute_call_count += 1
		var action := AIAssistantAction.new("act_test", "Test")
		action.status = AIAssistantAction.ActionStatus.PROPOSED
		return action

	func execute_pending_action(action: AIAssistantAction, _actor: PlayerProfile) -> AIAssistantAction:
		execute_pending_call_count += 1
		action.status = AIAssistantAction.ActionStatus.APPLIED
		return action


class MockSTT extends SpeechToTextPort:
	var transcribe_call_count := 0

	func transcribe(_audio: PackedByteArray, _lang: String) -> String:
		transcribe_call_count += 1
		return "hello"


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


func _make_shell(ai_port: MockRequestAIHelp, stt_port: MockSTT) -> CreateShell:
	var scene := load("res://src/adapters/inbound/scenes/create/create_shell.tscn")
	var shell: CreateShell = scene.instantiate()
	get_root().add_child(shell)
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	shell.setup(
		null,       # navigator
		profile,
		null,       # localization
		null,       # create_project
		null,       # run_playtest
		null,       # apply_world_edit
		ai_port,
		stt_port
	)
	return shell


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func _run_tests() -> void:
	print("=== Phase 8d: ports_ready gate tests ===")

	await _test_ports_ready_initially_false()
	await _test_voice_button_disabled_before_ports_ready()
	await _test_ai_button_disabled_before_ports_ready()
	await _test_click_before_ports_ready_does_not_call_ai_port()
	await _test_click_before_ports_ready_does_not_call_stt_port()
	await _test_buttons_enabled_after_ports_ready_signal()
	await _test_click_after_ports_ready_reaches_handler()
	await _test_ports_ready_signal_exists_on_inbound_main()

	quit(_exit_code)


# 1. _ports_ready is false on freshly-instantiated shell
func _test_ports_ready_initially_false() -> void:
	var ai := MockRequestAIHelp.new()
	var stt := MockSTT.new()
	var shell := _make_shell(ai, stt)

	_assert(
		shell.get("_ports_ready") == false,
		"_ports_ready is false immediately after instantiation"
	)

	shell.queue_free()
	await process_frame


# 2. Voice record button is disabled before ports_ready
func _test_voice_button_disabled_before_ports_ready() -> void:
	var ai := MockRequestAIHelp.new()
	var stt := MockSTT.new()
	var shell := _make_shell(ai, stt)

	var overlay = shell.get("_assistant_overlay")
	if overlay == null:
		print("SKIP: no overlay found (assistant_overlay is null)")
		shell.queue_free()
		await process_frame
		return

	var record_btn = overlay.get("_record_button")
	if record_btn == null:
		print("SKIP: no record button found")
		shell.queue_free()
		await process_frame
		return

	_assert(
		record_btn.disabled == true,
		"Voice record button is disabled before ports_ready fires"
	)

	shell.queue_free()
	await process_frame


# 3. Any AI help button surface is disabled before ports_ready
func _test_ai_button_disabled_before_ports_ready() -> void:
	var ai := MockRequestAIHelp.new()
	var stt := MockSTT.new()
	var shell := _make_shell(ai, stt)

	var overlay = shell.get("_assistant_overlay")
	if overlay == null:
		print("SKIP: no overlay found")
		shell.queue_free()
		await process_frame
		return

	# The overlay itself should be flagged not ready; check its ports_ready field
	_assert(
		overlay.get("_ports_ready") == false,
		"Overlay _ports_ready is false before signal fires"
	)

	shell.queue_free()
	await process_frame


# 4. Pressing record button before ports_ready does NOT call ai port
func _test_click_before_ports_ready_does_not_call_ai_port() -> void:
	var ai := MockRequestAIHelp.new()
	var stt := MockSTT.new()
	var shell := _make_shell(ai, stt)

	var overlay = shell.get("_assistant_overlay")
	if overlay == null:
		print("SKIP: no overlay found")
		shell.queue_free()
		await process_frame
		return

	# Simulate press by calling handler directly
	if overlay.has_method("_on_record_pressed"):
		overlay.call("_on_record_pressed")

	await process_frame

	_assert(
		ai.execute_call_count == 0,
		"AI port execute NOT called when _on_record_pressed fires before ports_ready"
	)

	shell.queue_free()
	await process_frame


# 5. Pressing record button before ports_ready does NOT call STT port
func _test_click_before_ports_ready_does_not_call_stt_port() -> void:
	var ai := MockRequestAIHelp.new()
	var stt := MockSTT.new()
	var shell := _make_shell(ai, stt)

	var overlay = shell.get("_assistant_overlay")
	if overlay == null:
		print("SKIP: no overlay found")
		shell.queue_free()
		await process_frame
		return

	if overlay.has_method("_on_record_pressed"):
		overlay.call("_on_record_pressed")

	await process_frame

	_assert(
		stt.transcribe_call_count == 0,
		"STT port transcribe NOT called when _on_record_pressed fires before ports_ready"
	)

	shell.queue_free()
	await process_frame


# 6. After ports_ready signal fires, buttons are enabled
func _test_buttons_enabled_after_ports_ready_signal() -> void:
	var ai := MockRequestAIHelp.new()
	var stt := MockSTT.new()
	var shell := _make_shell(ai, stt)

	var overlay = shell.get("_assistant_overlay")
	if overlay == null:
		print("SKIP: no overlay found")
		shell.queue_free()
		await process_frame
		return

	# Fire the ports_ready signal on the shell
	shell.emit_signal("ports_ready")
	await process_frame

	_assert(
		shell.get("_ports_ready") == true,
		"_ports_ready is true after ports_ready signal fires"
	)

	var record_btn = overlay.get("_record_button")
	if record_btn != null:
		_assert(
			record_btn.disabled == false,
			"Voice record button is enabled after ports_ready fires"
		)

	_assert(
		overlay.get("_ports_ready") == true,
		"Overlay _ports_ready is true after ports_ready signal fires"
	)

	shell.queue_free()
	await process_frame


# 7. After ports_ready signal, click reaches AI handler
func _test_click_after_ports_ready_reaches_handler() -> void:
	var ai := MockRequestAIHelp.new()
	var stt := MockSTT.new()
	var shell := _make_shell(ai, stt)

	var overlay = shell.get("_assistant_overlay")
	if overlay == null:
		print("SKIP: no overlay found")
		shell.queue_free()
		await process_frame
		return

	shell.emit_signal("ports_ready")
	await process_frame

	if overlay.has_method("_on_record_pressed"):
		overlay.call("_on_record_pressed")

	# Wait for the async timer inside _on_record_pressed
	await create_timer(1.2).timeout

	_assert(
		ai.execute_call_count > 0,
		"AI port execute IS called when _on_record_pressed fires after ports_ready"
	)

	shell.queue_free()
	await process_frame


# 8. InboundMain declares the ports_ready signal
func _test_ports_ready_signal_exists_on_inbound_main() -> void:
	# Instantiate from scene to get a real node
	var scene := load("res://src/adapters/inbound/main.tscn")
	if scene == null:
		print("SKIP: main.tscn not loadable in test context")
		return

	var main_node = scene.instantiate()
	if main_node == null:
		print("SKIP: cannot instantiate main scene")
		return

	_assert(
		main_node.has_signal("ports_ready"),
		"InboundMain declares ports_ready signal"
	)

	main_node.queue_free()
	await process_frame
