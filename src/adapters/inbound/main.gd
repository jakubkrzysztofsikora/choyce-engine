class_name InboundMain
extends Control

const SHELL_CREATE := "create"
const SHELL_PLAY := "play"
const SHELL_LIBRARY := "library"
const SHELL_PARENT := "parent"

const KEY_CREATE_PORT := "create_project"
const KEY_PLAYTEST_PORT := "run_playtest"
const KEY_APPLY_WORLD_EDIT_PORT := "apply_world_edit"
const KEY_PUBLISH_PORT := "publish_family_library"
const KEY_REVIEW_PUBLISH_PORT := "review_publish_request"
const KEY_UNPUBLISH_PORT := "unpublish_world"
const KEY_PARENTAL_CONTROLS_PORT := "set_parental_controls"
const KEY_REQUEST_AI_HELP_PORT := "request_ai_help"
const KEY_SPEECH_TO_TEXT_PORT := "speech_to_text"
const KEY_KID_STATUS_READ_MODEL := "kid_status_read_model"
const KEY_PARENT_AUDIT_READ_MODEL := "parent_audit_read_model"
const KEY_AI_PERFORMANCE_READ_MODEL := "ai_performance_read_model"

var _navigator := ShellNavigator.new()
var _ports: Dictionary = {}
var _feature_flags: FeatureFlagService
var _localization_policy: LocalizationPolicyPort
var _accessibility_policy: AccessibilityPolicyPort
var _profile: PlayerProfile

@onready var _nav_create: Button = $Layout/NavBar/NavCreate
@onready var _nav_play: Button = $Layout/NavBar/NavPlay
@onready var _nav_library: Button = $Layout/NavBar/NavLibrary
@onready var _nav_parent: Button = $Layout/NavBar/NavParent
@onready var _title_label: Label = $Layout/NavBar/TitleLabel

@onready var _create_shell: CreateShell = $Layout/Body/CreateShell
@onready var _play_shell: PlayShell = $Layout/Body/PlayShell
@onready var _library_shell: LibraryShell = $Layout/Body/LibraryShell
@onready var _parent_shell: ParentZoneShell = $Layout/Body/ParentZoneShell

# Accessibility UI
var _nav_a11y: Button
var _a11y_dialog: AcceptDialog
var _check_dyslexia: CheckBox
var _check_motor: CheckBox
var _check_captions: CheckBox


func _ready() -> void:
	if _accessibility_policy == null:
		_accessibility_policy = GodotAccessibilityAdapter.new().setup(self)
	_accessibility_policy.apply_baseline_contrast()
	
	if _feature_flags == null:
		# Use default config from environment
		var config = DeploymentConfig.from_environment()
		_feature_flags = FeatureFlagService.new(config)

	_setup_a11y_ui()
	_register_shells()
	_connect_navigation()
	_wire_shell_dependencies()
	_apply_localized_text()
	_navigator.show_shell(SHELL_CREATE)


func setup(profile: PlayerProfile, ports: Dictionary, localization_policy: LocalizationPolicyPort, accessibility_policy: AccessibilityPolicyPort) -> InboundMain:
	_profile = profile
	_ports = ports
	# Feature flags may ideally be passed in setup too, but for back-compat we handle it in _ready or expose separate setter 
	_localization_policy = localization_policy
	_accessibility_policy = accessibility_policy

	if is_node_ready():
		_wire_shell_dependencies()
		_apply_localized_text()

	return self


func _register_shells() -> void:
	_navigator.register_shell(SHELL_CREATE, _create_shell)
	_navigator.register_shell(SHELL_PLAY, _play_shell)
	_navigator.register_shell(SHELL_LIBRARY, _library_shell)
	_navigator.register_shell(SHELL_PARENT, _parent_shell)


func _connect_navigation() -> void:
	_nav_create.pressed.connect(func() -> void: _navigator.show_shell(SHELL_CREATE))
	_nav_play.pressed.connect(func() -> void: _navigator.show_shell(SHELL_PLAY))
	_nav_library.pressed.connect(func() -> void: _navigator.show_shell(SHELL_LIBRARY))
	_nav_parent.pressed.connect(func() -> void: _navigator.show_shell(SHELL_PARENT))


