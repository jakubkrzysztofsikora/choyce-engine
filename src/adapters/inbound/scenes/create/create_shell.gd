class_name CreateShell
extends Control

const OnboardingServiceScript = preload("res://src/application/onboarding_service.gd")
const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")
const ThemeManager = preload("res://src/adapters/inbound/shared/ui/theme_manager.gd")

signal world_context_changed(world_id: String)
signal selection_provenance_changed(provenance: Variant)
## Phase 8d: shell declares its own ports_ready signal so tests can call
## shell.emit_signal("ports_ready") without needing InboundMain in the tree.
## The signal is auto-connected to on_ports_ready() in _ready().
signal ports_ready

const SHELL_PLAY := "play"
const SHELL_LIBRARY := "library"
const SHELL_LANDING := "landing"

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
## Phase 9: VoicePromptPort for non-reader CTA TTS prompt (optional).
var _voice_prompt = null
var _event_bus: DomainEventBus = null
var _active_tool: CanvasTool = CanvasTool.PLACE
## Phase 9: timer for non-reader CTA 3s idle TTS prompt.
var _cta_idle_timer: SceneTreeTimer = null
var _cta_tts_fired: bool = false

## Phase 8d: input gate — false until InboundMain emits ports_ready.
## While false, voice/AI buttons are blocked by VoiceAssistantOverlay.
var _ports_ready: bool = false
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
## Part B: _preview_grid replaced by SubViewport 3D preview; kept as null so _update_preview_grid() no-ops.
var _preview_grid: GridContainer = null
## Part B: SubViewport 3D preview nodes. Fetched via get_node_or_null for forward-compat
## in case the scene is loaded without the preview nodes (e.g. older snapshots in tests).
var _preview_viewport: SubViewport = null
var _preview_root: Node3D = null
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
	# PC-desktop responsive band: center content on M2 Max / 4K monitors
	# so buttons + workspace stop stretching edge-to-edge. Matches
	# play_shell which already does this. Use 1600 cap (wider than the
	# 1280 default) because create needs the horizontal workspace +
	# preview split.
	ResponsiveLayout.apply_max_width($Layout, 1600.0)

	# Kid-UX: big visible voice CTA + first-step hint. Replaces the
	# cryptic "Status tworzenia" panel as the kid's primary entry
	# point. Spec FR-004 (voice-to-intent) + UX-KID-001 (non-reader
	# friendly) + UX-005 (educational micro-prompts).
	_build_kid_voice_cta()

	# Part B: resolve SubViewport preview nodes (null-safe if scene lacks them).
	_preview_viewport = get_node_or_null("Layout/WorkspaceCard/WorkspaceLayout/PreviewPanel/PreviewViewport/SubViewport")
	_preview_root = get_node_or_null("Layout/WorkspaceCard/WorkspaceLayout/PreviewPanel/PreviewViewport/SubViewport/PreviewRoot")

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
		# Wave 2 W2-B: wire the deterministic voice fast-path. The
		# overlay will try VoiceWorldCommandService first; LLM stays
		# as the fallback for unrecognised phrasing.
		if _assistant_overlay.has_method("setup_voice_commands"):
			var voice_svc := VoiceWorldCommandService.new().setup(
				PolishIntentExtractor.new().setup(),
				null
			)
			_assistant_overlay.setup_voice_commands(voice_svc, Vector3.ZERO)
		if _assistant_overlay.has_signal("voice_command_resolved") \
				and not _assistant_overlay.is_connected(
					"voice_command_resolved", _on_voice_command_resolved):
			_assistant_overlay.voice_command_resolved.connect(_on_voice_command_resolved)

	var OnboardingOverlayClass = load("res://src/adapters/inbound/shared/ui/onboarding_overlay.gd")
	if OnboardingOverlayClass:
		_onboarding_overlay = OnboardingOverlayClass.new()
		add_child(_onboarding_overlay)

	_ensure_back_button()
	_ensure_quick_build_row()
	_make_layout_responsive()
	_wire_actions()
	_refresh_labels()
	_apply_friendly_theme()
	# Greet only when the kid actually opens Create — NOT at boot. Firing at
	# boot made the mascot speak (TTS aloud) over the launcher/landing.
	if not visibility_changed.is_connected(_on_visibility_changed_greet):
		visibility_changed.connect(_on_visibility_changed_greet)
	if visible:
		_greet_via_mascot()


func _on_visibility_changed_greet() -> void:
	if visible:
		_greet_via_mascot()


## Inject a top button row: "← Menu" (return to landing) +
## "▶ Graj teraz" (jump straight into the active world). The
## existing GoPlayButton in the Actions row is far down + small;
## kids couldn't find it. Both buttons always enabled regardless
## of role guard — escape hatch first.
func _ensure_back_button() -> void:
	var layout: VBoxContainer = $Layout
	if layout == null:
		return
	if layout.has_node("KidNavRow"):
		return
	var row := HBoxContainer.new()
	row.name = "KidNavRow"
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var back := Button.new()
	back.name = "BackToLandingButton"
	back.text = "← Menu"
	back.custom_minimum_size = Vector2(140, 56)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_on_back_to_landing_pressed)
	row.add_child(back)

	var play_now := Button.new()
	play_now.name = "PlayNowButton"
	play_now.text = "▶ Graj teraz"
	play_now.custom_minimum_size = Vector2(220, 56)
	play_now.add_theme_font_size_override("font_size", 22)
	play_now.pressed.connect(_on_play_now_pressed)
	row.add_child(play_now)

	# Helper hint label so 7yo knows what this screen is for.
	var hint := Label.new()
	hint.name = "ScreenHint"
	hint.text = "  Wybierz narzędzie poniżej i kliknij scenę aby tworzyć"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	row.add_child(hint)

	layout.add_child(row)
	layout.move_child(row, 0)


