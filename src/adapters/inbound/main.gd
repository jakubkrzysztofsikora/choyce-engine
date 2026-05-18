class_name InboundMain
extends Control

const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")
const ShellTransition = preload("res://src/adapters/inbound/shared/ui/shell_transition.gd")
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
const KEY_DATA_LIFECYCLE_PORT := "data_lifecycle_port"
const ENV_PROFILE_ROLE := "CHOYCE_PROFILE_ROLE"
const ENV_PROFILE_ID := "CHOYCE_PROFILE_ID"
const ENV_PROFILE_NAME := "CHOYCE_PROFILE_NAME"
const ENV_FAMILY_ID := "CHOYCE_FAMILY_ID"
const ENV_CLASSROOM_ID := "CHOYCE_CLASSROOM_ID"

## Phase 8d: emitted when deferred (heavy I/O) adapters have finished initialising.
## Inbound shells gate voice/AI input until this signal fires.
signal ports_ready

var _navigator := ShellNavigator.new()
var _ports: Dictionary = {}
var _feature_flags: FeatureFlagService
var _localization_policy: LocalizationPolicyPort
var _accessibility_policy: AccessibilityPolicyPort
var _profile: PlayerProfile

## Phase 8d: set to true once _build_default_ports_phase_2 completes.
var _ports_phase_2_done: bool = false

# Phase 8d: shared objects produced by Phase 1 and consumed by Phase 2.
var _phase1_env: OSEnvironmentAdapter
var _phase1_clock: SystemClock
var _phase1_event_bus: DomainEventBus
var _phase1_project_store: FilesystemProjectStore
var _phase1_moderation: LocalModerationAdapter
var _phase1_publishing_policy: PublishingPolicy
var _phase1_telemetry: LocalTelemetry
var _phase1_ai_performance: AIPerformanceReadModelAdapter
var _phase1_kid_status: KidStatusReadModelAdapter
var _phase1_parent_audit: ParentAuditReadModelAdapter
var _phase1_tool_gateway: DeterministicToolExecutionGateway

@onready var _nav_bar: PanelContainer = $Layout/NavBar
@onready var _nav_pill: HBoxContainer = $Layout/NavBar/NavPill
@onready var _nav_create: Button = $Layout/NavBar/NavPill/NavCreate
@onready var _nav_play: Button = $Layout/NavBar/NavPill/NavPlay
@onready var _nav_library: Button = $Layout/NavBar/NavPill/NavLibrary
@onready var _nav_parent: Button = $Layout/NavBar/NavPill/NavParent
@onready var _active_indicator: PanelContainer = $ActiveIndicator
@onready var _title_label: Label = $Layout/NavBar/NavPill/TitleLabel

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

var _shell_transition: ShellTransition
var _nav_buttons: Dictionary = {}
var _accent_color := Color8(120, 210, 255)


func _ready() -> void:
	if _accessibility_policy == null:
		_accessibility_policy = GodotAccessibilityAdapter.new().setup(self)
	_accessibility_policy.apply_baseline_contrast()

	if _feature_flags == null:
		var _env_adapter := OSEnvironmentAdapter.new()
		var config = DeploymentConfig.from_environment(_env_adapter)
		_feature_flags = FeatureFlagService.new(config).setup(_env_adapter)

	_ensure_runtime_composition()
	_setup_a11y_ui()
	_apply_navigation_theme()
	_apply_global_theme()
	_register_shells()
	_connect_navigation()
	_wire_shell_dependencies()
	_apply_localized_text()
	_setup_transitions()
	_navigator.show_shell(SHELL_CREATE)

	# Phase 8d: schedule heavy-I/O adapter initialisation for the next frame so
	# the first frame returns quickly. Shells remain in the ports_ready=false gate
	# until _build_default_ports_phase_2 fires ports_ready.
	if not _ports_phase_2_done:
		call_deferred("_build_default_ports_phase_2")


func setup(profile: PlayerProfile, ports: Dictionary, localization_policy: LocalizationPolicyPort, accessibility_policy: AccessibilityPolicyPort) -> InboundMain:
	_profile = profile
	_ports = ports
	_localization_policy = localization_policy
	_accessibility_policy = accessibility_policy
	_ensure_runtime_composition()

	if is_node_ready():
		_wire_shell_dependencies()
		_apply_localized_text()

	return self


