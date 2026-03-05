class_name CreateShell
extends Control

const OnboardingServiceScript = preload("res://src/application/onboarding_service.gd")

signal world_context_changed(world_id: String)
signal selection_provenance_changed(provenance: Variant)

const SHELL_PLAY := "play"
const SHELL_LIBRARY := "library"

enum CanvasTool {
	PLACE,
	PAINT,
	MOVE,
	DUPLICATE,
}

var _navigator: ShellNavigator
var _profile: PlayerProfile
var _localization_policy: LocalizationPolicyPort
var _create_project_port: CreateProjectFromTemplatePort
var _run_playtest_port: RunPlaytestPort
var _apply_world_edit_port: ApplyWorldEditCommandPort
var _request_ai_help_port: RequestAICreationHelpPort
var _speech_to_text_port: SpeechToTextPort
var _active_tool: CanvasTool = CanvasTool.PLACE
var _active_world_id: String = ""
var _selected_node_id: String = ""
var _current_world_instance: World
var _provenance_badge: ProvenanceBadge
var _assistant_overlay: Control
var _onboarding_service # Typed dynamically to support test runtime without class cache updates
var _onboarding_overlay: Control # Typed as Control to avoid circular dependency if not strict
var _feature_flags: FeatureFlagService

@onready var _title: Label = $Layout/Header/Title
@onready var _info: Label = $Layout/Header/Info
@onready var _place_button: Button = $Layout/Tools/PlaceButton
@onready var _paint_button: Button = $Layout/Tools/PaintButton
@onready var _move_button: Button = $Layout/Tools/MoveButton
@onready var _duplicate_button: Button = $Layout/Tools/DuplicateButton
@onready var _undo_button: Button = $Layout/Actions/UndoButton
@onready var _safe_restore_button: Button = $Layout/Actions/SafeRestoreButton
@onready var _go_play_button: Button = $Layout/Actions/GoPlayButton
@onready var _go_library_button: Button = $Layout/Actions/GoLibraryButton


func _ready() -> void:
	var ProvenanceBadgeClass = load("res://src/adapters/inbound/shared/ui/provenance_badge.gd")
	if ProvenanceBadgeClass:
		_provenance_badge = ProvenanceBadgeClass.new()
		($Layout/Header).add_child(_provenance_badge)
		_provenance_badge.visible = false

	var VoiceAssistantOverlayClass = load("res://src/adapters/inbound/shared/ui/voice_assistant_overlay.gd")
	if VoiceAssistantOverlayClass:
		_assistant_overlay = VoiceAssistantOverlayClass.new()
		add_child(_assistant_overlay)
		_assistant_overlay.action_confirmed.connect(_on_ai_action_confirmed)

	var OnboardingOverlayClass = load("res://src/adapters/inbound/shared/ui/onboarding_overlay.gd")
	if OnboardingOverlayClass:
		_onboarding_overlay = OnboardingOverlayClass.new()
		add_child(_onboarding_overlay)

	_wire_actions()
	_refresh_labels()


func setup(
	navigator: ShellNavigator,
	profile: PlayerProfile,
	localization_policy: LocalizationPolicyPort,
	create_project_port: CreateProjectFromTemplatePort,
	run_playtest_port: RunPlaytestPort,
	apply_world_edit_port: ApplyWorldEditCommandPort,
	request_ai_help_port: RequestAICreationHelpPort = null,
	speech_to_text_port: SpeechToTextPort = null,
	feature_flags: FeatureFlagService = null
) -> CreateShell:
	_navigator = navigator
	_profile = profile
	_localization_policy = localization_policy
	_create_project_port = create_project_port
	_run_playtest_port = run_playtest_port
	_apply_world_edit_port = apply_world_edit_port
	_request_ai_help_port = request_ai_help_port
	_speech_to_text_port = speech_to_text_port
	_feature_flags = feature_flags

	if _provenance_badge != null and _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)

	# Initialize Onboarding Service
	_onboarding_service = OnboardingServiceScript.new()
	if _onboarding_service != null:
		_onboarding_service.step_changed.connect(_on_onboarding_step_changed)
		_onboarding_service.step_completed.connect(_on_onboarding_step_completed)
		_onboarding_service.onboarding_finished.connect(_on_onboarding_finished)
		
		# Overlay click advances welcome screen
		if _onboarding_overlay:
			_onboarding_overlay.advance_requested.connect(_onboarding_service.acknowledge_welcome)
		
		# Hook play button for onboarding tracking
		if _go_play_button:
			_go_play_button.pressed.connect(func(): _onboarding_service.record_action("play"))

		_onboarding_service.start_onboarding(_profile)

	var ai_enabled = true
	if _feature_flags != null:
		ai_enabled = _feature_flags.is_enabled("ai_generation")

	if _assistant_overlay != null:
		if ai_enabled and _request_ai_help_port != null:
			var session := "session_%d" % Time.get_unix_time_from_system()
			if _assistant_overlay.has_method("setup"):
				_assistant_overlay.setup(_speech_to_text_port, _request_ai_help_port, _profile, session)
			_assistant_overlay.visible = true
		else:
			_assistant_overlay.visible = false

	if _provenance_badge != null and _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)

	_ensure_world_context()

	if is_node_ready():
		_refresh_labels()
		_refresh_tool_states()

	return self