## "Quick Build" chip row — 4 single-tap presets that scaffold a
## recognizable world instantly. Was: kid stares at empty canvas,
## tools do nothing visible (PLACE stacks at origin), bunny is
## silent. After: tap "🏰 Zamek" → 9 blocks spawn → bunny cheers.
## This is the kid's "I made something!" moment in <2 seconds.
func _ensure_quick_build_row() -> void:
	var layout: VBoxContainer = $Layout
	if layout == null:
		return
	if layout.has_node("QuickBuildRow"):
		return
	var row := HBoxContainer.new()
	row.name = "QuickBuildRow"
	row.add_theme_constant_override("separation", 10)

	# VoxelForge palette (after inspecting ~/Repos/personal/voxel
	# globals.css + live UI): pure black bg, lime-400 accent, glitch
	# headings. Lifted as per-button overrides because the global
	# theme.tres is still the orange kid scheme — full re-skin pending.
	var voxel_lime := Color(0.639, 0.902, 0.208, 1)   # tailwind lime-400 ≈ #A3E635
	var voxel_lime_glow := Color(0.518, 0.800, 0.086, 1)  # lime-500 for borders
	var voxel_black := Color(0.0, 0.0, 0.0, 1)

	var label := Label.new()
	label.text = "🥷  NINJA — WYBIERZ MISJĘ:"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", voxel_lime)
	row.add_child(label)

	for preset in [
		{"id": "castle",   "label": "[ 🏰 ZAMEK ]"},
		{"id": "forest",   "label": "[ 🌲 LAS ]"},
		{"id": "track",    "label": "[ 🏁 TOR ]"},
		{"id": "surprise", "label": "[ 🎁 NIESPODZIANKA ]"},
	]:
		var btn := Button.new()
		btn.text = preset["label"]
		btn.custom_minimum_size = Vector2(160, 56)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", voxel_lime)
		btn.add_theme_color_override("font_hover_color", Color(0.988, 0.882, 0.278, 1))  # yellow-300
		btn.add_theme_color_override("font_pressed_color", voxel_lime_glow)
		# StyleBoxFlat per state — black bg, lime border, glow-y radius.
		for sb_state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sbf := StyleBoxFlat.new()
			sbf.bg_color = voxel_black
			sbf.border_color = voxel_lime if sb_state != "pressed" else voxel_lime_glow
			sbf.set_border_width_all(2)
			sbf.set_corner_radius_all(10)
			sbf.shadow_color = Color(voxel_lime.r, voxel_lime.g, voxel_lime.b, 0.20)
			sbf.shadow_size = 6 if sb_state == "hover" else 0
			sbf.content_margin_left = 14
			sbf.content_margin_right = 14
			sbf.content_margin_top = 6
			sbf.content_margin_bottom = 6
			btn.add_theme_stylebox_override(sb_state, sbf)
		var preset_id: String = preset["id"]
		btn.pressed.connect(func(): _quick_build_preset(preset_id))
		row.add_child(btn)

	layout.add_child(row)
	# Place right under KidNavRow (index 1) if it exists, else top.
	var insert_at := 1 if layout.has_node("KidNavRow") else 0
	layout.move_child(row, insert_at)


