class_name CreateShell
extends Control

const OnboardingServiceScript = preload("res://src/application/onboarding_service.gd")
const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")
const ThemeManager = preload("res://src/adapters/inbound/shared/ui/theme_manager.gd")

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
var _event_bus: DomainEventBus = null
var _active_tool: CanvasTool = CanvasTool.PLACE
var _active_world_id: String = ""
var _selected_node_id: String = ""
var _current_world_instance: World
var _provenance_badge: ProvenanceBadge
var _assistant_overlay: Control
var _onboarding_service
var _onboarding_overlay: Control
var _feature_flags: FeatureFlagService
var _node_list_ids: Array[String] = []
var _active_palette: String = "city_sunrise"
var _template_buttons: Array[Button] = []

@onready var _title: Label = $Layout/Header/Title
@onready var _info: Label = $Layout/Header/Info
@onready var _template_scroll: ScrollContainer = $Layout/TemplateScroll
@onready var _template_list: HBoxContainer = $Layout/TemplateScroll/TemplateList
@onready var _workspace_card: PanelContainer = $Layout/WorkspaceCard
@onready var _workspace: VBoxContainer = $Layout/WorkspaceCard/WorkspaceLayout/Workspace
@onready var _status_title: Label = $Layout/WorkspaceCard/WorkspaceLayout/Workspace/StatusTitle
@onready var _status_message: Label = $Layout/WorkspaceCard/WorkspaceLayout/Workspace/StatusMessage
@onready var _world_summary: Label = $Layout/WorkspaceCard/WorkspaceLayout/Workspace/WorldSummary
@onready var _selection_label: Label = $Layout/WorkspaceCard/WorkspaceLayout/Workspace/SelectionLabel
@onready var _node_list_title: Label = $Layout/WorkspaceCard/WorkspaceLayout/Workspace/NodeListTitle
@onready var _node_list: ItemList = $Layout/WorkspaceCard/WorkspaceLayout/Workspace/NodeList
@onready var _preview_panel: PanelContainer = $Layout/WorkspaceCard/WorkspaceLayout/PreviewPanel
@onready var _preview_grid: GridContainer = $Layout/WorkspaceCard/WorkspaceLayout/PreviewPanel/PreviewGrid
@onready var _place_button: Button = $Layout/Tools/PlaceButton
@onready var _paint_button: Button = $Layout/Tools/PaintButton
@onready var _move_button: Button = $Layout/Tools/MoveButton
@onready var _duplicate_button: Button = $Layout/Tools/DuplicateButton
@onready var _undo_button: Button = $Layout/Actions/UndoButton
@onready var _safe_restore_button: Button = $Layout/Actions/SafeRestoreButton
@onready var _go_play_button: Button = $Layout/Actions/GoPlayButton
@onready var _go_library_button: Button = $Layout/Actions/GoLibraryButton
@onready var _toast_banner: PanelContainer = $Layout/ToastBanner
@onready var _toast_label: Label = $Layout/ToastBanner/ToastLabel


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
	_apply_friendly_theme()
	_build_template_cards()
	_refresh_workspace_ui()
	_toast_banner.visible = false


func setup(
	navigator: ShellNavigator,
	profile: PlayerProfile,
	localization_policy: LocalizationPolicyPort,
	create_project_port: CreateProjectFromTemplatePort,
	run_playtest_port: RunPlaytestPort,
	apply_world_edit_port: ApplyWorldEditCommandPort,
	request_ai_help_port: RequestAICreationHelpPort = null,
	speech_to_text_port: SpeechToTextPort = null,
	feature_flags: FeatureFlagService = null,
	event_bus: DomainEventBus = null
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
	_event_bus = event_bus

	if _provenance_badge != null and _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)

	# Phase 7c: OnboardingService now publishes DomainEventBus events instead of Godot signals.
	# Subscribe via event_bus when available; fall back to no-op so existing tests without
	# an event_bus still construct without errors.
	_onboarding_service = OnboardingServiceScript.new()
	if _onboarding_service != null:
		if _event_bus != null:
			_onboarding_service.setup(_event_bus)
			_event_bus.subscribe("OnboardingStepChanged", _on_onboarding_step_changed_event)
			_event_bus.subscribe("OnboardingStepCompleted", _on_onboarding_step_completed_event)
			_event_bus.subscribe("OnboardingFinished", _on_onboarding_finished_event)
		if _onboarding_overlay:
			_onboarding_overlay.advance_requested.connect(_onboarding_service.acknowledge_welcome)
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
		_refresh_workspace_ui()

	return self