func _wire_shell_dependencies() -> void:
	_create_shell.setup(
		_navigator, 
		_profile, 
		_localization_policy, 
		_ports.get(KEY_CREATE_PORT, null), 
		_ports.get(KEY_PLAYTEST_PORT, null), 
		_ports.get(KEY_APPLY_WORLD_EDIT_PORT, null),
		_ports.get(KEY_REQUEST_AI_HELP_PORT, null),
		_ports.get(KEY_SPEECH_TO_TEXT_PORT, null),
		_feature_flags
	)
	_play_shell.setup(
		_navigator,
		_profile,
		_localization_policy,
		_ports.get(KEY_PLAYTEST_PORT, null),
		_ports.get(KEY_KID_STATUS_READ_MODEL, null)
	)
	_library_shell.setup(
		_navigator,
		_profile,
		_localization_policy,
		_ports.get(KEY_PUBLISH_PORT, null),
		_ports.get(KEY_REVIEW_PUBLISH_PORT, null),
		_ports.get(KEY_UNPUBLISH_PORT, null)
	)
	_parent_shell.setup(
		_navigator,
		_profile,
		_localization_policy,
		_ports.get(KEY_PARENTAL_CONTROLS_PORT, null),
		_ports.get(KEY_PARENT_AUDIT_READ_MODEL, null),
		_ports.get(KEY_AI_PERFORMANCE_READ_MODEL, null)
	)
	if not _create_shell.world_context_changed.is_connected(_on_world_context_changed):
		_create_shell.world_context_changed.connect(_on_world_context_changed)
	if not _create_shell.selection_provenance_changed.is_connected(_on_selection_provenance_changed):
		_create_shell.selection_provenance_changed.connect(_on_selection_provenance_changed)
	_play_shell.set_world_context(_create_shell.get_active_world_id())
	_on_selection_provenance_changed(null)

	_parent_shell.visible = _is_parent()
	_nav_parent.visible = _is_parent()


func _on_world_context_changed(world_id: String) -> void:
	_play_shell.set_world_context(world_id)


func _on_selection_provenance_changed(provenance: Variant) -> void:
	_play_shell.set_context_provenance(provenance)
	_library_shell.set_context_provenance(provenance)
	_parent_shell.set_context_provenance(provenance)


func _apply_localized_text() -> void:
	_title_label.text = _t("ui.navigation.title")
	_nav_create.text = _t("ui.navigation.create")
	_nav_play.text = _t("ui.navigation.play")
	_nav_library.text = _t("ui.navigation.library")
	_nav_parent.text = _t("ui.navigation.parent")
	
	if _nav_a11y:
		_nav_a11y.text = "♿" # Universal symbol
		_nav_a11y.tooltip_text = _t("ui.tooltip.a11y")
		
	if _a11y_dialog:
		_a11y_dialog.title = _t("ui.tooltip.a11y")
		_check_dyslexia.text = _t("ui.a11y.dyslexia")
		_check_motor.text = _t("ui.a11y.motor")
		_check_captions.text = _t("ui.a11y.captions")


func _setup_a11y_ui() -> void:
	if not has_node("Layout/NavBar"):
		return
		
	_nav_a11y = Button.new()
	_nav_a11y.name = "NavAccessibility"
	_nav_a11y.flat = true # Blend in
	_nav_a11y.add_theme_font_size_override("font_size", 24)
	_nav_a11y.focus_mode = Control.FOCUS_ALL
	
	_nav_a11y.pressed.connect(func():
		_a11y_dialog.popup_centered(Vector2(400, 300))
	)
	$Layout/NavBar.add_child(_nav_a11y)
	# Push it to the right if possible, or just append
	
	_a11y_dialog = AcceptDialog.new()
	_a11y_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	var vbox = VBoxContainer.new()
	vbox.name = "VBox" # Important for targeting if needed
	
	_check_dyslexia = CheckBox.new()
	_check_motor = CheckBox.new()
	_check_captions = CheckBox.new()
	
	vbox.add_child(_check_dyslexia)
	vbox.add_child(_check_motor)
	vbox.add_child(_check_captions)
	
	# Fix: AcceptDialog content is usually added via add_child, 
	# but in Godot 4.x explicitly, it's safer to use register_text_enter or just add to dialog
	_a11y_dialog.add_child(vbox)
	
	add_child(_a11y_dialog)
	
	# Wire
	if _accessibility_policy:
		_check_dyslexia.toggled.connect(func(enabled: bool): _accessibility_policy.set_dyslexia_font(enabled))
		_check_motor.toggled.connect(func(enabled: bool): _accessibility_policy.set_motor_scale(1.25 if enabled else 1.0))
		_check_captions.toggled.connect(func(enabled: bool): _accessibility_policy.set_captions_enabled(enabled))


func _is_parent() -> bool:
	if _profile == null:
		return false
	return _profile.is_parent()


func _t(key: String) -> String:
	if _localization_policy != null:
		return _localization_policy.translate(key)

	var fallback := {
		"ui.navigation.title": "Choyce Engine",
		"ui.navigation.create": "Twórz",
		"ui.navigation.play": "Graj",
		"ui.navigation.library": "Biblioteka",
		"ui.navigation.parent": "Strefa rodzica",
		"ui.tooltip.a11y": "Ustawienia dostępności",
		"ui.a11y.dyslexia": "Czcionka dla dyslektyków",
		"ui.a11y.motor": "Duże przyciski",
		"ui.a11y.captions": "Napisy",
	}
	return fallback.get(key, key)