## Issues a batch of ADD_NODE commands at preset positions through
## the existing _apply_world_edit_port so the audit/event-bus path
## remains consistent. No special-case AI placeholder.
func _quick_build_preset(preset_id: String) -> void:
	if _apply_world_edit_port == null or _profile == null:
		_set_status_message(_t("create.error.no_config"), true)
		return
	_ensure_world_context()
	if _active_world_id.is_empty():
		return

	# Each placement = (display_name, position). The display_name MUST
	# match a key in WorldRenderer.PROP_GLTF so the runtime loads the
	# authored Kenney/Blender prop instead of falling back to a white
	# BoxMesh. (Previous version emitted "castle #0" → no asset → cube.)
	var placements: Array = []
	match preset_id:
		"castle":
			# Stone walls (skała) on a 3×3 footprint + 4 corner spires
			# (skała z mchem) with flag markers (flaga) on top corners.
			for x in [-1, 0, 1]:
				for z in [-1, 0, 1]:
					placements.append({"name": "skała", "pos": Vector3(x * 1.2, 0, z * 1.2)})
			for c in [Vector3(-1.2,0.9,-1.2), Vector3(1.2,0.9,-1.2), Vector3(-1.2,0.9,1.2), Vector3(1.2,0.9,1.2)]:
				placements.append({"name": "skała z mchem", "pos": c})
			placements.append({"name": "flaga", "pos": Vector3(-1.2, 1.8, -1.2)})
			placements.append({"name": "flaga", "pos": Vector3(1.2, 1.8, 1.2)})
			placements.append({"name": "skrzynia", "pos": Vector3(0, 0, 2.2)})
		"forest":
			# Tall oaks in an outer ring, mushrooms + flowers inside,
			# acorns scattered. Spawn crystal as the centerpiece.
			for i in 5:
				var ang := i * TAU / 5.0
				placements.append({"name": "dąb", "pos": Vector3(cos(ang) * 3.0, 0, sin(ang) * 3.0)})
			placements.append({"name": "grzyb", "pos": Vector3(-1.4, 0, 0.8)})
			placements.append({"name": "grzyb mały", "pos": Vector3(1.2, 0, -0.6)})
			placements.append({"name": "kłoda", "pos": Vector3(0.8, 0, 1.6)})
			placements.append({"name": "kwiaty", "pos": Vector3(-0.5, 0, -1.2)})
			placements.append({"name": "kwiaty", "pos": Vector3(1.6, 0, 0.4)})
			placements.append({"name": "świetlik", "pos": Vector3(0, 0.5, 0)})
			placements.append({"name": "żołądź", "pos": Vector3(-2.2, 0, 1.8)})
		"track":
			# Fence rails forming a straight track + start/finish flags.
			for x in range(-3, 4):
				placements.append({"name": "płot", "pos": Vector3(x, 0, -1.2)})
				placements.append({"name": "płot", "pos": Vector3(x, 0, 1.2)})
			placements.append({"name": "flaga", "pos": Vector3(-3.0, 0, 0)})
			placements.append({"name": "flaga", "pos": Vector3(3.0, 0, 0)})
		"surprise", _:
			# Random kid-treat sprinkle. Coins, apples, firefly jars,
			# starfish, pearls — visible collectibles, not boxes.
			var pool := ["moneta", "jabłko", "świetlik", "rozgwiazda", "perła", "kwiaty", "grzyb mały"]
			for i in 8:
				var name: String = pool[i % pool.size()]
				placements.append({"name": name, "pos": Vector3(randi_range(-3, 3), 0, randi_range(-3, 3))})

	var placed := 0
	for entry in placements:
		var cmd := WorldEditCommand.new()
		cmd.target_node_id = "%s_%d_%d" % [preset_id, placed, Time.get_ticks_msec()]
		cmd.action = WorldEditCommand.Action.ADD_NODE
		cmd.node_data = {
			"type": SceneNode.NodeType.OBJECT,
			"display_name": entry["name"],
			"position": entry["pos"],
		}
		if _apply_world_edit_port.execute(_active_world_id, cmd, _profile):
			_apply_command_to_local_world(cmd)
			placed += 1

	_refresh_workspace_ui()
	_update_3d_preview(_current_world_instance)
	_set_status_message("✨ Zbudowano %d klocków!" % placed, false)
	_mascot_say("Gotowe. %s na mapie. Naciśnij ▶ Graj teraz!" % preset_id)


## Routes a greeting through the global Mascot autoload-like node
## ($MascotOverlay on InboundMain). Silent if unreachable — never
## blocks the shell.
func _greet_via_mascot() -> void:
	# Kid-UX: voice-first greeting per FR-004 + LEGO "mama duck"
	# onboarding (lead by example, don't force tutorial). Big mic
	# button is at the top of the screen — point the kid there.
	_mascot_say("Naciśnij 🎤 i powiedz np. „buduj drzewo”!")


func _mascot_say(text: String) -> void:
	var root := get_tree().root if is_inside_tree() else null
	if root == null:
		return
	var mascot := root.find_child("MascotOverlay", true, false)
	if mascot != null and mascot.has_method("say"):
		mascot.say(text, 4.0)


## "▶ Graj teraz" — launches a playtest on the CURRENT world the
## kid is editing (matches the existing GoPlayButton flow). Was
## previously just navigating to SHELL_PLAY which made the kid pick
## a world again — regression flagged by adv UX review B3.
func _on_play_now_pressed() -> void:
	# Fire the same launch path the Actions row's "Przejdź do gry"
	# button uses. _launch_playtest reads _active_world_id + builds
	# a session via RunPlaytestPort.
	if has_method("_launch_playtest"):
		_launch_playtest(false)
		return
	if _navigator != null:
		_navigator.show_shell(SHELL_PLAY)