func set_world_context(world_id: String) -> void:
	var changed := _active_world_id != world_id
	_active_world_id = world_id
	if changed and not _active_world_id.is_empty():
		world_context_changed.emit(_active_world_id)


func set_selected_node(node_id: String) -> void:
	_selected_node_id = node_id
	_update_selection_ui()
	_refresh_workspace_ui()


func _update_selection_ui() -> void:
	if _current_world_instance == null or _selected_node_id.is_empty():
		if _provenance_badge != null:
			_provenance_badge.visible = false
		selection_provenance_changed.emit(null)
		return

	var node = _current_world_instance.find_node(_selected_node_id)
	if node == null or node.provenance == null:
		if _provenance_badge != null:
			_provenance_badge.visible = false
		selection_provenance_changed.emit(null)
		return

	if _provenance_badge != null:
		_provenance_badge.set_provenance(node.provenance)
	selection_provenance_changed.emit(node.provenance)


func get_active_world_id() -> String:
	return _active_world_id


func get_active_world() -> World:
	return _current_world_instance


func _wire_actions() -> void:
	_place_button.pressed.connect(func() -> void:
		_set_active_tool(CanvasTool.PLACE)
		_apply_active_tool()
		_animate_button_press(_place_button)
	)
	_paint_button.pressed.connect(func() -> void:
		_set_active_tool(CanvasTool.PAINT)
		_apply_active_tool()
		_animate_button_press(_paint_button)
	)
	_move_button.pressed.connect(func() -> void:
		_set_active_tool(CanvasTool.MOVE)
		_apply_active_tool()
		_animate_button_press(_move_button)
	)
	_duplicate_button.pressed.connect(func() -> void:
		_set_active_tool(CanvasTool.DUPLICATE)
		_apply_active_tool()
		_animate_button_press(_duplicate_button)
	)
	if not _node_list.item_selected.is_connected(_on_node_list_item_selected):
		_node_list.item_selected.connect(_on_node_list_item_selected)
	_go_play_button.pressed.connect(func() -> void:
		var started := _launch_playtest(false)
		if started != null and _navigator != null:
			_navigator.show_shell(SHELL_PLAY)
	)
	_go_library_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_LIBRARY)
	)


func _refresh_labels() -> void:
	_title.text = _t("ui.create.title")
	_info.text = "Twórz krok po kroku: 1) Umieść 2) Pomaluj/Przesuń 3) Przetestuj."
	_status_title.text = "Status tworzenia"
	_node_list_title.text = "Obiekty w świecie"
	_place_button.text = "%s %s" % [IconFont.get_icon("place"), _t("ui.tool.place")]
	_paint_button.text = "%s %s" % [IconFont.get_icon("paint"), _t("ui.tool.paint")]
	_move_button.text = "%s %s" % [IconFont.get_icon("move"), _t("ui.tool.move")]
	_duplicate_button.text = "%s %s" % [IconFont.get_icon("duplicate"), _t("ui.tool.duplicate")]
	_place_button.tooltip_text = _t("ui.tooltip.place")
	_paint_button.tooltip_text = _t("ui.tooltip.paint")
	_move_button.tooltip_text = _t("ui.tooltip.move")
	_duplicate_button.tooltip_text = _t("ui.tooltip.duplicate")
	_undo_button.text = "%s %s" % [IconFont.get_icon("undo"), _t("ui.common.undo")]
	_safe_restore_button.text = "%s %s" % [IconFont.get_icon("restore"), _t("ui.common.safe_restore")]
	_go_play_button.text = "%s %s" % [IconFont.get_icon("play"), _t("ui.create.go_play")]
	_go_library_button.text = "%s %s" % [IconFont.get_icon("library"), _t("ui.create.go_library")]
	_set_status_message("Wybierz narzędzie. Zacznij od \"Umieść\".", false)
	_refresh_tool_states()


func _set_active_tool(tool: CanvasTool) -> void:
	_active_tool = tool
	_refresh_tool_states()
	_set_status_message("Wybrane narzędzie: %s." % _tool_name(tool), false)