func _ensure_runtime_composition() -> void:
	if _profile == null:
		_profile = _build_default_profile()
	if _localization_policy == null:
		_localization_policy = PolishLocalizationPolicy.new()
	if _ports == null:
		_ports = {}

	var defaults := _build_default_ports()
	for key in defaults.keys():
		if not _ports.has(key) or _ports[key] == null:
			_ports[key] = defaults[key]


func _build_default_profile() -> PlayerProfile:
	var role_env := OS.get_environment(ENV_PROFILE_ROLE).strip_edges().to_lower()
	var role := PlayerProfile.Role.PARENT if role_env == "parent" else PlayerProfile.Role.KID
	var default_id := "local_parent_1" if role == PlayerProfile.Role.PARENT else "local_kid_1"
	var profile_id := OS.get_environment(ENV_PROFILE_ID).strip_edges()
	if profile_id.is_empty():
		profile_id = default_id

	var profile := PlayerProfile.new(profile_id, role)
	var profile_name := OS.get_environment(ENV_PROFILE_NAME).strip_edges()
	if profile_name.is_empty():
		profile_name = "Opiekun" if role == PlayerProfile.Role.PARENT else "Dziecko"
	profile.display_name = profile_name
	profile.language = "pl-PL"

	var family_id := OS.get_environment(ENV_FAMILY_ID).strip_edges()
	if family_id.is_empty():
		family_id = "family_local"
	profile.preferences["family_id"] = family_id

	var classroom_id := OS.get_environment(ENV_CLASSROOM_ID).strip_edges()
	if not classroom_id.is_empty():
		profile.preferences["classroom_id"] = classroom_id

	return profile


## Phase 8d: Phase 1 — critical adapters only. Returns immediately with lightweight
## in-memory stubs for the heavy-I/O slots (audit ledger, publish store, consent
## store, encrypted policy vault). Deferred phase swaps these out and emits
## ports_ready so that shells unlock voice/AI input.
func _build_default_ports() -> Dictionary:
	# Phase 7b: single OSEnvironmentAdapter instance shared by all consumers in
	# this composition root. No application or domain code calls OS.get_environment directly.
	var env := OSEnvironmentAdapter.new()

	var clock := SystemClock.new()
	var event_bus := DomainEventBus.new()
	var project_store := FilesystemProjectStore.new().setup()
	var moderation := LocalModerationAdapter.new().setup()
	var publishing_policy := PublishingPolicy.new()
	var telemetry := LocalTelemetry.new().setup()
	var ai_performance := AIPerformanceReadModelAdapter.new()
	var kid_status := KidStatusReadModelAdapter.new()

	# Phase 8d: lightweight stubs used until _build_default_ports_phase_2 completes.
	# Stubs use in-memory adapters so nothing blocks the first frame.
	var publish_store_stub: PublishStorePort = InMemoryPublishStore.new().setup()
	var consent_store_stub: IdentityConsentPort = LocalConsentStore.new().setup()
	var audit_ledger_stub: AuditLedgerPort = InMemoryAuditLedger.new().setup()
	var policy_store_stub: ParentalPolicyStorePort = InMemoryParentalPolicyStore.new().setup()

	var parent_audit := ParentAuditReadModelAdapter.new().setup(audit_ledger_stub, clock)

	event_bus.subscribe_all(Callable(parent_audit, "update_from_event"))
	event_bus.subscribe_all(Callable(ai_performance, "update_from_event"))
	event_bus.subscribe_all(Callable(kid_status, "update_from_event"))

	var llm := OllamaLLMAdapter.new().setup(consent_store_stub)
	var tool_gateway := DeterministicToolExecutionGateway.new().setup()

	var data_lifecycle := ManageDataLifecycleService.new().setup(
		null,          # DataLifecyclePort backend — no cloud backend in default build
		null,          # RoleTokenGuard — optional, omitted in default build
		clock,
		audit_ledger_stub,
		policy_store_stub
	)

	# Store shared objects needed by Phase 2 as instance fields.
	_phase1_env = env
	_phase1_clock = clock
	_phase1_event_bus = event_bus
	_phase1_project_store = project_store
	_phase1_moderation = moderation
	_phase1_publishing_policy = publishing_policy
	_phase1_telemetry = telemetry
	_phase1_ai_performance = ai_performance
	_phase1_kid_status = kid_status
	_phase1_parent_audit = parent_audit
	_phase1_tool_gateway = tool_gateway

	return {
		KEY_CREATE_PORT: CreateProjectService.new().setup(project_store, clock),
		KEY_PLAYTEST_PORT: RunPlaytestService.new().setup(project_store, clock),
		KEY_APPLY_WORLD_EDIT_PORT: ApplyWorldEditService.new().setup(
			project_store,
			clock,
			event_bus,
			EventSourcedActionLog.new()
		),
		KEY_PUBLISH_PORT: PublishToFamilyLibraryService.new().setup(
			project_store,
			publish_store_stub,
			moderation,
			clock,
			publishing_policy,
			event_bus
		),
		KEY_REVIEW_PUBLISH_PORT: ReviewPublishRequestService.new().setup(
			publish_store_stub,
			publishing_policy,
			clock,
			event_bus
		),
		KEY_UNPUBLISH_PORT: UnpublishWorldService.new().setup(
			publish_store_stub,
			publishing_policy,
			clock,
			event_bus
		),
		KEY_PARENTAL_CONTROLS_PORT: SetParentalControlsService.new().setup(
			consent_store_stub,
			clock,
			telemetry,
			policy_store_stub,
			event_bus
		),
		KEY_REQUEST_AI_HELP_PORT: RequestAICreationHelpService.new().setup(
			llm,
			moderation,
			clock,
			_localization_policy,
			event_bus,
			tool_gateway,
			null,
			null,
			policy_store_stub,
			null,
			null
		),
		KEY_SPEECH_TO_TEXT_PORT: _build_moderating_stt(moderation, event_bus),
		KEY_KID_STATUS_READ_MODEL: kid_status,
		KEY_PARENT_AUDIT_READ_MODEL: parent_audit,
		KEY_AI_PERFORMANCE_READ_MODEL: ai_performance,
		KEY_DATA_LIFECYCLE_PORT: data_lifecycle,
	}