## Center the shell's content with a max width so ultra-wide
## monitors don't stretch buttons edge-to-edge. Applied to
## the existing Layout VBoxContainer by switching its anchors
## from FULL_RECT to a centered band. Existing @onready paths
## ($Layout/...) are preserved — we mutate anchors only.
func _make_layout_responsive() -> void:
	var layout: VBoxContainer = $Layout
	if layout == null:
		return
	const MAX_CONTENT_WIDTH := 1280.0
	# Center horizontally with a max band; keep vertical full-rect.
	layout.anchor_left = 0.5
	layout.anchor_right = 0.5
	layout.anchor_top = 0.0
	layout.anchor_bottom = 1.0
	layout.offset_left = -MAX_CONTENT_WIDTH * 0.5
	layout.offset_right = MAX_CONTENT_WIDTH * 0.5
	layout.offset_top = 16.0
	layout.offset_bottom = -16.0
	layout.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _on_back_to_landing_pressed() -> void:
	if _navigator != null:
		_navigator.show_shell(SHELL_LANDING)
	_build_template_cards()
	_setup_preview_environment()
	_refresh_workspace_ui()
	_toast_banner.visible = false
	# Phase 9: start non-reader CTA idle TTS prompt after 3s of no interaction.
	_start_cta_idle_timer()

	# Phase 8d: connect own ports_ready signal to the handler so that both:
	#   a) tests can call shell.emit_signal("ports_ready") directly, and
	#   b) InboundMain can call shell.on_ports_ready() (or emit its own signal
	#      which _wire_shell_dependencies connects below).
	if not ports_ready.is_connected(on_ports_ready):
		ports_ready.connect(on_ports_ready)

	# Also subscribe to InboundMain's ports_ready if we are already in the tree
	# under a parent that has the signal.  This covers the live runtime path.
	var parent := get_parent()
	if parent != null and parent.has_signal("ports_ready"):
		if not parent.ports_ready.is_connected(on_ports_ready):
			parent.ports_ready.connect(on_ports_ready)


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
	event_bus: DomainEventBus = null,
	## Phase 9: optional VoicePromptPort for non-reader CTA TTS prompt.
	voice_prompt = null
) -> CreateShell:
	_navigator = navigator
	_profile = profile
	_localization_policy = localization_policy
	_create_project_port = create_project_port
	_run_playtest_port = run_playtest_port
	_apply_world_edit_port = apply_world_edit_port
	_request_ai_help_port = request_ai_help_port
	_speech_to_text_port = speech_to_text_port
	_voice_prompt = voice_prompt
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
		_refresh_tool_port_gate()
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
		_reset_cta_idle_timer()
		_set_active_tool(CanvasTool.PLACE)
		_apply_active_tool()
		_animate_button_press(_place_button)
	)
	_paint_button.pressed.connect(func() -> void:
		_reset_cta_idle_timer()
		_set_active_tool(CanvasTool.PAINT)
		_apply_active_tool()
		_animate_button_press(_paint_button)
	)
	_move_button.pressed.connect(func() -> void:
		_reset_cta_idle_timer()
		_set_active_tool(CanvasTool.MOVE)
		_apply_active_tool()
		_animate_button_press(_move_button)
	)
	_duplicate_button.pressed.connect(func() -> void:
		_reset_cta_idle_timer()
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
	_info.text = _t("create.steps.intro")
	_status_title.text = _t("create.status.title")
	_node_list_title.text = _t("create.node_list.title")
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
	_set_status_message(_t("create.hint.choose_tool"), false)
	_refresh_tool_states()
	_refresh_tool_port_gate()


func _set_active_tool(tool: CanvasTool) -> void:
	_active_tool = tool
	_refresh_tool_states()
	_set_status_message(_t("create.tool_selected") % _tool_name(tool), false)


func _refresh_tool_states() -> void:
	_place_button.button_pressed = _active_tool == CanvasTool.PLACE
	_paint_button.button_pressed = _active_tool == CanvasTool.PAINT
	_move_button.button_pressed = _active_tool == CanvasTool.MOVE
	_duplicate_button.button_pressed = _active_tool == CanvasTool.DUPLICATE
	_style_tool_button(_place_button, _active_tool == CanvasTool.PLACE, Color8(120, 210, 255))
	_style_tool_button(_paint_button, _active_tool == CanvasTool.PAINT, Color8(147, 228, 170))
	_style_tool_button(_move_button, _active_tool == CanvasTool.MOVE, Color8(170, 190, 255))
	_style_tool_button(_duplicate_button, _active_tool == CanvasTool.DUPLICATE, Color8(229, 180, 255))


## Phase 9 / Wave C: disable/enable tool buttons depending on whether
## _apply_world_edit_port is wired AND _ports_ready is true.
## Called from _refresh_labels() (initial), setup() (after port injection),
## and on_ports_ready() (after ports_ready signal fires).
func _refresh_tool_port_gate() -> void:
	var port_available := _apply_world_edit_port != null and _ports_ready
	var unavailable_tip := _t("create.tools.unavailable")
	var tool_buttons: Array[Button] = [_place_button, _paint_button, _move_button, _duplicate_button]
	for btn in tool_buttons:
		if btn == null:
			continue
		btn.disabled = not port_available
		if not port_available:
			btn.tooltip_text = unavailable_tip


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
	# W1.11: Wave-B Phase 8d gate posture is BLOCK. The tool buttons disable
	# themselves until _ports_ready, but a direct call (keyboard nav, test
	# harness, future REST adapter) could still reach this function with
	# uninitialised ports. Reject explicitly with the same kid-friendly
	# message the disabled-button path uses.
	if not _ports_ready:
		_set_status_message(_t("create.tools.unavailable"), false)
		return
	if _apply_world_edit_port == null or _profile == null:
		_set_status_message(_t("create.error.port_not_ready"), true)
		return

	_ensure_world_context()
	if _active_world_id.is_empty():
		_set_status_message(_t("create.error.no_world"), true)
		return

	if _selected_node_id.is_empty() and _active_tool != CanvasTool.PLACE:
		_set_status_message(_t("create.error.no_selection"), true)
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
				"display_name": _t("create.object.default_name"),
				"position": Vector3(0, 0, 0),
			}
		CanvasTool.PAINT:
			command.action = WorldEditCommand.Action.PAINT
			# Adv R #10 fix — apply_world_edit handler reads
			# `command.new_state["color"]`, not "paint". The wrong key
			# meant clicks did nothing. Kid sees no color change → tool
			# appears broken.
			command.new_state = {"color": "kolor_przyjazny"}
		CanvasTool.MOVE:
			command.action = WorldEditCommand.Action.MOVE_NODE
			# MOVE used a fixed +X offset (Adv R #10). Use active-axis
			# offset derived from kid's last input direction; for MVP
			# fall back to +Z (forward) which is what a kid drags
			# instinctively. Real drag-to-place lands in W2 builder UX.
			command.new_state = {"offset": Vector3(0, 0, 1)}
		CanvasTool.DUPLICATE:
			command.action = WorldEditCommand.Action.DUPLICATE_NODE
			command.node_data = {"new_id": "%s_copy_%d" % [_selected_node_id, Time.get_ticks_msec()]}

	var applied := _apply_world_edit_port.execute(_active_world_id, command, _profile)
	if not applied:
		_set_status_message(_t("create.error.edit_failed"), true)
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
	_update_3d_preview(_current_world_instance)