func _refresh_tool_states() -> void:
	_place_button.button_pressed = _active_tool == CanvasTool.PLACE
	_paint_button.button_pressed = _active_tool == CanvasTool.PAINT
	_move_button.button_pressed = _active_tool == CanvasTool.MOVE
	_duplicate_button.button_pressed = _active_tool == CanvasTool.DUPLICATE
	_style_tool_button(_place_button, _active_tool == CanvasTool.PLACE, Color8(120, 210, 255))
	_style_tool_button(_paint_button, _active_tool == CanvasTool.PAINT, Color8(147, 228, 170))
	_style_tool_button(_move_button, _active_tool == CanvasTool.MOVE, Color8(170, 190, 255))
	_style_tool_button(_duplicate_button, _active_tool == CanvasTool.DUPLICATE, Color8(229, 180, 255))


func _style_tool_button(button: Button, active: bool, color: Color) -> void:
	if button == null:
		return
	if active:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.corner_radius_top_left = 14
		sb.corner_radius_top_right = 14
		sb.corner_radius_bottom_left = 14
		sb.corner_radius_bottom_right = 14
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = color.darkened(0.3)
		sb.shadow_color = Color(0, 0, 0, 0.15)
		sb.shadow_size = 4
		button.add_theme_stylebox_override("normal", sb)
		button.add_theme_stylebox_override("hover", sb)
		button.add_theme_stylebox_override("pressed", sb)
	else:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
		button.remove_theme_stylebox_override("pressed")


func _animate_button_press(button: Button) -> void:
	if button == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.15, 1.15), 0.08)
	tween.tween_property(button, "scale", Vector2.ONE, 0.15)


func _apply_active_tool() -> void:
	if _apply_world_edit_port == null or _profile == null:
		_set_status_message("Tryb tworzenia nie jest jeszcze gotowy. Spróbuj uruchomić ponownie.", true)
		return

	_ensure_world_context()
	if _active_world_id.is_empty():
		_set_status_message("Nie znaleziono aktywnego świata. Kliknij \"Umieść\" jeszcze raz.", true)
		return

	if _selected_node_id.is_empty() and _active_tool != CanvasTool.PLACE:
		_set_status_message("Najpierw wybierz obiekt z listy lub dodaj nowy przez \"Umieść\".", true)
		return

	var command := WorldEditCommand.new()
	command.target_node_id = _selected_node_id

	match _active_tool:
		CanvasTool.PLACE:
			command.action = WorldEditCommand.Action.ADD_NODE
			var prefix := "obj"
			if not _selected_node_id.is_empty():
				prefix = _selected_node_id
			command.target_node_id = "%s_%d" % [prefix, Time.get_ticks_msec()]
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
			command.node_data = {"new_id": "%s_copy_%d" % [_selected_node_id, Time.get_ticks_msec()]}

	var applied := _apply_world_edit_port.execute(_active_world_id, command, _profile)
	if not applied:
		_set_status_message("Zmiana nie została zapisana. Wybierz inny obiekt i spróbuj ponownie.", true)
		return

	_apply_command_to_local_world(command)
		
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

	_set_status_message(_success_message_for(command), false)
	_refresh_workspace_ui()
	_update_preview_grid()


func _ensure_world_context() -> void:
	if not _active_world_id.is_empty():
		return
	if _create_project_port == null or _profile == null:
		_set_status_message("Brak konfiguracji projektu. Tryb tworzenia jest nieaktywny.", true)
		return
	var project := _create_project_port.execute("starter_canvas", _profile)
	if project == null or project.worlds.is_empty():
		_set_status_message("Nie udało się utworzyć nowego świata.", true)
		return
	var world_variant: Variant = project.worlds[0]
	if not (world_variant is World):
		_set_status_message("Świat ma niepoprawny format.", true)
		return
	var world := world_variant as World
	_active_world_id = world.world_id
	_current_world_instance = world
	world_context_changed.emit(_active_world_id)
	if _current_world_instance.scene_nodes.is_empty():
		set_selected_node("")
	else:
		var first_node: Variant = _current_world_instance.scene_nodes[0]
		if first_node is SceneNode:
			set_selected_node((first_node as SceneNode).node_id)
	_set_status_message("Świat gotowy. Dodaj pierwszy obiekt przez \"Umieść\".", false)
	_refresh_workspace_ui()
	_update_preview_grid()