## Phase 8d: Phase 2 — deferred heavy-I/O initialisation.
## Runs on the frame after _ready() returns (via call_deferred).
## Replaces stub adapters with persistent filesystem / encrypted-vault variants,
## then emits ports_ready so shells unlock voice/AI input.
func _build_default_ports_phase_2() -> void:
	if _ports_phase_2_done:
		return

	var env: OSEnvironmentAdapter = _phase1_env
	var clock = _phase1_clock
	var event_bus = _phase1_event_bus
	var project_store = _phase1_project_store
	var moderation = _phase1_moderation
	var publishing_policy = _phase1_publishing_policy
	var telemetry = _phase1_telemetry
	var parent_audit = _phase1_parent_audit
	var tool_gateway = _phase1_tool_gateway

	# Heavy I/O: filesystem publish store.
	var publish_store := FilesystemPublishStore.new().setup("user://choyce_publish")

	# Heavy I/O: filesystem consent store.
	var consent_store := FilesystemConsentStore.new().setup("user://choyce_consent")

	# Heavy I/O: encrypted parental policy vault.
	var signing_key := _resolve_vault_signing_key(env)
	var encrypted_storage := LocalEncryptedStorage.new().setup()
	var policy_store := EncryptedParentalPolicyStore.new().setup(
		encrypted_storage,
		signing_key,
		"user://choyce_vault/parental_policies",
		event_bus
	)

	# Heavy I/O: filesystem audit ledger (unless test override requests in-memory).
	var audit_ledger: AuditLedgerPort
	if env.get_env("CHOYCE_AUDIT_IN_MEMORY", "") == "1":
		audit_ledger = InMemoryAuditLedger.new().setup()
	else:
		audit_ledger = FilesystemAuditLedger.new().setup("user://choyce_audit")

	# Re-wire parent audit to the persistent ledger.
	if parent_audit != null and parent_audit.has_method("setup"):
		parent_audit.setup(audit_ledger, clock)

	var llm := OllamaLLMAdapter.new().setup(consent_store)

	var data_lifecycle := ManageDataLifecycleService.new().setup(
		null,
		null,
		clock,
		audit_ledger,
		policy_store
	)

	# Overwrite stub ports with persistent variants.
	_ports[KEY_PUBLISH_PORT] = PublishToFamilyLibraryService.new().setup(
		project_store,
		publish_store,
		moderation,
		clock,
		publishing_policy,
		event_bus
	)
	_ports[KEY_REVIEW_PUBLISH_PORT] = ReviewPublishRequestService.new().setup(
		publish_store,
		publishing_policy,
		clock,
		event_bus
	)
	_ports[KEY_UNPUBLISH_PORT] = UnpublishWorldService.new().setup(
		publish_store,
		publishing_policy,
		clock,
		event_bus
	)
	_ports[KEY_PARENTAL_CONTROLS_PORT] = SetParentalControlsService.new().setup(
		consent_store,
		clock,
		telemetry,
		policy_store,
		event_bus
	)
	_ports[KEY_REQUEST_AI_HELP_PORT] = RequestAICreationHelpService.new().setup(
		llm,
		moderation,
		clock,
		_localization_policy,
		event_bus,
		tool_gateway,
		null,
		null,
		policy_store,
		null,
		null
	)
	_ports[KEY_SPEECH_TO_TEXT_PORT] = _build_moderating_stt(moderation, event_bus)
	_ports[KEY_DATA_LIFECYCLE_PORT] = data_lifecycle
	_ports[KEY_PARENT_AUDIT_READ_MODEL] = parent_audit

	# Re-wire shells with the persistent adapters.
	if is_node_ready():
		_wire_shell_dependencies()

	_ports_phase_2_done = true

	# Notify all listening shells that ports are ready.
	ports_ready.emit()