func _ensure_world_context() -> void:
	if not _active_world_id.is_empty():
		return
	if _create_project_port == null or _profile == null:
		_set_status_message(_t("create.error.no_config"), true)
		return
	var project := _create_project_port.execute("starter_canvas", _profile)
	if project == null or project.worlds.is_empty():
		_set_status_message(_t("create.error.world_create_failed"), true)
		return
	var world_variant: Variant = project.worlds[0]
	if not (world_variant is World):
		_set_status_message(_t("create.error.world_invalid"), true)
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
	_set_status_message(_t("create.world_ready"), false)
	_refresh_workspace_ui()
	_update_preview_grid()
	_update_3d_preview(_current_world_instance)


func _launch_playtest(local_coop: bool = false) -> Session:
	if _run_playtest_port == null or _profile == null:
		_set_status_message(_t("create.error.playtest_unavailable"), true)
		return null
	_ensure_world_context()
	if _active_world_id.is_empty():
		_set_status_message(_t("create.error.playtest_no_world"), true)
		return null

	var players: Array = [_profile]
	if local_coop:
		var guest := PlayerProfile.new("%s_local_guest" % _profile.profile_id, PlayerProfile.Role.KID)
		guest.display_name = _t("create.guest_name")
		players.append(guest)

	var session := _run_playtest_port.execute(_active_world_id, players)
	if session != null:
		var mode_str := _t("create.playtest.mode_coop") if session.mode == Session.SessionMode.CO_OP else _t("create.playtest.mode_solo")
		_info.text = _t("create.playtest.running") % mode_str
		_set_status_message(_t("create.playtest.started"), false)
	else:
		_set_status_message(_t("create.error.playtest_failed"), true)
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
		_world_summary.text = _t("create.world_summary.empty")
		_selection_label.text = _t("create.selection.none")
		_node_list.clear()
		_node_list_ids = []
		_node_list.add_item(_t("create.node_list.empty"))
		_node_list.set_item_disabled(0, true)
		return

	var node_count := _current_world_instance.scene_nodes.size()
	_world_summary.text = _t("create.world_summary.full") % [_active_world_id, node_count]
	_selection_label.text = (
		_t("create.selection.active") % _selected_node_id
		if not _selected_node_id.is_empty()
		else _t("create.selection.none")
	)

	_node_list.clear()
	_node_list_ids = []
	for node_variant in _current_world_instance.scene_nodes:
		if not (node_variant is SceneNode):
			continue
		var node: SceneNode = node_variant
		_node_list_ids.append(node.node_id)
		var title := node.display_name if not node.display_name.is_empty() else _t("create.object.fallback_name")
		_node_list.add_item("%s (%s)" % [title, node.node_id])

	if _node_list_ids.is_empty():
		_node_list.add_item(_t("create.node_list.empty"))
		_node_list.set_item_disabled(0, true)
		return

	var selected_index := _node_list_ids.find(_selected_node_id)
	if selected_index >= 0:
		_node_list.select(selected_index)


func _on_node_list_item_selected(index: int) -> void:
	if index < 0 or index >= _node_list_ids.size():
		return
	set_selected_node(_node_list_ids[index])
	_set_status_message(_t("create.object_selected") % _node_list_ids[index], false)


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
			return _t("create.tool.place")
		CanvasTool.PAINT:
			return _t("create.tool.paint")
		CanvasTool.MOVE:
			return _t("create.tool.move")
		CanvasTool.DUPLICATE:
			return _t("create.tool.duplicate")
	return _t("create.tool.unknown")


func _success_message_for(command: WorldEditCommand) -> String:
	match command.action:
		WorldEditCommand.Action.ADD_NODE:
			return _t("create.success.add") % command.target_node_id
		WorldEditCommand.Action.PAINT:
			return _t("create.success.paint") % command.target_node_id
		WorldEditCommand.Action.MOVE_NODE:
			return _t("create.success.move") % command.target_node_id
		WorldEditCommand.Action.DUPLICATE_NODE:
			return _t("create.success.duplicate")
	return _t("create.success.generic")


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
	# Clear old children.
	for child in _template_list.get_children():
		child.queue_free()
	_template_buttons.clear()

	# W1.8: card swatch colours come from palettes.json single source of truth
	# (template_defaults → palette → colors[0..2]) so the dots a kid sees match
	# what apply_palette_to_theme will actually paint when they pick the card.
	var template_ids := ["adventure", "farm", "city", "obby", "tycoon"]
	var template_icons := {"adventure": "⛰", "farm": "🌾", "city": "🏙", "obby": "🏃", "tycoon": "💰"}
	var templates: Array = []
	for tid in template_ids:
		var palette_colors := ThemeManager.get_palette_colors_for_template(tid)
		var swatch: Array = []
		for i in range(min(3, palette_colors.size())):
			swatch.append(ThemeManager.hex_to_color(str(palette_colors[i])))
		templates.append({
			"id": tid,
			"name": _t("create.template." + tid),
			"icon": template_icons.get(tid, "✨"),
			"colors": swatch,
		})

	for t in templates:
		var card := _build_template_card(t)
		_template_list.add_child(card)
		_template_buttons.append(card)