func _launch_playtest(local_coop: bool = false) -> Session:
	if _run_playtest_port == null or _profile == null:
		_set_status_message("Playtest jest chwilowo niedostępny.", true)
		return null
	_ensure_world_context()
	if _active_world_id.is_empty():
		_set_status_message("Najpierw utwórz świat przed startem playtestu.", true)
		return null

	var players: Array = [_profile]
	if local_coop:
		var guest := PlayerProfile.new("%s_local_guest" % _profile.profile_id, PlayerProfile.Role.KID)
		guest.display_name = "Gość"
		players.append(guest)

	var session := _run_playtest_port.execute(_active_world_id, players)
	if session != null:
		_info.text = "Test uruchomiony: %s" % ("kooperacja" if session.mode == Session.SessionMode.CO_OP else "solo")
		_set_status_message("Playtest uruchomiony. Możesz przejść do zakładki \"Graj\".", false)
	else:
		_set_status_message("Playtest nie wystartował. Dodaj obiekt i spróbuj ponownie.", true)
	return session


func _apply_command_to_local_world(command: WorldEditCommand) -> void:
	if _current_world_instance == null or command == null:
		return

	match command.action:
		WorldEditCommand.Action.ADD_NODE:
			var added := SceneNode.new(
				str(command.target_node_id),
				int(command.node_data.get("type", SceneNode.NodeType.OBJECT))
			)
			added.display_name = str(command.node_data.get("display_name", command.target_node_id))
			added.position = command.node_data.get("position", Vector3.ZERO)
			var props: Variant = command.node_data.get("properties", {})
			added.properties = props.duplicate(true) if props is Dictionary else {}
			_current_world_instance.add_node(added)
		WorldEditCommand.Action.PAINT, \
		WorldEditCommand.Action.MOVE_NODE, \
		WorldEditCommand.Action.CHANGE_PROPERTY:
			var node := _current_world_instance.find_node(command.target_node_id)
			if node == null:
				return
			for key in command.new_state.keys():
				node.properties[key] = command.new_state[key]
			if command.action == WorldEditCommand.Action.MOVE_NODE:
				var offset: Variant = command.new_state.get("offset", Vector3.ZERO)
				if offset is Vector3:
					node.position = node.position + offset
		WorldEditCommand.Action.DUPLICATE_NODE:
			var source := _current_world_instance.find_node(command.target_node_id)
			if source == null:
				return
			var copy_id := str(command.node_data.get("new_id", "%s_copy" % command.target_node_id))
			var duplicate := SceneNode.new(copy_id, source.node_type)
			duplicate.display_name = "%s kopia" % source.display_name if not source.display_name.is_empty() else copy_id
			duplicate.position = source.position + Vector3(1, 0, 0)
			duplicate.rotation = source.rotation
			duplicate.scale = source.scale
			duplicate.properties = source.properties.duplicate(true)
			duplicate.provenance = source.provenance
			_current_world_instance.add_node(duplicate)


func _refresh_workspace_ui() -> void:
	if _world_summary == null or _selection_label == null or _node_list == null:
		return

	if _current_world_instance == null:
		_world_summary.text = "Świat: brak | Obiekty: 0"
		_selection_label.text = "Zaznaczenie: brak"
		_node_list.clear()
		_node_list_ids = []
		_node_list.add_item("Brak obiektów. Kliknij \"Umieść\".")
		_node_list.set_item_disabled(0, true)
		return

	var node_count := _current_world_instance.scene_nodes.size()
	_world_summary.text = "Świat: %s | Obiekty: %d" % [_active_world_id, node_count]
	_selection_label.text = (
		"Zaznaczenie: %s" % _selected_node_id
		if not _selected_node_id.is_empty()
		else "Zaznaczenie: brak"
	)

	_node_list.clear()
	_node_list_ids = []
	for node_variant in _current_world_instance.scene_nodes:
		if not (node_variant is SceneNode):
			continue
		var node: SceneNode = node_variant
		_node_list_ids.append(node.node_id)
		var title := node.display_name if not node.display_name.is_empty() else "Obiekt"
		_node_list.add_item("%s (%s)" % [title, node.node_id])

	if _node_list_ids.is_empty():
		_node_list.add_item("Brak obiektów. Kliknij \"Umieść\".")
		_node_list.set_item_disabled(0, true)
		return

	var selected_index := _node_list_ids.find(_selected_node_id)
	if selected_index >= 0:
		_node_list.select(selected_index)


func _on_node_list_item_selected(index: int) -> void:
	if index < 0 or index >= _node_list_ids.size():
		return
	set_selected_node(_node_list_ids[index])
	_set_status_message("Wybrano obiekt: %s." % _node_list_ids[index], false)