## Phase 6: Resolve the 32-byte AES-256 vault signing key.
## Phase 7b: accepts EnvironmentPort so OS.get_environment is not called directly here.
## Priority:
##   1. CHOYCE_VAULT_KEY env var (hex-encoded, 64 chars → 32 bytes).
##   2. Dev mode: auto-generate per-install key, persist in user://choyce_vault/key.
##   3. Prod mode (FAMILY_CLOUD, CLASSROOM): hard-fail — no key means no vault.
func _resolve_vault_signing_key(env: EnvironmentPort) -> PackedByteArray:
	const VAULT_KEY_ENV := "CHOYCE_VAULT_KEY"
	const KEY_FILE := "user://choyce_vault/key"
	const KEY_SIZE := 32

	# 1. Environment variable (highest priority).
	var env_key := env.get_env(VAULT_KEY_ENV, "").strip_edges()
	if not env_key.is_empty():
		var bytes := env_key.hex_decode()
		if bytes.size() == KEY_SIZE:
			return bytes
		push_error(
			"_resolve_vault_signing_key: CHOYCE_VAULT_KEY must be 64 hex chars (32 bytes). Got %d bytes." % bytes.size()
		)
		# Fall through to per-install path — safer than crashing on a mis-formatted env var in dev.

	# 2. Per-install key in user:// directory.
	var config := DeploymentConfig.from_environment(env)
	var is_dev := config.mode == DeploymentConfig.Mode.LOCAL_ONLY

	if not is_dev:
		# Prod / classroom: must have an explicit key — hard fail.
		push_error(
			"_resolve_vault_signing_key: CHOYCE_VAULT_KEY not set in production build. Vault cannot start."
		)
		OS.crash("CHOYCE_VAULT_KEY required in production. Set the environment variable.")
		return PackedByteArray()  # unreachable

	# Dev path: load or generate a per-install key.
	var key_dir := KEY_FILE.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(key_dir))

	if FileAccess.file_exists(KEY_FILE):
		var file := FileAccess.open(KEY_FILE, FileAccess.READ)
		if file != null:
			var stored := file.get_buffer(KEY_SIZE)
			if stored.size() == KEY_SIZE:
				return stored

	# Generate a fresh random key and persist it.
	push_warning(
		"_resolve_vault_signing_key: no vault key found — generating per-install key at '%s'. "
		+ "This is only acceptable in LOCAL_ONLY / dev mode." % KEY_FILE
	)
	var crypto := Crypto.new()
	var new_key := crypto.generate_random_bytes(KEY_SIZE)
	var out := FileAccess.open(KEY_FILE, FileAccess.WRITE)
	if out != null:
		out.store_buffer(new_key)
	else:
		push_error("_resolve_vault_signing_key: cannot persist generated key to '%s'" % KEY_FILE)
	return new_key


## Build the moderating STT adapter (Phase 3, FR-022).
## Composes LocalSTTAdapter + PolishIntentExtractor + VoiceInputModerationService.
## VoiceInputModerationService is NOT registered as a port — it is an internal
## implementation detail of the adapter.
func _build_moderating_stt(
	moderation: ModerationPort,
	event_bus: DomainEventBus
) -> ModeratingSttAdapter:
	var raw_stt := LocalSTTAdapter.new().setup()
	var intent_extractor := PolishIntentExtractor.new()
	var voice_mod := VoiceInputModerationService.new().setup(moderation, intent_extractor, event_bus)
	var moderating_stt := ModeratingSttAdapter.new().setup(raw_stt, voice_mod)
	return moderating_stt


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
	
	_navigator.shell_changed.connect(_on_shell_changed)