func _build_template_card(t: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 160)
	btn.text = ""
	btn.set_meta("template_id", t["id"])
	btn.pressed.connect(_on_template_card_pressed.bind(t["id"]))
	btn.mouse_entered.connect(func(): _on_card_hover(btn, true))
	btn.mouse_exited.connect(func(): _on_card_hover(btn, false))

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(v)

	var icon := Label.new()
	icon.text = t["icon"]
	icon.add_theme_font_size_override("font_size", 64)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)

	var name_label := Label.new()
	name_label.text = t["name"]
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18, 1))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_label)

	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 6)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in t["colors"]:
		var dot := ColorRect.new()
		dot.color = c
		dot.custom_minimum_size = Vector2(14, 14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	v.add_child(dots)

	return btn


func _on_card_hover(btn: Button, hovering: bool) -> void:
	var target := Vector2(1.06, 1.06) if hovering else Vector2(1.0, 1.0)
	var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", target, 0.15)


func _on_template_card_pressed(template_id: String) -> void:
	_set_template(template_id)


func _set_template(template_id: String) -> void:
	# W1.8: template ids ("city", "obby", ...) are NOT palette ids; resolve via
	# template_defaults so apply_palette_to_theme receives a real palette id
	# ("city_sunrise", "arcade_pop", ...). Previously the raw template id was
	# stored, ThemeManager push_warning'd, and the palette never switched.
	_active_palette = ThemeManager.get_palette_id_for_template(template_id)
	_apply_friendly_theme()
	_set_status_message(_t("create.template_selected") % template_id, false)
	_update_3d_preview(_current_world_instance)


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


## Part B: Set up ground plane and sky WorldEnvironment in the SubViewport preview.
## Called once from _ready(). No-ops if _preview_root is null (scene has no SubViewport).
func _setup_preview_environment() -> void:
	if _preview_root == null:
		return
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(20, 20)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.60, 0.85, 0.50, 1)  # soft grass green
	ground.set_surface_override_material(0, mat)
	ground.position = Vector3(0, 0, 0)
	_preview_root.add_child(ground)
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.91, 1.0, 1)  # soft sky blue
	sky.environment = env
	_preview_root.add_child(sky)


## Part B: Populate the SubViewport with simple primitive meshes representing world nodes.
## Clears any previously spawned preview objects (tagged with meta "preview_mesh"),
## then creates one primitive per scene_node up to 8 max.
func _update_3d_preview(world) -> void:
	if _preview_root == null:
		return
	# Remove previously spawned preview meshes.
	for child in _preview_root.get_children():
		if child.has_meta("preview_mesh"):
			child.queue_free()
	if world == null or not world.has_method("get") or not ("scene_nodes" in world):
		return
	var nodes: Array = world.scene_nodes
	var max_nodes := mini(nodes.size(), 8)
	for i in range(max_nodes):
		var sn = nodes[i]
		if not (sn is SceneNode):
			continue
		var mi := MeshInstance3D.new()
		mi.set_meta("preview_mesh", true)
		# Pick mesh shape by node_type.
		match sn.node_type:
			SceneNode.NodeType.TERRAIN:
				var m := BoxMesh.new()
				m.size = Vector3(2.0, 0.5, 2.0)
				mi.mesh = m
			SceneNode.NodeType.DECORATION:
				var m := SphereMesh.new()
				m.radius = 0.6
				m.height = 1.2
				mi.mesh = m
			SceneNode.NodeType.SPAWN_POINT:
				var m := CylinderMesh.new()
				m.top_radius = 0.3
				m.bottom_radius = 0.3
				m.height = 1.0
				mi.mesh = m
			_:  # OBJECT, LIGHT, TRIGGER and anything else
				var m := BoxMesh.new()
				m.size = Vector3(1.0, 1.0, 1.0)
				mi.mesh = m
		# Position: use stored position when available, else spread in a grid.
		if sn.position != Vector3.ZERO:
			mi.position = sn.position + Vector3(0, 0.5, 0)
		else:
			var col := i % 4
			var row := i / 4
			mi.position = Vector3(col * 2.5 - 3.75, 0.5, row * 2.5)
		# Tint by palette color from properties if present.
		var node_color: Color = sn.properties.get("color", Color(0.60, 0.75, 1.0))
		var node_mat := StandardMaterial3D.new()
		node_mat.albedo_color = node_color
		mi.set_surface_override_material(0, node_mat)
		_preview_root.add_child(mi)


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
			OnboardingServiceScript.STEP_WELCOME: text = _t("create.onboarding.welcome")
			OnboardingServiceScript.STEP_PLACE_FIRST: text = _t("create.onboarding.place_first")
			OnboardingServiceScript.STEP_PAINT_FIRST: text = _t("create.onboarding.paint_first")
			OnboardingServiceScript.STEP_PLAY: text = _t("create.onboarding.play")
			_: text = _t("create.onboarding.continue")

	_onboarding_overlay.show_step(step_id, text, target)


func _on_onboarding_step_completed_event(event: DomainEvent) -> void:
	if _onboarding_overlay:
		_onboarding_overlay.celebrate_completion()