func _set_status_message(message: String, is_error: bool) -> void:
	if _status_message == null:
		return
	_status_message.text = message
	_status_message.modulate = Color(0.78, 0.16, 0.25, 1.0) if is_error else Color(0.11, 0.17, 0.30, 1.0)
	_show_toast(message, is_error)


func _show_toast(message: String, is_error: bool) -> void:
	if _toast_label == null or _toast_banner == null:
		return
	_toast_label.text = message
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	if is_error:
		style.bg_color = Color(1.0, 0.88, 0.88, 0.95)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.78, 0.16, 0.25, 1.0)
	else:
		style.bg_color = Color(0.9, 0.97, 1.0, 0.95)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.75, 1.0, 1.0)
	_toast_banner.add_theme_stylebox_override("panel", style)
	_toast_banner.visible = true
	_toast_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_toast_banner, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(_toast_banner) and _toast_banner != null:
		var out := create_tween()
		out.tween_property(_toast_banner, "modulate:a", 0.0, 0.4)
		out.finished.connect(func(): if is_instance_valid(_toast_banner): _toast_banner.visible = false)


func _tool_name(tool: CanvasTool) -> String:
	match tool:
		CanvasTool.PLACE:
			return "Umieść"
		CanvasTool.PAINT:
			return "Pomaluj"
		CanvasTool.MOVE:
			return "Przesuń"
		CanvasTool.DUPLICATE:
			return "Duplikuj"
	return "Narzędzie"


func _success_message_for(command: WorldEditCommand) -> String:
	match command.action:
		WorldEditCommand.Action.ADD_NODE:
			return "Dodano nowy obiekt: %s." % command.target_node_id
		WorldEditCommand.Action.PAINT:
			return "Pomalowano obiekt: %s." % command.target_node_id
		WorldEditCommand.Action.MOVE_NODE:
			return "Przesunięto obiekt: %s." % command.target_node_id
		WorldEditCommand.Action.DUPLICATE_NODE:
			return "Utworzono kopię obiektu."
	return "Zmiana zapisana."


func _apply_friendly_theme() -> void:
	var theme := load("res://data/themes/choyce_theme.tres") as Theme
	if theme != null:
		self.theme = theme
		ThemeManager.apply_palette_to_theme(theme, _active_palette)

	if _workspace_card != null:
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color8(245, 252, 255)
		card_style.corner_radius_top_left = 18
		card_style.corner_radius_top_right = 18
		card_style.corner_radius_bottom_left = 18
		card_style.corner_radius_bottom_right = 18
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = Color8(160, 220, 255)
		card_style.shadow_color = Color(0, 0, 0, 0.1)
		card_style.shadow_size = 8
		card_style.shadow_offset = Vector2(0, 4)
		_workspace_card.add_theme_stylebox_override("panel", card_style)

	if _preview_panel != null:
		var preview_style := StyleBoxFlat.new()
		preview_style.bg_color = Color8(230, 245, 255)
		preview_style.corner_radius_top_left = 14
		preview_style.corner_radius_top_right = 14
		preview_style.corner_radius_bottom_left = 14
		preview_style.corner_radius_bottom_right = 14
		preview_style.border_width_left = 2
		preview_style.border_width_top = 2
		preview_style.border_width_right = 2
		preview_style.border_width_bottom = 2
		preview_style.border_color = Color8(180, 220, 255)
		_preview_panel.add_theme_stylebox_override("panel", preview_style)

	_style_secondary_button(_go_play_button)
	_style_secondary_button(_go_library_button)


func _style_secondary_button(button: Button) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color8(255, 231, 140)
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color8(224, 188, 68)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color8(255, 239, 173)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color8(245, 214, 113)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color8(45, 35, 12))
	button.add_theme_color_override("font_hover_color", Color8(45, 35, 12))
	button.add_theme_color_override("font_pressed_color", Color8(45, 35, 12))


