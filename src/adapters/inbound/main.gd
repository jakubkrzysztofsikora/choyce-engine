class_name InboundMain
extends Control

const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")
const ShellTransition = preload("res://src/adapters/inbound/shared/ui/shell_transition.gd")
const SHELL_LANDING := "landing"
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

@onready var _mascot: Mascot = $MascotOverlay
@onready var _landing_shell: LandingScreen = $Layout/Body/LandingShell
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


func _process(delta: float) -> void:
	# Drive debounced filesystem stores. Adapters that don't implement
	# flush_if_due are skipped — this avoids per-adapter knowledge here
	# and lets new debounced stores plug in without touching main.gd.
	if _ports.is_empty():
		return
	var elapsed_msec := int(delta * 1000.0)
	for port in _ports.values():
		if port != null and port.has_method("flush_if_due"):
			port.flush_if_due(elapsed_msec)


func _notification(what: int) -> void:
	# Synchronous flush on shutdown so the last write isn't lost.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		for port in _ports.values():
			if port != null:
				if port.has_method("flush"):
					port.flush()
				if port.has_method("flush_rotation"):
					port.flush_rotation()


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
	# Wire mascot after shell dependencies so _phase1_event_bus is populated.
	if _mascot != null:
		_mascot.setup(_phase1_event_bus, null)
	_apply_localized_text()
	_setup_transitions()
	_navigator.show_shell(SHELL_LANDING)

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

	# W1.3: ManageDataLifecycleService now denies COPPA actions on empty
	# managed_profiles. Populate explicitly so parents in this family can
	# export/delete their kid's data. Single-kid-per-family is the local-only
	# default; multi-kid setups would extend this list at profile build time.
	if role == PlayerProfile.Role.PARENT:
		var kid_id := OS.get_environment(ENV_PROFILE_ID + "_KID").strip_edges()
		if kid_id.is_empty():
			kid_id = "local_kid_1"
		profile.preferences["managed_profiles"] = [kid_id]

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

	var data_lifecycle_adapter := FilesystemDataLifecycleAdapter.new().setup(
		project_store,
		consent_store,
		audit_ledger,
		clock
	)

	var data_lifecycle := ManageDataLifecycleService.new().setup(
		data_lifecycle_adapter,
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

	# Seed starter content on first launch so the kid sees ready-to-play
	# worlds instead of an empty library + create shell.
	_seed_starter_content_if_empty(project_store, clock)

	# Re-wire shells with the persistent adapters.
	if is_node_ready():
		_wire_shell_dependencies()

	_ports_phase_2_done = true

	# Notify all listening shells that ports are ready.
	ports_ready.emit()


## Populate ProjectStore with the 3 named demo worlds (adventure / farm / city).
## Idempotent per starter ID — only seeds worlds whose project_id is absent so
## that pre-existing projects (e.g. older local_kid_1_starter_canvas entries)
## do not block the 3 current starter worlds from appearing.
func _seed_starter_content_if_empty(store: ProjectStorePort, clock: ClockPort) -> void:
	if store == null:
		return
	var now := clock.now_iso() if clock != null else ""
	var starters := [
		# WORLD 1 — Wyspa skarbów (adventure) — 10x10m, 17 nodes
		{"id": "starter_adventure", "title": "Wyspa skarbów", "template": "adventure",
		 "nodes": [
			{"name": "Skała",      "type": SceneNode.NodeType.DECORATION,   "pos": Vector3(-3, 0, 0)},
			{"name": "Skrzynia",   "type": SceneNode.NodeType.OBJECT,        "pos": Vector3(0, 0, 0)},
			{"name": "Palma",      "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(-4, 0, 4)},
			{"name": "Palma",      "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(-1, 0, 3)},
			{"name": "Palma",      "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(3, 0, 3)},
			{"name": "Most",       "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(-4, 0, -3)},
			{"name": "Łódka",      "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(2, 0, -2)},
			{"name": "Flaga",      "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(4, 0, 1)},
			{"name": "Kryształ",   "type": SceneNode.NodeType.OBJECT,        "pos": Vector3(3, 0, 0)},
			{"name": "Trawa",      "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(-2, 0, -4)},
			{"name": "Trawa",      "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(2, 0, -4)},
			{"name": "Trawa",      "type": SceneNode.NodeType.DECORATION,    "pos": Vector3(0, 0, -3)},
			{"name": "Moneta",     "type": SceneNode.NodeType.OBJECT,        "pos": Vector3(1, 0.3, -2)},
			{"name": "Moneta",     "type": SceneNode.NodeType.OBJECT,        "pos": Vector3(-2, 0.3, 2)},
			{"name": "Rozgwiazda", "type": SceneNode.NodeType.OBJECT,        "pos": Vector3(4, 0.3, -3)},
			{"name": "Perła",      "type": SceneNode.NodeType.OBJECT,        "pos": Vector3(0.5, 0.5, 0)},
			{"name": "Start",      "type": SceneNode.NodeType.SPAWN_POINT,   "pos": Vector3(0, 0.5, -4)},
		]},
		# WORLD 2 — Mała farma (farm) — 10x10m, 18 nodes
		{"id": "starter_farm", "title": "Mała farma", "template": "farm",
		 "nodes": [
			{"name": "Stodoła",     "type": SceneNode.NodeType.OBJECT,      "pos": Vector3(-4, 0, 0)},
			{"name": "Jabłoń",      "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-3, 0, 4)},
			{"name": "Jabłoń",      "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(2, 0, 4)},
			{"name": "Beli siana",  "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(0, 0, 1)},
			{"name": "Beli siana",  "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(2, 0, 1)},
			{"name": "Wiatrak",     "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(4, 0, 2)},
			{"name": "Kura",        "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-2, 0, -1)},
			{"name": "Kura",        "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(1, 0, -1)},
			{"name": "Kura",        "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(3, 0, -1)},
			{"name": "Koryto",      "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(0, 0, -2)},
			{"name": "Płot",        "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-4, 0, -4)},
			{"name": "Płot",        "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-2, 0, -4)},
			{"name": "Płot",        "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(2, 0, -4)},
			{"name": "Płot",        "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(4, 0, -4)},
			{"name": "Jabłko",      "type": SceneNode.NodeType.OBJECT,      "pos": Vector3(-3, 1.5, 3)},
			{"name": "Moneta",      "type": SceneNode.NodeType.OBJECT,      "pos": Vector3(1, 0.3, 0)},
			{"name": "Jajko",       "type": SceneNode.NodeType.OBJECT,      "pos": Vector3(-2, 0.3, -1.5)},
			{"name": "Start",       "type": SceneNode.NodeType.SPAWN_POINT, "pos": Vector3(0, 0.5, -4.5)},
		]},
		# WORLD 3 — Las grzybów (forest) — replaces previous city starter, 10x10m, 17 nodes
		{"id": "starter_forest", "title": "Las grzybów", "template": "forest",
		 "nodes": [
			{"name": "Dąb",             "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-4, 0, 4)},
			{"name": "Dąb",             "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(3, 0, 4)},
			{"name": "Dąb",             "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-1, 0, 4)},
			{"name": "Grzyb",           "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-3, 0, 1)},
			{"name": "Grzyb",           "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(3, 0, 1)},
			{"name": "Grzyb mały",      "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(0, 0, 2)},
			{"name": "Grzyb mały",      "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(0.5, 0, 2.3)},
			{"name": "Grzyb mały",      "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-0.5, 0, 1.8)},
			{"name": "Kłoda",           "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-2, 0, -1)},
			{"name": "Kamień z mchem",  "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(2, 0, -1)},
			{"name": "Kwiaty",          "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(-4, 0, -3)},
			{"name": "Kwiaty",          "type": SceneNode.NodeType.DECORATION,  "pos": Vector3(1, 0, -3)},
			{"name": "Świetlik",        "type": SceneNode.NodeType.LIGHT,       "pos": Vector3(0, 1.0, 0)},
			{"name": "Żołądź",          "type": SceneNode.NodeType.OBJECT,      "pos": Vector3(-3, 0.3, -2)},
			{"name": "Żołądź",          "type": SceneNode.NodeType.OBJECT,      "pos": Vector3(3, 0.3, 3)},
			{"name": "Słoik świetlików","type": SceneNode.NodeType.OBJECT,      "pos": Vector3(0, 0.5, 1)},
			{"name": "Start",           "type": SceneNode.NodeType.SPAWN_POINT, "pos": Vector3(0, 0.5, -4.5)},
		]},
	]
	# Build a set of project IDs already owned by this profile.
	var existing_ids: Dictionary = {}
	for entry in store.list_projects():
		if entry is Project and entry.owner_profile_id == _profile.profile_id:
			existing_ids[entry.project_id] = true

	# Collect only the starters that are not yet present.
	var to_seed: Array = []
	for seed in starters:
		var pid: String = "%s_%s" % [_profile.profile_id, seed["id"]]
		if not existing_ids.has(pid):
			to_seed.append(seed)
	if to_seed.is_empty():
		return

	for seed in to_seed:
		var project_id: String = "%s_%s" % [_profile.profile_id, seed["id"]]
		var project := Project.new(project_id, seed["title"])
		project.owner_profile_id = _profile.profile_id
		project.template_id = seed["template"]
		project.description = seed["title"]
		project.created_at = now
		project.updated_at = now
		var world := World.new("%s_world_1" % project_id, seed["title"])
		world.is_playable = true
		world.theme = seed["template"]
		for n in seed["nodes"]:
			# Include position in the id to disambiguate repeated names (e.g. "Palma" × 3).
			var pos: Vector3 = n["pos"]
			var pos_tag: String = "%d_%d_%d" % [int(pos.x * 10), int(pos.y * 10), int(pos.z * 10)]
			var node_id: String = "%s_%s_%s" % [world.world_id, str(n["name"]).to_lower(), pos_tag]
			var scene_node := SceneNode.new(node_id, n["type"])
			scene_node.display_name = n["name"]
			scene_node.position = n["pos"]
			world.add_node(scene_node)
		project.add_world(world)
		store.save_project(project)
	push_warning("Seeded %d starter worlds for profile %s" % [to_seed.size(), _profile.profile_id])


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
	# Editor runs (godot --path .) count as dev so first-time launches without
	# CHOYCE_VAULT_KEY auto-generate a per-install key instead of crashing.
	# Exported binaries don't carry the "editor" feature, so prod still
	# hard-fails when the key is unset.
	var is_dev := config.mode == DeploymentConfig.Mode.LOCAL_ONLY \
		or OS.has_feature("editor")

	# Load existing key file before evaluating dev/prod path so that a corrupt
	# key file in production triggers OS.crash rather than silently regenerating.
	var key_dir := KEY_FILE.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(key_dir))

	if FileAccess.file_exists(KEY_FILE):
		var file := FileAccess.open(KEY_FILE, FileAccess.READ)
		if file != null:
			var stored := file.get_buffer(KEY_SIZE)
			if stored.size() == KEY_SIZE:
				return stored
			# Key file exists but is not the expected size — corrupt on-disk state.
			# Silently regenerating would destroy all existing encrypted vault data.
			push_error(
				"_resolve_vault_signing_key: vault key file corrupt: %d bytes (expected %d)."
				% [stored.size(), KEY_SIZE]
			)
			push_error(
				"_resolve_vault_signing_key: delete user://choyce_vault/key to reset "
				+ "(existing encrypted policies will be unreadable after reset)."
			)
			if not is_dev:
				OS.crash(
					"Vault key file corrupt — manual reset required. "
					+ "Delete user://choyce_vault/key to recover."
				)
				return PackedByteArray()  # unreachable in prod
			# Dev mode only: warn and fall through to regenerate so developers can recover.
			push_warning(
				"_resolve_vault_signing_key: dev mode — regenerating key despite corrupt file. "
				+ "Existing encrypted policies will be unreadable."
			)

	if not is_dev:
		# Prod / classroom: must have an explicit key — hard fail.
		push_error(
			"_resolve_vault_signing_key: CHOYCE_VAULT_KEY not set in production build. Vault cannot start."
		)
		OS.crash("CHOYCE_VAULT_KEY required in production. Set the environment variable.")
		return PackedByteArray()  # unreachable

	# Dev path: generate a fresh random key and persist it.
	push_warning(
		("_resolve_vault_signing_key: no vault key found — generating per-install key at '%s'. "
		+ "This is only acceptable in LOCAL_ONLY / dev mode.") % KEY_FILE
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
	_navigator.register_shell(SHELL_LANDING, _landing_shell)
	_navigator.register_shell(SHELL_CREATE, _create_shell)
	_navigator.register_shell(SHELL_PLAY, _play_shell)
	_navigator.register_shell(SHELL_LIBRARY, _library_shell)
	_navigator.register_shell(SHELL_PARENT, _parent_shell)


func _connect_navigation() -> void:
	_nav_create.pressed.connect(func() -> void: _navigator.show_shell(SHELL_CREATE))
	_nav_play.pressed.connect(func() -> void: _navigator.show_shell(SHELL_PLAY))
	_nav_library.pressed.connect(func() -> void: _navigator.show_shell(SHELL_LIBRARY))
	_nav_parent.pressed.connect(func() -> void: _navigator.show_shell(SHELL_PARENT))

	# LandingScreen signals → shell navigation.
	_landing_shell.play_pressed.connect(func() -> void: _navigator.show_shell(SHELL_PLAY))
	_landing_shell.create_pressed.connect(func() -> void: _navigator.show_shell(SHELL_CREATE))
	_landing_shell.parent_pressed.connect(func() -> void: _navigator.show_shell(SHELL_PARENT))
	_landing_shell.world_card_pressed.connect(_on_world_card_pressed)

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


func _on_world_card_pressed(project_id: String, world_id: String) -> void:
	# Direct-launch path from LandingScreen. PlayShell.launch_world_by_id loads
	# the project, picks the right world, plays template-matched music, and
	# starts a session through RunPlaytestPort — all of which set_world_context
	# + _launch_playtest do NOT do (set_world_context only refreshes the
	# kid-status summary). Previous handler silently no-op'd because PlayShell
	# had no project context to resolve world_id against.
	_navigator.show_shell(SHELL_PLAY)
	if _play_shell.has_method("launch_world_by_id"):
		_play_shell.launch_world_by_id(project_id, world_id)
	else:
		push_warning("PlayShell missing launch_world_by_id — falling back to context-only")
		if not world_id.is_empty():
			_play_shell.set_world_context(world_id)


func _wire_shell_dependencies() -> void:
	# Wire landing screen with profile + project store + localization.
	_landing_shell.setup(_profile, _phase1_project_store, _localization_policy)

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
	# Wire project_store so LandingScreen world-card clicks can resolve the
	# project + launch directly via PlayShell.launch_world_by_id. Without
	# this _on_world_card_pressed silently no-ops.
	if _play_shell.has_method("setup_for_direct_launch"):
		_play_shell.setup_for_direct_launch(_phase1_project_store)
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
		return
	# W1.6: theme load failure used to silently fall back to engine defaults,
	# masking the missing .import sidecars for the font assets it references.
	# Loud failure so the next reviewer sees the regression instead of
	# attributing the styling drift to design choices.
	push_error(
		"Theme failed to load — UI will render with engine defaults. "
		+ "Verify data/themes/choyce_theme.tres exists and that the fonts/audio "
		+ ".import sidecars under data/ are committed (run godot --headless --import)."
	)


func _apply_navigation_theme() -> void:
	# Warm cream pill with primary orange border
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(1, 0.97, 0.94, 0.95)
	pill_style.corner_radius_top_left = 32
	pill_style.corner_radius_top_right = 32
	pill_style.corner_radius_bottom_left = 32
	pill_style.corner_radius_bottom_right = 32
	pill_style.border_width_left = 3
	pill_style.border_width_top = 3
	pill_style.border_width_right = 3
	pill_style.border_width_bottom = 3
	pill_style.border_color = Color(1.0, 0.42, 0.21, 1)
	pill_style.shadow_color = Color(0, 0, 0, 0.08)
	pill_style.shadow_size = 6
	pill_style.shadow_offset = Vector2(0, 3)
	pill_style.content_margin_left = 12
	pill_style.content_margin_top = 8
	pill_style.content_margin_right = 12
	pill_style.content_margin_bottom = 8
	_nav_bar.add_theme_stylebox_override("panel", pill_style)

	# Title in primary orange
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.21, 1))
	_title_label.add_theme_font_size_override("font_size", 22)

	if _active_indicator != null:
		var indicator_style := StyleBoxFlat.new()
		# Active indicator: primary orange, height 6, radius 3
		indicator_style.bg_color = Color(1.0, 0.42, 0.21, 1)
		indicator_style.corner_radius_top_left = 3
		indicator_style.corner_radius_top_right = 3
		indicator_style.corner_radius_bottom_left = 3
		indicator_style.corner_radius_bottom_right = 3
		_active_indicator.add_theme_stylebox_override("panel", indicator_style)
		_active_indicator.custom_minimum_size.y = 6
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
		btn.add_theme_color_override("font_color", Color(0.42, 0.36, 0.31, 1))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.43, 1))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.42, 0.21, 1))
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