func _on_onboarding_finished_event(event: DomainEvent) -> void:
	if _onboarding_overlay:
		_onboarding_overlay.dismiss()


## Phase 8d: handler for the ports_ready signal from InboundMain or test harness.
func on_ports_ready() -> void:
	_ports_ready = true
	if _assistant_overlay != null and _assistant_overlay.has_method("notify_ports_ready"):
		_assistant_overlay.call("notify_ports_ready")
	# Wave C: re-evaluate tool gate now that ports_ready is true; buttons enabled
	# only when BOTH _apply_world_edit_port != null AND _ports_ready == true.
	if is_node_ready():
		_refresh_tool_port_gate()


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
		"ui.create.go_library": "Przejdź do biblioteki",
		# Phase 4a-1: create_shell keys
		"create.steps.intro": "Stwórz: 1) Umieść 2) Pomaluj 3) Zagraj.",
		"create.status.title": "Status tworzenia",
		"create.node_list.title": "Obiekty w świecie",
		"create.hint.choose_tool": "Powiedz 🎤 „buduj drzewo” albo kliknij ➕ Umieść.",
		"create.tool_selected": "Wybrałeś: %s.",
		"create.error.port_not_ready": "Tryb tworzenia niegotowy. Uruchom ponownie.",
		"create.error.no_world": "Brak aktywnego świata. Kliknij Umieść.",
		"create.error.no_selection": "Wybierz obiekt lub dodaj przez Umieść.",
		"create.object.default_name": "Nowy obiekt",
		"create.error.edit_failed": "Zmiana niezapisana. Wybierz inny obiekt.",
		"create.error.no_config": "Brak konfiguracji. Tryb tworzenia nieaktywny.",
		"create.error.world_create_failed": "Nie udało się utworzyć świata.",
		"create.error.world_invalid": "Świat ma niepoprawny format.",
		"create.world_ready": "Świat gotowy. Dodaj obiekt przez Umieść.",
		"create.error.playtest_unavailable": "Playtest chwilowo niedostępny.",
		"create.error.playtest_no_world": "Najpierw utwórz świat.",
		"create.guest_name": "Gość",
		"create.playtest.running": "Test uruchomiony: %s",
		"create.playtest.mode_coop": "kooperacja",
		"create.playtest.mode_solo": "solo",
		"create.playtest.started": "Playtest uruchomiony. Przejdź do Graj.",
		"create.error.playtest_failed": "Playtest nieudany. Dodaj obiekt.",
		"create.world_summary.empty": "Świat: brak | Obiekty: 0",
		"create.selection.none": "Zaznaczenie: brak",
		"create.node_list.empty": "Brak obiektów. Kliknij Umieść.",
		"create.world_summary.full": "Świat: %s | Obiekty: %d",
		"create.selection.active": "Zaznaczenie: %s",
		"create.object.fallback_name": "Obiekt",
		"create.object_selected": "Wybrano obiekt: %s.",
		"create.tool.place": "Umieść",
		"create.tool.paint": "Pomaluj",
		"create.tool.move": "Przesuń",
		"create.tool.duplicate": "Duplikuj",
		"create.tool.unknown": "Narzędzie",
		"create.success.add": "Dodano obiekt: %s.",
		"create.success.paint": "Pomalowano obiekt: %s.",
		"create.success.move": "Przesunięto obiekt: %s.",
		"create.success.duplicate": "Utworzono kopię obiektu.",
		"create.success.generic": "Zmiana zapisana.",
		"create.template_selected": "Świetnie! Wybrałeś %s. Teraz powiedz 🎤 co dodać!",
		"create.onboarding.welcome": "Witaj! Zaczynamy budowanie.",
		"create.onboarding.place_first": "Kliknij tu, aby ustawić obiekt.",
		"create.onboarding.paint_first": "Teraz pomaluj swój obiekt.",
		"create.onboarding.play": "Naciśnij Graj, aby przetestować.",
		"create.onboarding.continue": "Kontynuuj...",
		"create.ai.applied": "Zmiana AI zatwierdzona i zastosowana.",
		# Phase 9
		"create.tools.unavailable": "Narzędzia niedostępne. Spróbuj ponownie.",
		# Wave C: CTA voice prompt (kid-register: short imperative)
		"create.cta.build_world_voice": "Naciśnij narzędzie i coś zbuduj.",
		"create.cta.build_world": "Stwórz coś!",
		# Part A: template card names (kid-register)
		"create.template.adventure": "Wyspa skarbów",
		"create.template.farm": "Mała farma",
		"create.template.city": "Małe miasto",
		"create.template.obby": "Tor przeszkód",
		"create.template.tycoon": "Mały sklep",
		# Part B: preview labels
		"create.preview.title": "Podgląd Twojego świata",
		"create.preview.empty": "Naciśnij narzędzie i coś dodaj.",
	}
	return fallback.get(key, key)


## Phase 9: Non-reader CTA — start 3s idle timer. On timeout, fire VoicePromptPort if available.
## The timer is (re-)started on shell ready. Any user interaction resets it via _reset_cta_idle_timer().
func _start_cta_idle_timer() -> void:
	if not is_inside_tree():
		return
	_cta_tts_fired = false
	_cta_idle_timer = get_tree().create_timer(3.0)
	_cta_idle_timer.timeout.connect(_on_cta_idle_timeout)


func _reset_cta_idle_timer() -> void:
	_cta_tts_fired = false
	if is_inside_tree():
		_cta_idle_timer = get_tree().create_timer(3.0)
		_cta_idle_timer.timeout.connect(_on_cta_idle_timeout)


