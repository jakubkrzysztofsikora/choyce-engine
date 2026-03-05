extends SceneTree

const CreateShell = preload("res://src/adapters/inbound/scenes/create/create_shell.gd")
const RequestAICreationHelpPort = preload("res://src/ports/inbound/request_ai_creation_help_port.gd")
const AIAssistantAction = preload("res://src/domain/ai_orchestration/ai_assistant_action.gd")
const PlayerProfile = preload("res://src/domain/gameplay/player_profile.gd")

class MockRequestAIHelp extends RequestAICreationHelpPort:
	var last_action: AIAssistantAction
	var execute_called := false
	var execute_pending_called := false
	var pending_count := 0

	func execute(_session_id: String, _prompt: String, _actor: PlayerProfile, _preview: bool = false) -> AIAssistantAction:
		execute_called = true
		var action = AIAssistantAction.new("act_1", "Test Intent")
		action.status = AIAssistantAction.ActionStatus.PROPOSED
		action.explanation = "I will test."
		return action

	func execute_pending_action(action: AIAssistantAction, _actor: PlayerProfile) -> AIAssistantAction:
		execute_pending_called = true
		pending_count += 1
		last_action = action
		action.status = AIAssistantAction.ActionStatus.APPLIED
		return action

var _shell: CreateShell
var _mock_ai: MockRequestAIHelp
var _exit_code := 0

func _init() -> void:
	call_deferred("_run_tests")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		_exit_code = 1
	else:
		print("PASS: %s" % message)

func _run_tests() -> void:
	print("Running Voice Assistant Integration Tests...")
	
	var scene = load("res://src/adapters/inbound/scenes/create/create_shell.tscn")
	_shell = scene.instantiate()
	get_root().add_child(_shell)
	
	_mock_ai = MockRequestAIHelp.new()
	var profile = PlayerProfile.new("p1", PlayerProfile.Role.KID)
	
	# Setup shell with mock ports
	# We pass null for others as they are not needed for this test scenario
	# NOTE: The setup signature is positional. We need to respect it.
	# func setup(navigator, profile, methods...)
	# The signature has 8 args now.
	# navigator, profile, localization, create_proj, run_play, apply_edit, request_ai, stt
	
	_shell.setup(
		null, # navigator
		profile,
		null, # localization
		null, # create_proj
		null, # run_play
		null, # apply_edit
		_mock_ai,
		null  # stt
	)
	
	# Verify overlay existence
	var overlay = _shell.get("_assistant_overlay")
	_assert(overlay != null, "Overlay should be created")
	
	if overlay:
		var action = _mock_ai.execute("s1", "prompt", profile, true)
		_assert(_mock_ai.execute_called, "execute called on port")

		var card = overlay._card
		card.set_action(action)
		card.visible = true

		var adjustment_keys: Array = card.get_adjustment_keys()
		_assert(adjustment_keys.size() == 4, "Adjust flow should expose bounded choices")
		card.apply_adjustment_choice(2)
		_assert(
			str(action.reversible_patch.get("kid_adjustment", "")) == "creative",
			"Selected bounded adjustment should be stored on action"
		)
		_assert(_mock_ai.pending_count == 0, "No mutation should happen before confirm")

		card.call("_on_confirm")
		await process_frame
		_assert(_mock_ai.execute_pending_called, "execute_pending_action called on port")
		_assert(_mock_ai.last_action == action, "Action passed correctly")
		_assert(action.status == AIAssistantAction.ActionStatus.APPLIED, "Action marked APPLIED by mock")

		var second_action = _mock_ai.execute("s1", "prompt2", profile, true)
		card.set_action(second_action)
		card.visible = true
		card.call("_on_cancel")
		await process_frame
		_assert(_mock_ai.pending_count == 1, "Cancel flow should not execute pending action")

	_shell.queue_free()
	quit(_exit_code)