func set_world_context(world_id: String) -> void:
	var changed := _active_world_id != world_id
	_active_world_id = world_id
	if changed and not _active_world_id.is_empty():
		world_context_changed.emit(_active_world_id)


func set_selected_node(node_id: String) -> void:
	_selected_node_id = node_id
	_update_selection_ui()


func _update_selection_ui() -> void:
	if _provenance_badge == null:
		return

	if _current_world_instance == null or _selected_node_id.is_empty():
		_provenance_badge.visible = false
		selection_provenance_changed.emit(null)
		return

	var node = _current_world_instance.find_node(_selected_node_id)
	if node == null or node.provenance == null:
		_provenance_badge.visible = false
		selection_provenance_changed.emit(null)
		return

	_provenance_badge.set_provenance(node.provenance)
	selection_provenance_changed.emit(node.provenance)


func get_active_world_id() -> String:
	return _active_world_id


func _wire_actions() -> void:
	_place_button.pressed.connect(func() -> void:
		_set_active_tool(CanvasTool.PLACE)
		_apply_active_tool()
	)
	_paint_button.pressed.connect(func() -> void:
		_set_active_tool(CanvasTool.PAINT)
		_apply_active_tool()
	)
	_move_button.pressed.connect(func() -> void:
		_set_active_tool(CanvasTool.MOVE)
		_apply_active_tool()
	)
	_duplicate_button.pressed.connect(func() -> void:
		_set_active_tool(CanvasTool.DUPLICATE)
		_apply_active_tool()
	)
	_go_play_button.pressed.connect(func() -> void:
		_launch_playtest(false)
		if _navigator != null:
			_navigator.show_shell(SHELL_PLAY)
	)
	_go_library_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_LIBRARY)
	)


func _refresh_labels() -> void:
	_title.text = _t("ui.create.title")
	_info.text = _t("ui.create.info")
	_place_button.text = _t("ui.tool.place")
	_paint_button.text = _t("ui.tool.paint")
	_move_button.text = _t("ui.tool.move")
	_duplicate_button.text = _t("ui.tool.duplicate")
	_place_button.tooltip_text = _t("ui.tooltip.place")
	_paint_button.tooltip_text = _t("ui.tooltip.paint")
	_move_button.tooltip_text = _t("ui.tooltip.move")
	_duplicate_button.tooltip_text = _t("ui.tooltip.duplicate")
	_undo_button.text = _t("ui.common.undo")
	_safe_restore_button.text = _t("ui.common.safe_restore")
	_go_play_button.text = _t("ui.create.go_play")
	_go_library_button.text = _t("ui.create.go_library")
	_refresh_tool_states()


func _set_active_tool(tool: CanvasTool) -> void:
	_active_tool = tool
	_refresh_tool_states()


func _refresh_tool_states() -> void:
	_place_button.button_pressed = _active_tool == CanvasTool.PLACE
	_paint_button.button_pressed = _active_tool == CanvasTool.PAINT
	_move_button.button_pressed = _active_tool == CanvasTool.MOVE
	_duplicate_button.button_pressed = _active_tool == CanvasTool.DUPLICATE


func _apply_active_tool() -> void:
	if _apply_world_edit_port == null or _profile == null:
		return

	_ensure_world_context()
	if _active_world_id.is_empty():
		push_warning("CreateShell: No active world ID set, cannot apply edit.")
		return

	# Most tools require a selection, except possibly PLACE (which adds new)
	# However, if we place relative to something, we might want selection.
	# For now, if no selection and not PLACE, we return early.
	if _selected_node_id.is_empty() and _active_tool != CanvasTool.PLACE:
		return

	var command := WorldEditCommand.new()
	command.target_node_id = _selected_node_id

	match _active_tool:
		CanvasTool.PLACE:
			command.action = WorldEditCommand.Action.ADD_NODE
			var prefix := "obj"
			if not _selected_node_id.is_empty():
				prefix = _selected_node_id
			command.target_node_id = "%s_%d" % [prefix, Time.get_unix_time_from_system()]
			command.node_data = {
				"type": SceneNode.NodeType.OBJECT,
				"display_name": "Nowy obiekt",
				"position": Vector3(0, 0, 0),
			}
		CanvasTool.PAINT:
			command.action = WorldEditCommand.Action.PAINT
			command.new_state = {"paint": "kolor_przyjazny"}
		CanvasTool.MOVE:
			command.action = WorldEditCommand.Action.MOVE_NODE
			command.new_state = {"offset": Vector3(1, 0, 0)}
		CanvasTool.DUPLICATE:
			command.action = WorldEditCommand.Action.DUPLICATE_NODE
			command.node_data = {"new_id": "%s_copy" % _selected_node_id}

	var applied := _apply_world_edit_port.execute(_active_world_id, command, _profile)
	if not applied:
		return
		
	# Record action for Onboarding
	if _onboarding_service:
		var action_key = ""
		match _active_tool:
			CanvasTool.PLACE: action_key = "place"
			CanvasTool.PAINT: action_key = "paint"
			CanvasTool.MOVE: action_key = "move"
			CanvasTool.DUPLICATE: action_key = "duplicate"
		if not action_key.is_empty():
			_onboarding_service.record_action(action_key)

	if command.action == WorldEditCommand.Action.ADD_NODE:
		set_selected_node(command.target_node_id)
	elif command.action == WorldEditCommand.Action.DUPLICATE_NODE:
		set_selected_node(str(command.node_data.get("new_id", _selected_node_id)))