func _build_template_cards() -> void:
	if _template_list == null:
		return
	var palettes: Dictionary = ThemeManager.get_palettes()
	var templates: Array = palettes.keys()
	var display_names: Dictionary = {}
	for pid in templates:
		var p: Dictionary = palettes[pid]
		display_names[pid] = p.get("name_pl", pid)
	var colors_map: Dictionary = {}
	for pid in templates:
		var p: Dictionary = palettes[pid]
		var cols: Array = p.get("colors", [])
		if not cols.is_empty():
			colors_map[pid] = cols[0]

	for i in range(min(templates.size(), 5)):
		var pid: String = templates[i]
		var btn := Button.new()
		btn.text = display_names.get(pid, pid)
		btn.custom_minimum_size = Vector2(140, 80)
		btn.toggle_mode = true
		btn.button_group = ButtonGroup.new()
		var color_hex: String = colors_map.get(pid, "#5B8DEF")
		var color := _hex_to_color(color_hex)
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.corner_radius_top_left = 14
		sb.corner_radius_top_right = 14
		sb.corner_radius_bottom_left = 14
		sb.corner_radius_bottom_right = 14
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = color.darkened(0.2)
		btn.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate()
		sb_hover.bg_color = color.lightened(0.1)
		btn.add_theme_stylebox_override("hover", sb_hover)
		var sb_pressed := sb.duplicate()
		sb_pressed.bg_color = color.darkened(0.1)
		btn.add_theme_stylebox_override("pressed", sb_pressed)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.pressed.connect(func() -> void:
			_active_palette = pid
			_apply_friendly_theme()
			_set_status_message("Wybrano szablon: %s" % display_names.get(pid, pid), false)
		)
		_template_list.add_child(btn)
		_template_buttons.append(btn)

	if not _template_buttons.is_empty():
		_template_buttons[0].button_pressed = true


func _update_preview_grid() -> void:
	if _preview_grid == null:
		return
	for child in _preview_grid.get_children():
		child.queue_free()
	if _current_world_instance == null:
		var empty := Label.new()
		empty.text = "(pusty)"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_preview_grid.add_child(empty)
		return
	for node_variant in _current_world_instance.scene_nodes:
		if not (node_variant is SceneNode):
			continue
		var node: SceneNode = node_variant
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(24, 24)
		var ds := StyleBoxFlat.new()
		var node_color: Color = node.properties.get("color", Color8(120, 210, 255))
		ds.bg_color = node_color
		ds.corner_radius_top_left = 6
		ds.corner_radius_top_right = 6
		ds.corner_radius_bottom_left = 6
		ds.corner_radius_bottom_right = 6
		dot.add_theme_stylebox_override("panel", ds)
		_preview_grid.add_child(dot)


func _hex_to_color(hex: String) -> Color:
	if hex.begins_with("#"):
		hex = hex.substr(1)
	if hex.length() == 6:
		return Color(
			hex.substr(0, 2).hex_to_int() / 255.0,
			hex.substr(2, 2).hex_to_int() / 255.0,
			hex.substr(4, 2).hex_to_int() / 255.0
		)
	return Color.WHITE


# -- Onboarding Handlers (Phase 7c: event-bus callbacks) --

func _on_onboarding_step_changed_event(event: DomainEvent) -> void:
	if not _onboarding_overlay:
		return
	var step_id: String = event.payload.get("step_id", "")
	var instruction_key: String = event.payload.get("instruction_key", "")

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
			OnboardingServiceScript.STEP_PLACE_FIRST: text = "Kliknij tutaj, aby ustawić obiekt."
			OnboardingServiceScript.STEP_PAINT_FIRST: text = "Teraz pomaluj swój obiekt."
			OnboardingServiceScript.STEP_PLAY: text = "Naciśnij Graj, aby przetestować świat."
			_: text = "Kontynuuj..."

	_onboarding_overlay.show_step(step_id, text, target)


func _on_onboarding_step_completed_event(event: DomainEvent) -> void:
	if _onboarding_overlay:
		_onboarding_overlay.celebrate_completion()


func _on_onboarding_finished_event(event: DomainEvent) -> void:
	if _onboarding_overlay:
		_onboarding_overlay.dismiss()


func _t(key: String) -> String:
	if _localization_policy != null:
		return _localization_policy.translate(key)

	var fallback := {
		"ui.create.title": "Tryb tworzenia",
		"ui.create.info": "Wybierz szablon, zbuduj świat i uruchom test.",
		"ui.tool.place": "Umieść",
		"ui.tool.paint": "Pomaluj",
		"ui.tool.move": "Przesuń",
		"ui.tool.duplicate": "Duplikuj",
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
			_set_status_message("Zmiana AI została zatwierdzona i zastosowana.", false)
			if not _selected_node_id.is_empty():
				set_selected_node(_selected_node_id)