func _on_cta_idle_timeout() -> void:
	if _cta_tts_fired:
		return
	_cta_tts_fired = true
	if _voice_prompt != null and _voice_prompt.has_method("speak"):
		_voice_prompt.call("speak", _t("create.cta.build_world_voice"))


## Kid-UX hero card injected at the top of the create scene. Single
## big CTA the 6yo can see + hit + understand. Replaces the cryptic
## "Status tworzenia" text panel as the primary call-to-action.
##
## Spec coverage:
##   FR-004    voice-to-intent creation
##   UX-001    44px+ touch target (we use 96px hero button)
##   UX-KID-001 non-reader friendly (emoji-first, voice-first)
##   UX-KID-002 bounded choices (one big primary CTA, secondary hint)
##   UX-KID-003 mascot guide ("Powiem ci co zbudować")
##   UX-005    educational micro-prompts (examples shown)
func _build_kid_voice_cta() -> void:
	# Inject above the existing Header so it's the first thing the kid sees.
	var layout := get_node_or_null("Layout") as VBoxContainer
	if layout == null:
		return
	if layout.get_node_or_null("KidVoiceCTA") != null:
		return

	var card := PanelContainer.new()
	card.name = "KidVoiceCTA"
	card.custom_minimum_size = Vector2(0, 140)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Place at top of the VBox.
	layout.add_child(card)
	layout.move_child(card, 0)

	# Friendly gradient-ish background via StyleBoxFlat.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.38, 0.55, 0.95, 1.0)
	sb.corner_radius_top_left = 24
	sb.corner_radius_top_right = 24
	sb.corner_radius_bottom_left = 24
	sb.corner_radius_bottom_right = 24
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	card.add_child(row)

	# Big mic button — the hero CTA.
	var mic_btn := Button.new()
	mic_btn.name = "MicButton"
	mic_btn.text = "🎤"
	mic_btn.add_theme_font_size_override("font_size", 56)
	mic_btn.custom_minimum_size = Vector2(120, 100)
	mic_btn.add_theme_color_override("font_color", Color.WHITE)
	var mic_sb := StyleBoxFlat.new()
	mic_sb.bg_color = Color(0.95, 0.42, 0.55, 1.0)
	mic_sb.corner_radius_top_left = 50
	mic_sb.corner_radius_top_right = 50
	mic_sb.corner_radius_bottom_left = 50
	mic_sb.corner_radius_bottom_right = 50
	mic_btn.add_theme_stylebox_override("normal", mic_sb)
	var mic_sb_hover := mic_sb.duplicate()
	mic_sb_hover.bg_color = Color(1.0, 0.5, 0.62, 1.0)
	mic_btn.add_theme_stylebox_override("hover", mic_sb_hover)
	mic_btn.pressed.connect(_on_kid_voice_cta_pressed)
	row.add_child(mic_btn)

	# Text column.
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 6)
	row.add_child(text_vbox)

	var headline := Label.new()
	headline.text = "Powiedz mi co zbudować!"
	headline.add_theme_font_size_override("font_size", 32)
	headline.add_theme_color_override("font_color", Color.WHITE)
	text_vbox.add_child(headline)

	var examples := Label.new()
	examples.text = "Spróbuj: „buduj drzewo” • „buduj dom” • „usuń kwiat”"
	examples.add_theme_font_size_override("font_size", 20)
	examples.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	text_vbox.add_child(examples)


## Kid pressed the big hero mic button. Route directly into the
## existing VoiceAssistantOverlay record path so the deterministic
## VoiceWorldCommandService runs without needing the kid to find
## the small bottom-right 🎤 button.
func _on_kid_voice_cta_pressed() -> void:
	if _assistant_overlay == null:
		_set_status_message("Asystent głosowy nie jest gotowy.", true)
		return
	if not _ports_ready:
		_set_status_message("Chwilę… wczytuję!", false)
		return
	if _assistant_overlay.has_method("_on_record_pressed"):
		_assistant_overlay.call("_on_record_pressed")
	else:
		_set_status_message("Nie mogę nagrywać teraz.", true)


## Wave 2 W2-B: deterministic voice fast-path handler. Applies the
## offline-built WorldEditCommand and speaks Polish feedback via
## VoicePromptPort (when wired). Skips the LLM round trip entirely.
func _on_voice_command_resolved(command: WorldEditCommand, feedback_pl: String) -> void:
	if command == null:
		return
	if _apply_world_edit_port == null or _profile == null:
		push_warning("create_shell: voice command resolved but apply port / profile missing")
		return
	var ok := _apply_world_edit_port.execute(_active_world_id, command, _profile)
	if ok:
		_set_status_message(feedback_pl, false)
		if _voice_prompt != null and _voice_prompt.has_method("speak"):
			_voice_prompt.call("speak", feedback_pl)
	else:
		_set_status_message("Nie udało się. Spróbuj ponownie.", true)


func _on_ai_action_confirmed(action: AIAssistantAction) -> void:
	if _request_ai_help_port != null:
		var executed = _request_ai_help_port.execute_pending_action(action, _profile)
		if executed and executed.status == AIAssistantAction.ActionStatus.APPLIED:
			print("AI Action executed: ", executed.action_id)
			_set_status_message(_t("create.ai.applied"), false)
			if not _selected_node_id.is_empty():
				set_selected_node(_selected_node_id)