func _setup_transitions() -> void:
	_shell_transition = ShellTransition.new()
	_shell_transition.name = "ShellTransition"
	add_child(_shell_transition)
	_navigator.set_transition_callback(_on_transition_requested)


func _on_transition_requested(from_shell_id: String, to_shell_id: String) -> void:
	var from_shell := _navigator.get_shell(from_shell_id)
	var to_shell := _navigator.get_shell(to_shell_id)
	
	if from_shell == null or from_shell_id == to_shell_id:
		# First switch or same shell
		if to_shell != null:
			to_shell.visible = true
			if from_shell != null and from_shell != to_shell:
				from_shell.visible = false
		_navigator._instant_switch(to_shell_id)
		return
	
	_shell_transition.transition_out(from_shell, func() -> void:
		if to_shell != null:
			_shell_transition.transition_in(to_shell)
		_navigator._instant_switch(to_shell_id)
	)


func _on_shell_changed(shell_id: String) -> void:
	_update_active_indicator(shell_id)


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
		_ports.get(KEY_KID_STATUS_READ_MODEL, null),
		func() -> World:
			if _create_shell.has_method("get_active_world"):
				return _create_shell.get_active_world()
			return null
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
		_ports.get(KEY_AI_PERFORMANCE_READ_MODEL, null),
		_ports.get(KEY_DATA_LIFECYCLE_PORT, null)
	)
	if not _create_shell.world_context_changed.is_connected(_on_world_context_changed):
		_create_shell.world_context_changed.connect(_on_world_context_changed)
	if not _create_shell.selection_provenance_changed.is_connected(_on_selection_provenance_changed):
		_create_shell.selection_provenance_changed.connect(_on_selection_provenance_changed)
	_play_shell.set_world_context(_create_shell.get_active_world_id())
	_on_selection_provenance_changed(null)

	_parent_shell.visible = _is_parent()
	_nav_parent.visible = _is_parent()

	# Phase 8d: connect ports_ready to any shell that declares on_ports_ready().
	# CreateShell hosts voice/AI buttons and must receive the signal.
	# Guard against duplicate connections (wiring may be called more than once).
	if _create_shell.has_method("on_ports_ready"):
		if not ports_ready.is_connected(_create_shell.on_ports_ready):
			ports_ready.connect(_create_shell.on_ports_ready)

	# If Phase 2 already completed before _wire_shell_dependencies was called
	# (e.g. in tests), fire the callback immediately so the gate is unlocked.
	if _ports_phase_2_done and _create_shell.has_method("on_ports_ready"):
		_create_shell.on_ports_ready()


func _on_world_context_changed(world_id: String) -> void:
	_play_shell.set_world_context(world_id)


func _on_selection_provenance_changed(provenance: Variant) -> void:
	_play_shell.set_context_provenance(provenance)
	_library_shell.set_context_provenance(provenance)
	_parent_shell.set_context_provenance(provenance)


func _apply_localized_text() -> void:
	_title_label.text = _t("ui.navigation.title")
	_nav_create.text = "%s %s" % [IconFont.get_icon("build"), _t("ui.navigation.create")]
	_nav_play.text = "%s %s" % [IconFont.get_icon("play"), _t("ui.navigation.play")]
	_nav_library.text = "%s %s" % [IconFont.get_icon("library"), _t("ui.navigation.library")]
	_nav_parent.text = "%s %s" % [IconFont.get_icon("parent"), _t("ui.navigation.parent")]
	
	if _nav_a11y:
		_nav_a11y.text = "♿"
		_nav_a11y.tooltip_text = _t("ui.tooltip.a11y")
		
	if _a11y_dialog:
		_a11y_dialog.title = _t("ui.tooltip.a11y")
		_check_dyslexia.text = _t("ui.a11y.dyslexia")
		_check_motor.text = _t("ui.a11y.motor")
		_check_captions.text = _t("ui.a11y.captions")


func _apply_global_theme() -> void:
	var theme := load("res://data/themes/choyce_theme.tres") as Theme
	if theme != null:
		self.theme = theme