func _ensure_world_context() -> void:
	if not _active_world_id.is_empty():
		return
	if _create_project_port == null or _profile == null:
		return
	var project := _create_project_port.execute("starter_canvas", _profile)
	if project == null or project.worlds.is_empty():
		return
	var world_variant: Variant = project.worlds[0]
	if not (world_variant is World):
		return
	var world := world_variant as World
	_active_world_id = world.world_id
	_current_world_instance = world
	world_context_changed.emit(_active_world_id)
	if _selected_node_id.is_empty():
		set_selected_node("root_node")


func _launch_playtest(local_coop: bool = false) -> Session:
	if _run_playtest_port == null or _profile == null:
		return null
	_ensure_world_context()
	if _active_world_id.is_empty():
		return null

	var players: Array = [_profile]
	if local_coop:
		var guest := PlayerProfile.new("%s_local_guest" % _profile.profile_id, PlayerProfile.Role.KID)
		guest.display_name = "Gosc"
		players.append(guest)

	var session := _run_playtest_port.execute(_active_world_id, players)
	if session != null:
		_info.text = "Test uruchomiony: %s" % ("kooperacja" if session.mode == Session.SessionMode.CO_OP else "solo")
	return session


# -- Onboarding Handlers --

func _on_onboarding_step_changed(step_id: String, instruction_key: String) -> void:
	if not _onboarding_overlay:
		return
	
	var target: Control = null
	match step_id:
		OnboardingServiceScript.STEP_WELCOME:
			pass
		OnboardingServiceScript.STEP_PLACE_FIRST:
			target = _place_button
		OnboardingServiceScript.STEP_PAINT_FIRST:
			target = _paint_button
		OnboardingServiceScript.STEP_PLAY:
			target = _go_play_button
	
	var text: String = _t(instruction_key)
	if text.begins_with("KEY_NOT_FOUND"): 
		match step_id:
			OnboardingServiceScript.STEP_WELCOME: text = "Witaj! Zaczynamy budowanie."
			OnboardingServiceScript.STEP_PLACE_FIRST: text = "Kliknij tutaj, aby ustawic obiekt."
			OnboardingServiceScript.STEP_PAINT_FIRST: text = "Teraz pomaluj swoj obiekt."
			OnboardingServiceScript.STEP_PLAY: text = "Nacisnij Graj, aby przetestowac swiat."
			_: text = "Kontynuuj..."
	
	_onboarding_overlay.show_step(step_id, text, target)


func _on_onboarding_step_completed(step_id: String) -> void:
	if _onboarding_overlay:
		_onboarding_overlay.celebrate_completion()


func _on_onboarding_finished() -> void:
	if _onboarding_overlay:
		_onboarding_overlay.dismiss()


func _t(key: String) -> String:
	if _localization_policy != null:
		return _localization_policy.translate(key)

	var fallback := {
		"ui.create.title": "Tryb tworzenia",
		"ui.create.info": "Wybierz szablon, zbuduj świat i uruchom test.",
		"ui.tool.place": "🟦 Umieść",
		"ui.tool.paint": "🟩 Pomaluj",
		"ui.tool.move": "🔷 Przesuń",
		"ui.tool.duplicate": "🟪 Duplikuj",
		"ui.tooltip.place": "Umieść obiekt na planszy.",
		"ui.tooltip.paint": "Nadaj obiektowi kolor.",
		"ui.tooltip.move": "Przesuń zaznaczony obiekt.",
		"ui.tooltip.duplicate": "Utwórz kopię zaznaczonego obiektu.",
		"ui.common.undo": "Cofnij",
		"ui.common.safe_restore": "Przywróć bezpieczny zapis",
		"ui.create.go_play": "Przejdź do gry",
		"ui.create.go_library": "Przejdź do biblioteki"
	}
	return fallback.get(key, key)


func _on_ai_action_confirmed(action: AIAssistantAction) -> void:
	if _request_ai_help_port != null:
		var executed = _request_ai_help_port.execute_pending_action(action, _profile)
		if executed and executed.status == AIAssistantAction.ActionStatus.APPLIED:
			print("AI Action executed: ", executed.action_id)
			# Refresh UI if needed
			if not _selected_node_id.is_empty():
				set_selected_node(_selected_node_id)