func _apply_navigation_theme() -> void:
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color8(245, 248, 252)
	pill_style.corner_radius_top_left = 24
	pill_style.corner_radius_top_right = 24
	pill_style.corner_radius_bottom_left = 24
	pill_style.corner_radius_bottom_right = 24
	pill_style.border_width_left = 2
	pill_style.border_width_top = 2
	pill_style.border_width_right = 2
	pill_style.border_width_bottom = 2
	pill_style.border_color = Color8(210, 225, 240)
	pill_style.shadow_color = Color(0, 0, 0, 0.08)
	pill_style.shadow_size = 6
	pill_style.shadow_offset = Vector2(0, 3)
	pill_style.content_margin_left = 12
	pill_style.content_margin_top = 8
	pill_style.content_margin_right = 12
	pill_style.content_margin_bottom = 8
	_nav_bar.add_theme_stylebox_override("panel", pill_style)
	
	_title_label.add_theme_color_override("font_color", Color8(18, 26, 38))
	_title_label.add_theme_font_size_override("font_size", 22)
	
	if _active_indicator != null:
		var indicator_style := StyleBoxFlat.new()
		indicator_style.bg_color = _accent_color
		indicator_style.corner_radius_top_left = 2
		indicator_style.corner_radius_top_right = 2
		indicator_style.corner_radius_bottom_left = 2
		indicator_style.corner_radius_bottom_right = 2
		_active_indicator.add_theme_stylebox_override("panel", indicator_style)
		_active_indicator.visible = false
	
	_nav_buttons = {
		SHELL_CREATE: _nav_create,
		SHELL_PLAY: _nav_play,
		SHELL_LIBRARY: _nav_library,
		SHELL_PARENT: _nav_parent,
	}
	
	for shell_id in _nav_buttons.keys():
		var btn: Button = _nav_buttons[shell_id]
		if btn == null:
			continue
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color8(80, 90, 110))
		btn.add_theme_color_override("font_hover_color", Color8(40, 50, 70))
		btn.add_theme_color_override("font_pressed_color", Color8(20, 30, 45))
		btn.focus_mode = Control.FOCUS_NONE
	
	_update_active_indicator(SHELL_CREATE)


func _update_active_indicator(shell_id: String) -> void:
	var btn: Button = _nav_buttons.get(shell_id, null)
	if btn == null or _active_indicator == null:
		return
	
	var btn_rect := btn.get_global_rect()
	var target_pos := btn_rect.position - self.global_position
	target_pos.y += btn_rect.size.y - 4
	
	_active_indicator.visible = true
	if is_inside_tree():
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(_active_indicator, "position:x", target_pos.x, 0.2)
		tween.parallel().tween_property(_active_indicator, "size:x", btn_rect.size.x, 0.2)
		tween.parallel().tween_property(_active_indicator, "position:y", target_pos.y, 0.2)
	else:
		_active_indicator.position = target_pos
		_active_indicator.size.x = btn_rect.size.x
	
	# Update button colors
	for sid in _nav_buttons.keys():
		var b: Button = _nav_buttons[sid]
		if b == null:
			continue
		if sid == shell_id:
			b.add_theme_color_override("font_color", Color8(30, 40, 60))
			b.add_theme_font_size_override("font_size", 20)
		else:
			b.add_theme_color_override("font_color", Color8(100, 110, 130))
			b.add_theme_font_size_override("font_size", 18)


func _setup_a11y_ui() -> void:
	if not has_node("Layout/NavBar"):
		return
		
	_nav_a11y = Button.new()
	_nav_a11y.name = "NavAccessibility"
	_nav_a11y.flat = true
	_nav_a11y.add_theme_font_size_override("font_size", 24)
	_nav_a11y.focus_mode = Control.FOCUS_ALL
	
	_nav_a11y.pressed.connect(func():
		_a11y_dialog.popup_centered(Vector2(400, 300))
	)
	$Layout/NavBar/NavPill.add_child(_nav_a11y)
	
	_a11y_dialog = AcceptDialog.new()
	_a11y_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	
	_check_dyslexia = CheckBox.new()
	_check_motor = CheckBox.new()
	_check_captions = CheckBox.new()
	
	vbox.add_child(_check_dyslexia)
	vbox.add_child(_check_motor)
	vbox.add_child(_check_captions)
	
	_a11y_dialog.add_child(vbox)
	
	add_child(_a11y_dialog)
	
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
