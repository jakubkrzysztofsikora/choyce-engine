class_name GameplayRuntime
extends Node3D

const FACIAL_PERFORMANCE_SCRIPT := preload("res://src/adapters/inbound/gameplay/facial_performance.gd")
const SKY3D_SCRIPT := preload("res://addons/sky_3d/src/Sky3D.gd")

signal session_ended
## Emitted at session-end with the WinOutcome so HUD/celebration
## can branch on win vs. lose vs. reason. Always fires before
## session_ended for backwards-compat consumers.
signal session_outcome(outcome: WinOutcome)
## Emitted when a rule's action fires.
##   action_kind: int — CompiledRule.ActionKind value
##   params:      Dict — action params
signal rule_fired(rule_id: String, action_kind: int, params: Dictionary)

## VS-016: Evidence capture signals for visual acceptance testing
signal evidence_capture_requested(capture_point: int)

var _world_renderer: WorldRenderer
var _player_controller: PlayerController
var _session: Session

## VS-016: Track which evidence capture points have been triggered
## to ensure we only capture once per point
var _captured_evidence_points: Array = []
var _audio_bus: AudioEventBus
var _sfx_player: SFXPlayer
## Live NPC voice (ElevenLabs TTS). Silent no-op without ELEVENLABS_API_KEY.
var _npc_voice: VoicePromptPort = null
var _effect_spawner: EffectSpawner
var _screen_feedback: ScreenFeedback
var _victory_sequence: VictorySequence
var _ambient_player: AudioStreamPlayer
var _ambient_particles: GPUParticles3D
var _adventure_sky: WorldEnvironment = null
var _adventure_legacy_environment: WorldEnvironment = null
var _adventure_legacy_environment_resource: Environment = null
var _adventure_legacy_light_visibility: Dictionary = {}

# Rules engine — injected by main.gd via setup_rules() before start_session.
# Optional: GameplayRuntime keeps working with null rules (legacy worlds).
var _rules_runtime: RulesRuntimePort
var _rule_compiler: RuleCompilerService
var _score: int = 0
var _rules_active: bool = false

# Combat HUD references — built lazily in _build_hud.
var _hp_bar: ProgressBar
var _score_label: Label
var _stats_panel: PanelContainer
var _enemy_root: Node3D
var _loot_root: Node3D
var _build_grid: BuildGrid
var _hotbar_panel: HBoxContainer
## The undo control is contextual: it only appears after the child has made a
## build edit. Keeping it visible from the first frame made the opening read as
## an editor rather than an adventure.
var _undo_button: Button
var _inventory_panel: Container
var _inventory_labels: Dictionary = {}  ## item_id -> Label
var _weapon_tiers := [
	{"id": "fist",      "damage": 4,  "label": "Pięść",          "needs": {}},
	{"id": "stick",     "damage": 7,  "label": "Patyk",          "needs": {"wood_oak": 3}},
	{"id": "sword_iron","damage": 12, "label": "Żelazny miecz",  "needs": {"ore_iron": 3, "wood_oak": 2}},
	{"id": "sword_epic","damage": 20, "label": "Epicki miecz",   "needs": {"ore_iron": 8, "slime_gel": 5}},
]
var _current_weapon_index: int = 0
var _weapon_label: Label
var _wave_number: int = 0
var _wave_respawn_timer: float = 0.0
var _rng: RandomNumberGenerator = null
## Adv Y H5: track last attack style for phase-aware feedback
var _last_attack_style: String = "punch"

# Application services extracted from this adapter per Adv 1 H1/H2.
# Lazy-init so legacy callers (autoplay, tests) keep working.
var _gear_service: GearProgressionService = null
var _wave_service: WaveDirectorService = null
var _combat_service: CombatService = null
var _xp_service: XpProgressionService = null
# Authored data lists (loaded from res://data/*.tres at session start
# if files exist; otherwise the procedural fallback kicks in).
var _gear_tiers: Array = []       ## Array[GearTierResource]
var _wave_configs: Array = []     ## Array[WaveConfig]
# XP/level state — survives within a session; reset on end_session
# per CLAUDE.md greenfield-wipe policy.
var _xp_level: int = 0
var _xp_current: int = 0
var _xp_bar: ProgressBar = null
var _xp_label: Label = null

# VS-021: Vehicle system
var _vehicle_spawner: VehicleSpawner = null
var _destruction_tracker: DestructionTracker = null
var _active_vehicle: VehicleBase = null

const WAVE_RESPAWN_DELAY := 6.0
## Kid falls below this y → soft-respawn. Fixes spring-launch
## softlock (Adv 2 H-5). Default world floor is y=0; -50 leaves a
## comfortable buffer for tall builds.
const FALL_KILL_PLANE_Y := -50.0
const HUD_ACTION_GREEN: Texture2D = preload("res://data/textures/ui/PNG/Green/Double/button_round_depth_gloss.png")
const HUD_ICON_AXE: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/tool-axe.png")
const HUD_ICON_HAMMER: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/tool-hammer.png")
const HUD_ICON_GRASS: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/grass.png")
const HUD_ICON_WOOD: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/resource-wood.png")
const HUD_ICON_STONE: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/resource-stone.png")
const HUD_ICON_WORKBENCH: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/workbench.png")
const HUD_ICON_BEDROLL: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/bedroll.png")
const HUD_ICON_STAR: Texture2D = preload("res://data/textures/ui/PNG/Yellow/Double/star.png")
const HUD_ICON_RETURN: Texture2D = preload("res://data/textures/ui/PNG/Blue/Double/arrow_basic_w.png")
const HUD_ICON_UNDO: Texture2D = preload("res://data/textures/ui/PNG/Yellow/Double/arrow_basic_w.png")

# Goal + lose-condition injection (Wave 3 W3-A/B). Populated by
# setup_goal() from main.gd composition root, sourced from the
# template pack's optional default_goal + lose_conditions. Null = sandbox
# free-play mode (no forced win-screen or loss, kid can explore and leave).
var _goal: GameGoal = null
var _goal_evaluator: EvaluateGoalService = null
## Debug-only: when CHOYCE_AUTOWIN=1 in a debug/editor build, defeat one enemy
## per tick so goal-bearing templates can exercise the generic completion path
## headlessly (no input automation). Never active in a release build.
var _autowin: bool = false
var _lives_remaining: int = -1            ## -1 = unlimited
var _time_limit_sec: int = 0              ## 0 = no timer
var _kill_plane_y: float = FALL_KILL_PLANE_Y
var _session_elapsed_sec: float = 0.0
var _outcome_emitted: bool = false        ## Guard so end_session is idempotent.
var _last_goal_check_ratio: float = 0.0   ## Cached so HUD can paint a progress bar.

# Wave 3 W3-A3 NPC roster. Injected via setup_npcs(); populated by
# PlayShell from NPCDialogueLoader.filtered_for_policy(). Empty list
# means no friendly NPCs spawn (legacy / free-play sessions).
var _npc_roster: Array = []
var _npc_root: Node3D = null
var _npc_dialogue_label: Label = null
var _active_npc_id: String = ""

# Wave 3 W3-A6 goal HUD (built lazily in _build_hud).
var _goal_panel: PanelContainer = null
var _goal_label: Label = null
var _goal_bar: ProgressBar = null
var _lives_label: Label = null
var _timer_label: Label = null
var _interaction_prompt_panel: PanelContainer = null
var _interaction_prompt_label: Label = null
var _interaction_prompt_icon: TextureRect = null
var _nearby_world_interactable: Node3D = null
var _interaction_feedback_until: float = 0.0
const SILLY_FART_REACTION_RANGE := 10.0
## A reaction is a tiny social beat, not a crowd of voices competing at once.
## Every nearby NPC gets a turn, while new fart-triggered dialogue waits until
## the current group has finished. Physical gags still happen immediately.
const SILLY_FART_REACTION_GAP_SECONDS := 0.12
## Four distinct nearby reactions are readable; a dozen turns made a small gag
## monopolise the shared narration channel for minutes when TTS was slow.
const SILLY_FART_MAX_QUEUED_REACTIONS := 4
const SILLY_FART_VOICE_TIMEOUT_SECONDS := 3.0
## FIFO of nearby NPC reaction turns. Entries keep a WeakRef so streamed-out
## NPCs can disappear safely before their turn without holding their scene
## nodes alive.
var _npc_reaction_queue: Array[Dictionary] = []
var _npc_reaction_queue_active := false
var _active_npc_reaction_line := ""
var _active_npc_reaction_name := ""
var _active_npc_reaction_audio_started := false
var _active_npc_reaction_audio_finished := false
var _active_npc_reaction_audio_skipped := false
var _npc_reaction_request_sequence := 0
var _active_npc_reaction_request_id := -1

# Parental gates (Adv 2 TB-1, TB-2 fix). Default policy = combat off
# until parent toggles on. Without a policy injection, _spawn_starter_enemies
# + _spawn_next_wave become no-ops.
var _combat_policy: ParentalControlPolicy = null
var _audit_ledger: AuditLedgerPort = null
var _profile_id: String = ""
## Optional outbound bridge to the Tauri shell. When the WS adapter
## is registered (CHOYCE_SHELL_BRIDGE=1 or debug build), session
## lifecycle + publish-state events fan out to the desktop UI.
## Duck-typed via has_method so swapping in a no-op bridge for tests
## stays painless.
var _shell_bridge: Object = null

## VS-022: cosmetic-only player-character customization. Loaded once at
## session start from user://character_customization.json, applied to the
## player rig, and re-saved whenever the panel emits a change signal.
var _customization: CharacterCustomization = null
var _customization_panel: CharacterCustomizationPanel = null

# VS-025: Nutrition and training state
var _nutrition: Nutrition = null
var _training: Training = null
var _body_progression: BodyProgression = null

# VS-025: Nutrition/Training HUD references
var _nutrition_panel: PanelContainer = null
var _protein_bar: ProgressBar = null
var _carbs_bar: ProgressBar = null
var _training_label: Label = null
var _body_level_label: Label = null

## Inject the optional shell bridge. main.gd's _build_default_ports_phase_2
## passes the WebSocketShellBridgeAdapter when registered; otherwise this
## stays null and notify_* calls become no-ops.
func setup_shell_bridge(bridge: Object) -> void:
	_shell_bridge = bridge


func _notify_shell(method: String, args: Array) -> void:
	if _shell_bridge == null:
		return
	if not _shell_bridge.has_method(method):
		return
	_shell_bridge.callv(method, args)


func _ready() -> void:
	_world_renderer = $WorldRenderer
	_player_controller = $PlayerController
	_audio_bus = $AudioEventBus
	_sfx_player = $SFXPlayer
	_effect_spawner = $EffectSpawner
	_screen_feedback = $ScreenFeedbackLayer/ScreenFeedback
	_victory_sequence = $VictorySequence
	_ambient_player = $AmbientPlayer
	_ambient_particles = $AmbientParticles if has_node("AmbientParticles") else null
	
	# VS-021: Initialize vehicle system
	_setup_vehicle_system()

	# Respect reduce-motion accessibility setting for ambient particles
	_update_ambient_particles_from_reduce_motion()

	# Live NPC voice via ElevenLabs. Key from env; absent -> silent no-op.
	# Accept both env spellings (ELEVENLABS_API_KEY and ELEVEN_LABS_API_KEY).
	var eleven_key := OS.get_environment("ELEVENLABS_API_KEY").strip_edges()
	if eleven_key.is_empty():
		eleven_key = OS.get_environment("ELEVEN_LABS_API_KEY").strip_edges()
	var eleven_voice := OS.get_environment("ELEVENLABS_VOICE_ID").strip_edges()
	_npc_voice = ElevenLabsVoicePromptAdapter.new().setup(self, eleven_key, eleven_voice)
	if _npc_voice != null:
		_npc_voice.playback_started.connect(_on_npc_voice_playback_started)
		_npc_voice.playback_finished.connect(_on_npc_voice_playback_finished)
		_npc_voice.playback_skipped.connect(_on_npc_voice_playback_skipped)

	# Ambient music is now driven by AudioBank (play_music called from PlayShell
	# when the world is chosen). The _ambient_player node is kept so the scene
	# tree is unchanged, but we no longer generate procedural noise here.
	# _ambient_player remains silent until AudioBank drives the music bus.

	if _player_controller != null:
		_player_controller.visible = false
		_player_controller.set_process_input(false)
		_player_controller.set_process(false)
		_player_controller.footstep.connect(_on_footstep)
		_player_controller.landed.connect(_on_landed)
		_player_controller.hard_landed.connect(_on_hard_landed)
		_player_controller.jumped.connect(_on_jumped)
		# Adv Y C2 fix — whoosh on swing miss (no enemy in cone).
		if _player_controller.has_signal("swing_missed"):
			_player_controller.swing_missed.connect(_on_player_swing_missed)
		# Adv Y H2 fix — whoosh on EVERY swing (hit or miss)
		if _player_controller.has_signal("attacked"):
			_player_controller.attacked.connect(_on_player_attacked)
		if _player_controller.has_signal("farted"):
			_player_controller.farted.connect(_on_player_farted)

	if _victory_sequence != null:
		_victory_sequence.setup(_effect_spawner, _audio_bus, _screen_feedback, _player_controller)
		_victory_sequence.completed.connect(_on_victory_completed)

## Inject the rules engine. Optional — if not called, rules are inactive
## and the runtime behaves like the legacy collect-or-touch-win path.
## Called by main.gd composition root before start_session.
func setup_rules(runtime: RulesRuntimePort, compiler: RuleCompilerService) -> void:
	_rules_runtime = runtime
	_rule_compiler = compiler
	if _rules_runtime != null and _rules_runtime.has_signal("rules_action"):
		if not _rules_runtime.is_connected("rules_action", _on_rules_action):
			_rules_runtime.connect("rules_action", _on_rules_action)


## Inject parental policy + audit ledger for combat. Adv 2 TB-1 + TB-2
## trust-fixes: combat now opt-in via ParentalControlPolicy.combat_enabled
## and every defeat / wave-spawn is forwarded to AuditLedger for the
## parent dashboard.
func setup_combat_governance(
	policy: ParentalControlPolicy,
	ledger: AuditLedgerPort,
	profile_id: String
) -> void:
	_combat_policy = policy
	_audit_ledger = ledger
	_profile_id = profile_id


## Wave NEXT+1 — Resource-driven combat data. Caller passes typed
## arrays loaded from res://data/{gear,waves}/*.tres. Optional —
## if empty, GameplayRuntime falls back to the legacy inline
## ladder + procedural wave curve. Services are owned here so the
## adapter knows when to apply them; they stay pure RefCounted.
## Wave 3 W3-A/B: Inject the template-pack goal + lose conditions so
## the runtime can produce a real WinOutcome at session end.
## Pass null `goal` for sandbox worlds — the runtime stays open-ended and
## emits an "abandoned" outcome on exit rather than forcing completion.
func setup_goal(
	goal: GameGoal,
	evaluator: EvaluateGoalService,
	lives: int = -1,
	time_limit_sec: int = 0,
	kill_plane_y: float = FALL_KILL_PLANE_Y
) -> void:
	_goal = goal
	_goal_evaluator = evaluator if evaluator != null else EvaluateGoalService.new()
	_lives_remaining = lives
	_time_limit_sec = max(0, time_limit_sec)
	_kill_plane_y = kill_plane_y


## Wave 3 W3-A3: inject the NPC roster for this session.
## Caller (PlayShell) already applied parental policy degradation so
## hostile NPCs become guides when combat is off.
func setup_npcs(npcs: Array) -> void:
	_npc_roster = npcs.duplicate()


func setup_combat_data(
	gear_tiers: Array,        ## Array[GearTierResource]
	wave_configs: Array       ## Array[WaveConfig]
) -> void:
	_gear_tiers = gear_tiers
	_wave_configs = wave_configs
	if _gear_service == null:
		_gear_service = GearProgressionService.new()
	if _wave_service == null:
		_wave_service = WaveDirectorService.new()
	if _combat_service == null:
		_combat_service = CombatService.new()
	if _xp_service == null:
		_xp_service = XpProgressionService.new()


func start_session(world: World, session: Session) -> void:
	_session = session
	_score = 0
	_session_elapsed_sec = 0.0
	_outcome_emitted = false
	_last_goal_check_ratio = 0.0
	_autowin = (OS.has_feature("debug") or OS.has_feature("editor")) \
		and OS.get_environment("CHOYCE_AUTOWIN") == "1"
	var t0 := Time.get_ticks_msec()
	print("[gameplay] start_session: world=%s nodes=%d rules=%d" %
		[world.world_id, world.scene_nodes.size(), world.game_rules.size()])
	# Fan out to the Tauri shell (if registered) so the desktop UI can close
	# its world picker / show an in-session badge. No-op when shell bridge
	# is off (default).
	_notify_shell("notify_session_started", [world.world_id, _profile_id])
	var use_adventure_sky := world.theme in ["adventure", "tropical_fantasy"]
	if not use_adventure_sky:
		_teardown_adventure_sky()
	_world_renderer.render_world(world)
	if use_adventure_sky:
		_setup_adventure_sky()
	_set_legacy_ground_visual_visible(not _world_renderer.has_runtime_terrain_surface())
	_set_legacy_ground_collision_enabled(not _world_renderer.has_runtime_terrain_collision())
	print("[gameplay] render_world done in %d ms" % (Time.get_ticks_msec() - t0))
	_register_world_rules(world)
	var spawn_pos := _world_renderer.get_spawn_position(0)
	# Capsule bottom is 0.1m below the player root (shape centre y=0.8,
	# total height 1.8). Spawn it directly on the floor instead of one metre
	# above it and waiting for a visible physics drop.
	_player_controller.spawn_at(spawn_pos + Vector3(0, 0.10, 0))
	_player_controller.visible = true
	_player_controller.set_process_input(true)
	_player_controller.set_process(true)
	_apply_loaded_customization()
	# Don't capture mouse — kid needs to click ESC button / nav back if anything stalls.
	# Mouse capture made the apparent "hang" feel total since user couldn't escape.
	# FPS-style mouselook — capture cursor so motion is raw delta.
	# Kid presses ESC to release the cursor when they want to click
	# the back button / hotbar. Re-pressing LMB into 3D recaptures.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Hide Main/Layout so the NavBar (top tabs) and other UI don't overlap the
	# HUD overlay added below. Gameplay is full-screen 3D + HUD only.
	# gameplay_runtime is rooted at scene-tree root so it stays visible.
	_set_main_layout_visible(false)

	# VS-025: Initialize nutrition, training, and body progression
	_nutrition = Nutrition.new()
	_training = Training.new()
	_body_progression = BodyProgression.new()

	# Session-init effects + HUD + spawns moved OUT of _set_main_layout_visible
	# (Adv D bug #4 — they were running on every layout toggle including
	# session-end, double-spawning enemies + HUD). Now run once here.
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(_player_controller.global_position)
	for child in _world_renderer.get_children():
		if child is Area3D:
			if not child.body_entered.is_connected(_on_trigger_area_entered):
				child.body_entered.connect(_on_trigger_area_entered.bind(child))
	_build_hud()
	_ensure_session_music()
	_spawn_npcs()
	_spawn_starter_enemies()
	_setup_build_grid()
	_spawn_vehicles()

	# VS-016: Schedule region transition capture after a short delay
	# This gives the player time to move away from spawn point
	var region_timer = Timer.new()
	region_timer.wait_time = 5.0  # 5 seconds after spawn
	region_timer.timeout.connect(func() -> void:
		_trigger_evidence_capture(3)  # REGION_TRANSITION = 3
		region_timer.queue_free()
	)
	add_child(region_timer)
	region_timer.start()

	print("[gameplay] session live in %d ms total" % (Time.get_ticks_msec() - t0))


func _ensure_session_music() -> void:
	# Direct test/demo launch paths bypass PlayShell. Keep a non-lyrical music
	# loop alive there too, so entering the playable world is never silent.
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("play_music"):
		bank.call("play_music", "adventure_island", true)


## VS-021: Vehicle System

func _setup_vehicle_system() -> void:
	# Create destruction tracker if not exists
	if not has_node("DestructionTracker"):
		_destruction_tracker = DestructionTracker.new()
		_destruction_tracker.name = "DestructionTracker"
		_destruction_tracker.configure(self, _world_renderer)
		add_child(_destruction_tracker)
	else:
		_destruction_tracker = $DestructionTracker
		_destruction_tracker.configure(self, _world_renderer)

	# Create vehicle spawner if not exists. Inject sibling dependencies before
	# adding it to the tree so its _ready path can spawn safely in embedded roots.
	if not has_node("VehicleSpawner"):
		_vehicle_spawner = VehicleSpawner.new()
		_vehicle_spawner.name = "VehicleSpawner"
		_vehicle_spawner.configure(self, _player_controller, _destruction_tracker)
		add_child(_vehicle_spawner)
	else:
		_vehicle_spawner = $VehicleSpawner
		_vehicle_spawner.configure(self, _player_controller, _destruction_tracker)


func _spawn_vehicles() -> void:
	if _vehicle_spawner == null:
		_setup_vehicle_system()

	if _vehicle_spawner != null:
		_vehicle_spawner.configure(self, _player_controller, _destruction_tracker)


func _on_vehicle_entered(vehicle: VehicleBase, player: PlayerController) -> void:
	_active_vehicle = vehicle

	# Switch input context (optional - can be handled in vehicle itself)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_vehicle_exited(vehicle: VehicleBase, player: PlayerController, exit_position: Vector3) -> void:
	if _active_vehicle == vehicle:
		_active_vehicle = null

	# Restore input
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_vehicle_destroyed(vehicle: VehicleBase, object: Node3D) -> void:
	# Handle vehicle destruction tracking if needed
	pass


## Hide / restore the InboundMain Layout (NavBar + Body) for fullscreen
## gameplay. Pure visibility toggle — session-init side effects moved
## back into start_session per Adv D code-quality review.
func _set_main_layout_visible(value: bool) -> void:
	var layout := get_node_or_null("/root/Main/Layout")
	if layout != null:
		layout.visible = value
	# VoxelBodyBG is an OPAQUE black full-rect ColorRect on Main's 2D canvas —
	# it draws over the root 3D viewport. Hide it (and the scanline overlay)
	# during gameplay or the kid sees a black screen with only the HUD
	# CanvasLayer visible above it.
	var bg := get_node_or_null("/root/Main/VoxelBodyBG")
	if bg != null:
		bg.visible = value
	var scan := get_node_or_null("/root/Main/VoxelScanlines")
	if scan != null:
		scan.visible = value


## Preserve the legacy StaticBody3D collider beneath the opening, but never
## render it on top of a successfully imported Terrain3D mesh. The old mesh
## and Terrain3D differed by only centimetres, which made the entire ground
## flicker as the depth buffer alternated between them.
func _set_legacy_ground_visual_visible(value: bool) -> void:
	var ground_mesh := get_node_or_null("GroundPlane/GroundMesh") as MeshInstance3D
	if ground_mesh != null:
		ground_mesh.visible = value


## When Terrain3D has built its dynamic heightfield collider, the old flat
## StaticBody3D must stop participating in physics too. Otherwise a player can
## alternate between the two ground surfaces and visibly snap while walking.
func _set_legacy_ground_collision_enabled(value: bool) -> void:
	var ground_collision := get_node_or_null("GroundPlane/GroundCollider") as CollisionShape3D
	if ground_collision != null:
		ground_collision.set_deferred("disabled", not value)


## The installed MIT-licensed Sky3D addon replaces the static procedural sky
## only for the Adventure world. We preserve the established Environment's
## fog, GI, post-processing and restrained palette, while Sky3D supplies
## moving daylight, moonlight and cloud layers that make the large island read
## as an explorable place rather than a frozen test scene.
func _setup_adventure_sky() -> void:
	if _adventure_sky != null and is_instance_valid(_adventure_sky):
		return
	var legacy_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	var environment := Environment.new()
	if legacy_environment != null and legacy_environment.environment != null:
		_adventure_legacy_environment = legacy_environment
		_adventure_legacy_environment_resource = legacy_environment.environment
		environment = legacy_environment.environment.duplicate(true) as Environment
		# A WorldEnvironment uses one active Environment at a time. Keep the
		# baseline node and resource so a later non-adventure session can restore
		# its presentation exactly, but detach it while Sky3D is active.
		legacy_environment.environment = null
	# Sky3D owns the sky material; retain the existing fog, GI and colour grade.
	environment.sky = null
	# Adventure needs a readable daylight grade, not the high-ambient gray wash
	# inherited from the generic runtime scene. Keep surfaces warm but restrained,
	# preserve shadow contrast under trees and reduce horizon haze without showing
	# the world boundary.
	environment.ambient_light_energy = 0.74
	environment.ambient_light_sky_contribution = 0.62
	environment.tonemap_exposure = 0.90
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.88
	environment.adjustment_contrast = 1.12
	environment.fog_density = 0.0019
	environment.fog_light_color = Color(0.58, 0.67, 0.72, 1.0)
	environment.fog_light_energy = 0.46
	environment.fog_aerial_perspective = 0.46
	var sky := SKY3D_SCRIPT.new() as WorldEnvironment
	if sky == null:
		push_warning("Adventure Sky3D could not be created; retaining the static sky")
		return
	sky.name = "AdventureSky3D"
	add_child(sky)
	# Sky3D's custom Environment setter forwards into its SkyDome, which is
	# created during enter-tree initialization. Attach first, then transfer the
	# retained project Environment. Re-run its initializer afterward: our copied
	# Environment deliberately has no static sky, so the addon must install its
	# animated shader material onto that new resource.
	sky.environment = environment
	sky.call("_initialize")
	# SkyDome builds once during Sky3D's initial enter-tree pass. Rebinding the
	# Environment above gives it the retained project settings, but its cached
	# material still points at that first temporary Environment unless we update
	# the addon-owned cache as well. Without this, clouds/time animate an unseen
	# shader while the viewport sky stays frozen.
	var sky_dome := sky.get_node_or_null("SkyDome")
	if sky_dome != null and environment.sky != null:
		sky_dome.set("environment", environment)
		sky_dome.set("sky_material", environment.sky.sky_material)
		sky_dome.set("cumulus_material", environment.sky.sky_material)
	_adventure_sky = sky
	# Set these after the node enters the tree, once Sky3D has created its
	# TimeOfDay/SunLight/MoonLight/SkyDome children.
	sky.set("current_time", 13.25)
	sky.set("minutes_per_day", 24.0)
	sky.set("update_interval", 0.20)
	sky.set("clouds_enabled", true)
	sky.set("cloud_intensity", 0.24)
	sky.set("sun_energy", 1.30)
	sky.set("moon_energy", 0.32)
	sky.set("sky_contribution", 0.62)
	sky.set("night_sky_contribution", 0.56)
	sky.set("tonemap_exposure", 0.90)
	# Existing Environment fog is already tuned to hide the large-world horizon;
	# do not stack Sky3D's fullscreen fog shader over it.
	sky.set("fog_enabled", false)
	for legacy_light_name in ["DirectionalLight3D", "FillLight"]:
		var legacy_light := get_node_or_null(legacy_light_name) as DirectionalLight3D
		if legacy_light != null:
			_adventure_legacy_light_visibility[legacy_light_name] = legacy_light.visible
			legacy_light.visible = false


## Restore the base scene's Environment and light visibility after an Adventure
## session. GameplayRuntime is reused by the launcher, so this cannot rely on
## the scene itself being destroyed between themes.
func _teardown_adventure_sky() -> void:
	if _adventure_sky != null and is_instance_valid(_adventure_sky):
		_adventure_sky.environment = null
		_adventure_sky.queue_free()
	_adventure_sky = null
	if _adventure_legacy_environment != null and is_instance_valid(_adventure_legacy_environment):
		_adventure_legacy_environment.environment = _adventure_legacy_environment_resource
	for legacy_light_name in _adventure_legacy_light_visibility:
		var legacy_light := get_node_or_null(String(legacy_light_name)) as DirectionalLight3D
		if legacy_light != null:
			legacy_light.visible = bool(_adventure_legacy_light_visibility[legacy_light_name])
	_adventure_legacy_light_visibility.clear()
	_adventure_legacy_environment = null
	_adventure_legacy_environment_resource = null


## Minecraft-lite voxel placement. Mounts a BuildGrid as a child of
## the gameplay runtime so blocks are siblings to enemies + world
## scenery. Player gets the grid reference for input handling.
## Seeds a handful of tree + ore_node blocks so the gear loop has
## producers (closes Adv 4 "wood_oak has no producer" finding).
func _setup_build_grid() -> void:
	if _build_grid != null and is_instance_valid(_build_grid):
		_build_grid.clear_all()
		_build_grid.queue_free()
	_build_grid = BuildGrid.new()
	_build_grid.name = "BuildGrid"
	add_child(_build_grid)
	if _player_controller != null and _player_controller.has_method("setup_build_grid"):
		_player_controller.setup_build_grid(_build_grid)
	_build_grid.block_placed.connect(_on_block_placed)
	_build_grid.block_removed.connect(_on_block_removed)
	_build_grid.block_dropped_item.connect(_on_block_dropped_item)
	_build_grid.block_place_failed.connect(_on_block_place_failed)
	# Resources remain available through manual building/crafting. Do not stamp
	# cube-shaped placeholder trees and ore into the opening view: the authored
	# procedural forest already supplies grounded nature at the correct scale.


## Spawn 6 tree_oak + 3 ore_node blocks around the player so mining
## actually produces wood_oak and ore_iron — without these the gear
## ladder is dead code. Positions randomized in 12-18m ring.
func _seed_resource_nodes() -> void:
	if _player_controller == null or _build_grid == null:
		return
	var spawn := _player_controller.global_position
	var rng := _ensure_rng()
	# Trees: cluster of 6 in two rings.
	for i in 6:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(10.0, 18.0)
		var pos := spawn + Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		_build_grid.place_block(_build_grid.world_to_cell(pos), "tree_oak")
	# Iron ore: 3 nodes farther out so kid earns them.
	for i in 3:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(14.0, 22.0)
		var pos := spawn + Vector3(cos(angle) * radius, 0.5, sin(angle) * radius)
		_build_grid.place_block(_build_grid.world_to_cell(pos), "ore_node")


## True only when a non-null ParentalControlPolicy has combat_enabled.
## Defaults to false (no policy = no combat) per CLAUDE.md
## "consent → deny" rule.
func _is_combat_allowed() -> bool:
	if _combat_policy == null:
		return false
	return _combat_policy.combat_enabled


## 0 = waves disabled past the starter pack. Non-zero = hard cap on
## wave count. Driven by ParentalControlPolicy.combat_wave_cap.
func _wave_cap() -> int:
	if _combat_policy == null:
		return 0
	return _combat_policy.combat_wave_cap


## Append a combat-related audit record. Best-effort: silently
## drops if ledger is not wired (e.g. tests / autoplay before
## composition root finishes). Each record carries event_type
## prefixed with "combat_" so the parent dashboard can filter.
func _audit_combat(event_type: String, payload: Dictionary) -> void:
	if _audit_ledger == null:
		return
	var record_id := "%s_%d" % [event_type, Time.get_ticks_msec()]
	var record := AuditRecord.new(
		record_id,
		event_type,
		record_id,
		_profile_id,
		Time.get_datetime_string_from_system(true),
		payload,
		_audit_ledger.last_hash()
	)
	_audit_ledger.append_record(record)


## Weighted-random pick from the wave director's archetype_weights
## dict. Falls back to procedural mix when weights are empty
## (legacy code path). Adv F/H #2 fix.
func _sample_enemy_archetype(weights: Dictionary, rng: RandomNumberGenerator) -> EnemyDefinition:
	if weights.is_empty():
		# Procedural fallback — early-wave default mix.
		var roll := rng.randf()
		if _wave_number >= 3 and roll < 0.3:
			return EnemyDefinition.slime_blue()
		elif roll < 0.7:
			return EnemyDefinition.slime_green()
		return EnemyDefinition.bouncer()
	var total := 0.0
	for w in weights.values():
		total += float(w)
	if total <= 0.0:
		return EnemyDefinition.slime_green()
	var pick := rng.randf_range(0.0, total)
	var accum := 0.0
	for enemy_id in weights.keys():
		accum += float(weights[enemy_id])
		if pick <= accum:
			return _enemy_factory_for(String(enemy_id))
	return EnemyDefinition.slime_green()


func _enemy_factory_for(enemy_id: String) -> EnemyDefinition:
	match enemy_id:
		"slime_blue":
			return EnemyDefinition.slime_blue()
		"bouncer_pink":
			return EnemyDefinition.bouncer()
		"big_slime":
			return EnemyDefinition.big_slime()
		"slime_green", _:
			return EnemyDefinition.slime_green()


## Brief Engine.time_scale dip on impact — Souls/Astro-Bot pattern.
## Defaults to 40ms slow-motion for mob hits, 80ms for boss kills.
## Reverts via SceneTreeTimer so we never leave the world frozen.
## Adv V #1 bug fix: `create_timer` signature is
##   create_timer(time_sec, process_always, process_in_physics, ignore_time_scale)
## We were passing `false` as the 2nd arg thinking it disabled
## time_scale — but the 2nd arg is process_always. Result: previous
## hit-stop lasted 6.6× the intended duration. Now we pass the true
## ignore_time_scale flag (4th arg) so the timer fires in real
## wall-clock seconds regardless of Engine.time_scale.
func _apply_hit_stop(duration_seconds: float) -> void:
	Engine.time_scale = 0.15
	if get_tree() == null:
		return
	var t := get_tree().create_timer(duration_seconds, true, false, true)
	t.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
	)


## Spawn a floating "-7" damage number above the hit position.
## Cheap Label3D billboard + Tween up-and-fade. Skipped silently
## when scene-tree access isn't available (early frames, tear-down).
func _spawn_damage_number(amount: int, position: Vector3, is_boss: bool = false) -> void:
	if get_tree() == null:
		return
	var lbl := Label3D.new()
	lbl.text = "-%d" % amount
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.font_size = 64 if is_boss else 48
	lbl.outline_size = 4
	lbl.modulate = Color(1.0, 0.6, 0.3) if is_boss else Color(1.0, 0.9, 0.5)
	lbl.outline_modulate = Color(0.1, 0.05, 0.0, 1.0)
	add_child(lbl)
	lbl.global_position = position + Vector3(0, 1.4, 0)
	# Adv Y H1 fix: scale-pop animation for juicy hit feedback
	# Start small, slam to overscale, then settle
	lbl.scale = Vector3(0.2, 0.2, 0.2)
	var pop_tween := create_tween()
	var target_scale := 1.8 if is_boss else 1.4
	pop_tween.tween_property(lbl, "scale", Vector3(target_scale, target_scale, target_scale), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(lbl, "scale", Vector3.ONE, 0.10)
	# Original drift-up + fade tween
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "global_position", lbl.global_position + Vector3(0, 1.2, 0), 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.2)
	tw.chain()
	tw.tween_callback(lbl.queue_free)


func _ensure_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


## Mined block dropped an item. Add to inventory + show in HUD.
## Reuses _on_loot_picked_up path so gear auto-upgrade triggers.
func _on_block_dropped_item(drop_item_id: String, position: Vector3) -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("collect", position)
	# Spawn a brief sparkle then add to inventory directly (mining is
	# tactile — no separate orb-grab step). Saves a tween + makes
	# break_block feel instant.
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(position)
	_on_loot_picked_up(drop_item_id, 1)


func _on_block_place_failed(reason: String) -> void:
	if _screen_feedback != null and reason == "capacity":
		_screen_feedback.flash(Color(1.0, 0.4, 0.4), 0.15)


func _on_block_placed(cell: Vector3i, kind_id: String) -> void:
	_set_undo_button_visible(true)
	if _rules_runtime != null:
		_rules_runtime.set_context_value("blocks_placed", _build_grid.block_count())
		_rules_runtime.on_event("place_block", {"kind": kind_id, "cell": cell})


func _on_block_removed(cell: Vector3i, kind_id: String) -> void:
	_set_undo_button_visible(true)
	if _rules_runtime != null:
		_rules_runtime.set_context_value("blocks_placed", _build_grid.block_count())
		_rules_runtime.on_event("break_block", {"kind": kind_id, "cell": cell})


func _on_hud_undo_pressed() -> void:
	if _build_grid != null:
		if _build_grid.undo_last_action():
			_interaction_feedback("Cofnięto!")
			if _audio_bus != null:
				_audio_bus.emit_sfx("collect", _player_controller.global_position if _player_controller != null else Vector3.ZERO)
		else:
			_set_undo_button_visible(false)


func _set_undo_button_visible(should_show: bool) -> void:
	if _undo_button != null and is_instance_valid(_undo_button):
		_undo_button.visible = should_show


## MVP: spawn a small kid-safe enemy pack beyond the opening guide and
## landmarks. The first minute teaches movement and exploration before
## introducing three readable encounters.
##
## Gated by ParentalControlPolicy.combat_enabled (Adv 2 TB-1 fix).
## When combat is off, the runtime stays in the legacy
## collect-and-touch-win mode — no enemies, no waves.
## Wave 3 W3-A4 NPC animation tick: idle bob + chase for hostiles.
## Cheaper than AnimationTree per roster; deterministic so contract
## tests can drive it without a frame loop.
func _tick_npcs(delta: float) -> void:
	if _npc_root == null or not is_instance_valid(_npc_root):
		return
	var t := float(Time.get_ticks_msec()) / 1000.0
	for child in _npc_root.get_children():
		if not (child is StaticBody3D):
			continue
		var body: StaticBody3D = child
		var role: String = String(body.get_meta("npc_role", NPCCharacter.ROLE_GUIDE))
		var base_y: float = float(body.get_meta("npc_base_y", body.global_position.y))
		match role:
			NPCCharacter.ROLE_GUIDE, NPCCharacter.ROLE_VENDOR:
				# Keep feet planted. The former idle bob made static NPCs appear to
				# float above the terrain from the third-person camera.
				body.global_position.y = base_y
				body.rotate_y(delta * 0.6)
			NPCCharacter.ROLE_HOSTILE:
				# Slow chase: lerp toward player on the XZ plane, capped speed.
				if _player_controller == null or not is_instance_valid(_player_controller):
					continue
				var to_player: Vector3 = _player_controller.global_position - body.global_position
				to_player.y = 0.0
				if to_player.length() > 1.6:
					var step: Vector3 = to_player.normalized() * delta * 1.2
					body.global_position += step
				body.look_at(_player_controller.global_position, Vector3.UP)


## Wave 3 W3-A3: spawn one visible NPC per roster entry around the opening
## path. Each gets a collision body + Area3D so walking up triggers the
## greeting bubble. Quaternius rigs provide recognizable silhouettes.
func _spawn_npcs() -> void:
	if _player_controller == null:
		return
	if _npc_roster.is_empty():
		return
	if _npc_root != null and is_instance_valid(_npc_root):
		_npc_root.queue_free()
	_npc_root = Node3D.new()
	_npc_root.name = "NPCs"
	add_child(_npc_root)

	var origin := _player_controller.global_position
	# Spawn markers are stored at the player root, which starts 1m above the
	# floor while physics settles. Static NPCs must use terrain height, not that
	# transient character height, or they remain permanently airborne.
	origin.y = 0.0
	# Put the guide on the opening path and keep optional characters farther
	# out. The first thing the kid sees is a friendly invitation, not a wall of
	# hostile geometry.
	var count: int = _npc_roster.size()
	for i in count:
		var npc_variant: Variant = _npc_roster[i]
		if not (npc_variant is NPCCharacter):
			continue
		var npc: NPCCharacter = npc_variant
		var angle := (TAU / float(count)) * float(i)
		var pos := origin + Vector3(cos(angle) * 10.0, 0.0, sin(angle) * 10.0)
		if i == 0:
			# The guide is visible beside the opening trail, but speaks only when
			# approached. This avoids a reading-heavy dialogue slab obscuring the
			# first scenic frame before the child has chosen to interact.
			pos = origin + Vector3(-3.8, 0.0, -6.0)
		elif npc.visual_id == "npc_pirate":
			# The pirate is a discoverable world character even when parental
			# combat policy degrades their role to guide. Do not let the policy
			# move a full-sized human into the opening tableau.
			pos = origin + Vector3(-120.0, 0.0, 90.0)
		elif npc.visual_id == "npc_parrot":
			# Pestka stays near Olek as a small, grounded companion—not a human
			# at a random point on the NPC ring.
			pos = origin + Vector3(-5.5, 0.0, -6.5)
		_spawn_one_npc(npc, pos)


func _show_intro_npc() -> void:
	if _npc_roster.is_empty():
		return
	for npc_variant in _npc_roster:
		if not (npc_variant is NPCCharacter):
			continue
		var npc: NPCCharacter = npc_variant
		if npc.role != NPCCharacter.ROLE_GUIDE and npc.role != NPCCharacter.ROLE_VENDOR:
			continue
		var greeting := npc.line_for("greeting")
		if greeting.is_empty():
			return
		_active_npc_id = npc.npc_id
		_animate_npc_speech(npc.npc_id, greeting)
		_show_npc_dialogue(npc.name_pl, greeting)
		return


## Spawn a single NPC marker: capsule mesh + collision + Area3D for
## the greeting trigger. Color encodes role so the kid can tell a
## guide (green) from a vendor (gold) from a (degraded) hostile (red).
func _spawn_one_npc(npc: NPCCharacter, pos: Vector3) -> void:
	var root := StaticBody3D.new()
	root.name = "npc_%s" % npc.npc_id
	# A detached node cannot safely receive a global transform. Add it to the
	# NPC root first, then use local position so the authored spawn is stable
	# and smoke runs stay free of !is_inside_tree() errors.
	_npc_root.add_child(root)
	root.position = pos
	root.set_meta("npc_id", npc.npc_id)
	root.set_meta("npc_name_pl", npc.name_pl)
	root.set_meta("greeting_pl", npc.line_for("greeting"))
	root.set_meta("npc_role", npc.role)
	root.set_meta("npc_base_y", pos.y)
	root.add_to_group("npcs")

	# Real rigged, textured character model per role — replaces the old
	# solid-color capsule so kids can tell an NPC apart from a prop. Falls
	# back to a tinted capsule only if the model fails to load.
	var visual := _build_npc_visual(npc)
	root.add_child(visual)
	var facial = visual.find_child("FacialPerformance", true, false)
	if facial != null:
		root.set_meta("facial_performance", facial)

	# The interaction bubble carries the name once the child chooses to talk.
	# Floating labels across the terrain made the world read like an editor.
	var label := Label3D.new()
	label.text = npc.name_pl
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.fixed_size = false
	label.pixel_size = 0.004
	label.font_size = 32
	label.outline_size = 4
	label.modulate = Color(0.92, 0.96, 1.0)
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.position = Vector3(0, 2.05, 0)
	label.visible = false
	root.add_child(label)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.2
	shape.radius = 0.28
	col.shape = shape
	col.position.y = 0.6
	root.add_child(col)

	# Interaction trigger — 1.8m radius so walking up greets the kid
	# without requiring precise alignment.
	var trigger := Area3D.new()
	trigger.name = "GreetTrigger"
	var trig_shape := SphereShape3D.new()
	trig_shape.radius = 1.8
	var trig_col := CollisionShape3D.new()
	trig_col.shape = trig_shape
	trigger.add_child(trig_col)
	trigger.body_entered.connect(_on_npc_trigger_entered.bind(root))
	trigger.body_exited.connect(_on_npc_trigger_exited.bind(root))
	root.add_child(trigger)

## The player already proves these Kenney character scenes at the correct kid
## scale. Reuse them for every NPC instead of depending on a separate rig that
## can silently fail and leave the green capsule fallback in the world.
const _NPC_MODEL_BY_ROLE := {
	"guide": "res://data/models/kenney/toon_characters/Models/GLB format/character-male-b.glb",
	"vendor": "res://data/models/kenney/toon_characters/Models/GLB format/character-male-d.glb",
	"hostile": "res://data/models/kenney/toon_characters/Models/GLB format/character-male-f.glb",
}
const _NPC_IDLE_HINTS := ["Idle", "idle", "CharacterArmature|Idle", "SkeletonArmature|Skeleton_Idle"]


## Build the NPC's visual node: a loaded character model (idle-animated when the
## model has clips), or a tinted capsule fallback if loading fails.
func _build_npc_visual(npc: NPCCharacter) -> Node3D:
	if npc.visual_id == "npc_parrot":
		return _build_parrot_visual()
	var role := npc.role
	var path: String = _NPC_MODEL_BY_ROLE.get(role, _NPC_MODEL_BY_ROLE["guide"])
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		if packed != null:
			var model := packed.instantiate() as Node3D
			if model != null:
				model.scale = Vector3.ONE * 0.92
				# Kenney rigs author facing +Z; face -Z toward the approaching kid.
				model.rotation.y = PI
				if npc.visual_id == "npc_pirate":
					_add_pirate_accessories(model)
				_attach_humanoid_face(model)
				var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if anim != null:
					for hint in _NPC_IDLE_HINTS:
						if anim.has_animation(hint):
							anim.get_animation(hint).loop_mode = Animation.LOOP_LINEAR
							anim.play(hint)
							break
				return model
	# Fallback: tinted capsule (old behavior) so an NPC is never invisible.
	var capsule := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.height = 1.6
	mesh.radius = 0.35
	capsule.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color_for_role(role)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.15
	capsule.material_override = mat
	# Keep the degraded fallback expressive too; the face sits on its forward
	# surface rather than leaving a silent blank marker in a live session.
	var fallback_face = FACIAL_PERFORMANCE_SCRIPT.new()
	fallback_face.name = "FacialPerformance"
	capsule.add_child(fallback_face)
	fallback_face.setup_face(Vector3(0.0, 0.36, 0.0), -0.35, 0.8)
	return capsule


func _attach_humanoid_face(model: Node3D) -> void:
	FACIAL_PERFORMANCE_SCRIPT.attach_kenney_humanoid(model)


func _build_parrot_visual() -> Node3D:
	# No bird model exists in the local approved packs. Build a deliberately
	# readable small parrot silhouette (body, wings, tail, beak and feet) rather
	# than ever degrading this NPC to a human rig again.
	var parrot := Node3D.new()
	parrot.name = "ParrotVisual"
	parrot.scale = Vector3.ONE * 0.62
	var green := _npc_material(Color(0.08, 0.46, 0.22))
	var blue := _npc_material(Color(0.06, 0.23, 0.75))
	var red := _npc_material(Color(0.78, 0.12, 0.08))
	var yellow := _npc_material(Color(1.0, 0.64, 0.08))
	var dark := _npc_material(Color(0.015, 0.02, 0.03))
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.31
	body_mesh.height = 0.64
	body.mesh = body_mesh
	body.material_override = green
	body.position.y = 0.42
	parrot.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.material_override = yellow
	head.position = Vector3(0.0, 0.76, -0.10)
	parrot.add_child(head)
	for x in [-0.27, 0.27]:
		var wing := MeshInstance3D.new()
		var wing_mesh := SphereMesh.new()
		wing_mesh.radius = 0.18
		wing_mesh.height = 0.48
		wing.mesh = wing_mesh
		wing.material_override = blue
		wing.position = Vector3(x, 0.43, 0.03)
		wing.scale = Vector3(0.58, 1.0, 0.36)
		wing.rotation.z = -0.38 * signf(x)
		parrot.add_child(wing)
	var beak := MeshInstance3D.new()
	var beak_mesh := PrismMesh.new()
	beak_mesh.size = Vector3(0.18, 0.13, 0.25)
	beak.mesh = beak_mesh
	beak.material_override = red
	beak.position = Vector3(0.0, 0.76, -0.31)
	beak.rotation.x = PI * 0.5
	parrot.add_child(beak)
	for x in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		eye.mesh = eye_mesh
		eye.material_override = dark
		eye.position = Vector3(x, 0.82, -0.31)
		parrot.add_child(eye)
	var tail := MeshInstance3D.new()
	var tail_mesh := PrismMesh.new()
	tail_mesh.size = Vector3(0.24, 0.54, 0.18)
	tail.mesh = tail_mesh
	tail.material_override = blue
	tail.position = Vector3(0.0, 0.18, 0.28)
	tail.rotation.x = -0.55
	parrot.add_child(tail)
	for x in [-0.09, 0.09]:
		var foot := MeshInstance3D.new()
		var foot_mesh := CylinderMesh.new()
		foot_mesh.top_radius = 0.025
		foot_mesh.bottom_radius = 0.025
		foot_mesh.height = 0.18
		foot.mesh = foot_mesh
		foot.material_override = dark
		foot.position = Vector3(x, 0.08, 0.02)
		parrot.add_child(foot)
	# The parrot keeps its authored eyes while this lightweight mouth layer
	# opens only while its greeting is being spoken.
	var face = FACIAL_PERFORMANCE_SCRIPT.new()
	face.name = "FacialPerformance"
	parrot.add_child(face)
	face.setup_face(Vector3(0.0, 0.76, -0.10), -0.22, 0.72, false, false)
	return parrot


func _npc_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	return mat


func _add_pirate_accessories(model: Node3D) -> void:
	# A compact red bandana and eyepatch turn the shared human rig into a clear
	# pirate silhouette using only runtime primitives; no blob/fallback or new
	# unlicensed character asset is needed.
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.56, 0.08, 0.06)
	red.roughness = 0.72
	var bandana := MeshInstance3D.new()
	var bandana_mesh := CylinderMesh.new()
	bandana_mesh.top_radius = 0.23
	bandana_mesh.bottom_radius = 0.23
	bandana_mesh.height = 0.075
	bandana.mesh = bandana_mesh
	bandana.material_override = red
	bandana.position = Vector3(0.0, 1.42, 0.0)
	model.add_child(bandana)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.025, 0.02, 0.018)
	black.roughness = 0.6
	var patch := MeshInstance3D.new()
	var patch_mesh := SphereMesh.new()
	patch_mesh.radius = 0.075
	patch_mesh.height = 0.035
	patch.mesh = patch_mesh
	patch.material_override = black
	patch.position = Vector3(-0.10, 1.30, -0.22)
	model.add_child(patch)


func _color_for_role(role: String) -> Color:
	match role:
		NPCCharacter.ROLE_GUIDE:
			return Color(0.45, 0.85, 0.55)
		NPCCharacter.ROLE_VENDOR:
			return Color(1.0, 0.85, 0.35)
		NPCCharacter.ROLE_HOSTILE:
			return Color(0.95, 0.4, 0.4)
		_:
			return Color(0.7, 0.85, 1.0)


func _on_npc_trigger_entered(body: Node, npc_root: Node3D) -> void:
	if body != _player_controller:
		return
	if not is_instance_valid(npc_root):
		return
	var name_pl: String = String(npc_root.get_meta("npc_name_pl", ""))
	var greeting: String = String(npc_root.get_meta("greeting_pl", ""))
	if greeting.is_empty():
		return
	_active_npc_id = String(npc_root.get_meta("npc_id", ""))
	_animate_npc_speech(String(npc_root.get_meta("npc_id", "")), greeting)
	_show_npc_dialogue(name_pl, greeting)
	
	# VS-016: Trigger guide interaction evidence capture
	var npc_role = npc_root.get_meta("npc_role", null)
	if npc_role == NPCCharacter.ROLE_GUIDE:
		_trigger_evidence_capture(2)  # GUIDE_INTERACTION = 2


func _on_npc_trigger_exited(body: Node, npc_root: Node3D) -> void:
	if body != _player_controller:
		return
	var leaving_id: String = String(npc_root.get_meta("npc_id", ""))
	if leaving_id == _active_npc_id:
		_hide_npc_dialogue()
		_active_npc_id = ""


## Lazily build a single shared dialogue label at the bottom-center.
## Kept on the HUD CanvasLayer so it sits above 3D geometry.
func _show_npc_dialogue(name_pl: String, line_pl: String, speak_line: bool = true) -> void:
	if _npc_dialogue_label == null:
		_npc_dialogue_label = _build_npc_dialogue_label()
	if _npc_dialogue_label == null:
		return
	_npc_dialogue_label.text = "%s: %s" % [name_pl, line_pl]
	_npc_dialogue_label.visible = true
	# Speak the line aloud (ElevenLabs). Caption stays as the fallback.
	if speak_line and _npc_voice != null:
		_npc_voice.speak(line_pl)


func _speech_duration_for_line(line: String) -> float:
	# Voice assets can vary a little, but this avoids a permanent talk loop and
	# closely covers short kid-facing greetings until audio playback ends.
	return clampf(float(line.length()) / 13.0, 0.75, 4.5)


func _animate_npc_speech(
		npc_id: String,
		line: String,
		emotion: int = FacialPerformance.Emotion.HAPPY
	) -> void:
	if _npc_root == null or npc_id.is_empty():
		return
	for child in _npc_root.get_children():
		if not (child is Node3D) or String(child.get_meta("npc_id", "")) != npc_id:
			continue
		if not child.has_meta("facial_performance"):
			return
		var facial = child.get_meta("facial_performance")
		if facial != null and is_instance_valid(facial):
			facial.speak_for(_speech_duration_for_line(line), emotion)
		return


func _hide_npc_dialogue() -> void:
	if _npc_dialogue_label != null:
		_npc_dialogue_label.visible = false


func _build_npc_dialogue_label() -> Label:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return null
	var panel := PanelContainer.new()
	panel.name = "NPCDialogue"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 280
	panel.offset_top = -160
	panel.offset_right = -280
	panel.offset_bottom = -90
	hud.add_child(panel)
	var label := Label.new()
	label.name = "NPCDialogueLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.visible = false
	panel.add_child(label)
	return label


func _spawn_starter_enemies() -> void:
	if _player_controller == null:
		return
	if not _is_combat_allowed():
		print("[combat] disabled by parental policy — no enemies spawned")
		return
	_audit_combat("combat_session_started", {
		"wave_cap": _wave_cap(),
		"profile_id": _profile_id,
	})
	if _enemy_root != null and is_instance_valid(_enemy_root):
		_enemy_root.queue_free()
	_enemy_root = Node3D.new()
	_enemy_root.name = "Enemies"
	add_child(_enemy_root)

	var spawn := _player_controller.global_position
	var def_a := EnemyDefinition.slime_green()
	var def_b := EnemyDefinition.slime_green()
	var def_c := EnemyDefinition.bouncer()

	# The opening is an invitation to explore, not an instant three-enemy
	# ambush. Encounters live at the cave, deep in the forest, and by the beach;
	# the first view therefore contains a guide and places to walk toward, not
	# placeholder blobs attacking from the yard.
	_spawn_one(def_a, spawn + Vector3(46, 1, -62))
	_spawn_one(def_b, spawn + Vector3(-210, 1, 126))
	_spawn_one(def_c, spawn + Vector3(-118, 1, -92))


func _spawn_one(def: EnemyDefinition, pos: Vector3) -> void:
	var enemy := EnemyController.new()
	enemy.add_to_group("enemies")
	# setup() before add_child so definition is non-null when _ready fires.
	enemy.setup(def, _player_controller)
	# Adv BB P0-7 fix: apply easy mode scaling if enabled
	if _combat_policy != null and _combat_policy.combat_difficulty == ParentalControlPolicy.CombatDifficulty.EASY:
		enemy.health.max_hp = int(enemy.health.max_hp * 0.6)
		enemy.definition.contact_damage = int(enemy.definition.contact_damage * 0.5)
	enemy.defeated.connect(_on_enemy_defeated)
	# Hook hit feedback: floating "-N" damage label + short shake +
	# percussive SFX on every landed swing. (Adv N/M feel overhaul.)
	enemy.damaged_with_amount.connect(_on_enemy_damaged)
	_enemy_root.add_child(enemy)
	enemy.global_position = pos


## Adv Y C2 fix — fire whoosh SFX when a swing hits empty air.
## Keeps the air swing audible so a 7yo never thinks the button
## broke.
func _on_player_swing_missed(attack_origin: Vector3) -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("swing_whoosh", attack_origin)


## Adv Y H2 fix: whoosh SFX on every swing (hit or miss)
## Adv Y H5: track attack style for phase-aware feedback
func _on_player_attacked(damage: int, hit_position: Vector3) -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("swing_whoosh", hit_position)
	# Cache attack style for use in _on_enemy_damaged
	if _player_controller != null and _player_controller.has_method("get_last_attack_style"):
		_last_attack_style = _player_controller.get_last_attack_style()


func _on_enemy_damaged(amount: int, position: Vector3) -> void:
	# Cheap heuristic: amount ≥ 8 → likely against a boss (bigger HP
	# bar). Future: pass enemy_id through.
	var is_boss := amount >= 8
	_spawn_damage_number(amount, position, is_boss)
	# Adv Y H5 fix: phase-aware feedback (kicks > punches)
	# Kicks get bigger shake, longer hit-stop, and 2x knockback
	var is_kick := _last_attack_style == "kick"
	var hit_stop_duration := 0.06 if is_boss else (0.06 if is_kick else 0.035)
	var shake_amplitude := 7.0 if is_kick else 6.0
	# Adv Y C1 fix: hit-stop fires on EVERY hit-connect (35ms mob /
	# 60ms boss), not only on kill. This is the single biggest "yes I
	# hit it" signal — Mick Hofman / J.W. Nijman pattern.
	_apply_hit_stop(hit_stop_duration)
	
	# VS-016: Trigger combat evidence capture on first hit
	_trigger_evidence_capture(4)  # COMBAT = 4
	# Adv Y C4 fix: per-hit shake is now LOUDER than defeat shake
	# (because it fires every swing, defeat is the rarer payoff).
	# Direction = away from player toward hit point so the camera
	# kicks toward the impact side (Doom/Halo nudge pattern).
	if _screen_feedback != null:
		var dir_x := 0.0
		if _player_controller != null:
			dir_x = signf(position.x - _player_controller.global_position.x)
		var dir := Vector2(dir_x, -0.4)
		if _screen_feedback.has_method("shake_directional"):
			_screen_feedback.shake_directional(shake_amplitude, 0.08, dir)
		elif _screen_feedback.has_method("shake"):
			_screen_feedback.shake(shake_amplitude, 0.08)
	# Physical impact SFX follows the actual animation phase: fist strikes use
	# a dry punch, kicks use a lower body-impact thud.
	# Adv Y C2 fix: also play enemy_grunt on hit for audio feedback
	if _audio_bus != null:
		var impact_sfx := "kick_impact" if is_kick else "punch_thud"
		_audio_bus.emit_sfx(impact_sfx, position)
		_audio_bus.emit_sfx("enemy_grunt", position)


func _on_enemy_defeated(enemy_id: String, position: Vector3, loot: Array) -> void:
	print("[combat] defeated %s at %s loot=%s" % [enemy_id, position, loot])
	# Feel overhaul (Adv M+N #11/#12): per-defeat SFX + screen shake
	# + hit-stop. Adv Y C4: defeat shake is now SOFTER per-hit
	# because per-hit shake is the loud one now. Hit-stop on kill
	# stays the bigger of the two (0.08 boss / 0.04 mob).
	var is_boss := enemy_id == "big_slime"
	if _screen_feedback != null and _screen_feedback.has_method("shake"):
		_screen_feedback.shake(7.0 if is_boss else 5.0, 0.10)
	if _audio_bus != null:
		_audio_bus.emit_sfx("punch_thud", position)
	_apply_hit_stop(0.08 if is_boss else 0.04)
	# Grant XP first so audit + HUD reflect the new level if a level-up fires.
	if _xp_service != null:
		_grant_xp(_xp_service.xp_for_kill(enemy_id))
	_audit_combat("combat_enemy_defeated", {
		"enemy_id": enemy_id,
		"wave_number": _wave_number,
		"loot_items": loot.size(),
		"xp_level": _xp_level,
		"profile_id": _profile_id,
	})
	if _audio_bus != null:
		_audio_bus.emit_sfx("collect", position)
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(position)
	if _rules_runtime != null:
		_rules_runtime.on_event("defeat_%s" % enemy_id, {"enemy_id": enemy_id})

	# Physical loot drops — spawn LootPickup orbs that the kid walks
	# into. Loot table entries may stack; we drop one pickup per
	# stack so the kid sees multiple orbs poof out.
	if _loot_root == null or not is_instance_valid(_loot_root):
		_loot_root = Node3D.new()
		_loot_root.name = "Loot"
		add_child(_loot_root)
	var index := 0
	for drop in loot:
		if not (drop is Dictionary):
			continue
		var item := String((drop as Dictionary).get("item_id", ""))
		var qty := int((drop as Dictionary).get("quantity", 0))
		if item == "" or qty <= 0:
			continue
		var angle := index * (TAU / 4.0)
		var offset := Vector3(cos(angle) * 0.8, 0.5, sin(angle) * 0.8)
		var pickup := LootPickup.new()
		pickup.setup(item, qty, _player_controller)
		pickup.picked_up.connect(_on_loot_picked_up)
		_loot_root.add_child(pickup)
		pickup.global_position = position + offset
		index += 1

	# Default scoring fallback (works even without compiled rules).
	_score += 5
	if _score_label != null:
		_score_label.text = str(_score)


func _on_loot_picked_up(item_id: String, quantity: int) -> void:
	if _audio_bus != null and _player_controller != null:
		_audio_bus.emit_sfx("collect", _player_controller.global_position)
	# Update inventory via rules-runtime context (single source of truth).
	if _rules_runtime != null:
		var inv: Variant = _rules_runtime.get_context_value("inventory")
		var inv_dict: Dictionary = inv if inv is Dictionary else {}
		inv_dict[item_id] = int(inv_dict.get(item_id, 0)) + quantity
		_rules_runtime.set_context_value("inventory", inv_dict)
		_rules_runtime.on_event("inventory_changed", {"item": item_id})
		_rules_runtime.on_event("collect_%s" % item_id, {})
		_refresh_inventory_panel(inv_dict)
		_try_auto_upgrade_weapon(inv_dict)
	else:
		# Fallback when rules runtime not wired — local inventory map.
		var inv_dict: Dictionary = {}
		inv_dict[item_id] = quantity
		_refresh_inventory_panel(inv_dict)


func _refresh_inventory_panel(inv: Dictionary) -> void:
	if _inventory_panel == null:
		return
	for item_id in inv.keys():
		var count := int(inv[item_id])
		var label: Label = _inventory_labels.get(item_id, null)
		if label == null:
			var slot := Control.new()
			slot.name = "Inventory_%s" % item_id
			slot.custom_minimum_size = Vector2(52, 52)
			slot.tooltip_text = _pretty_item_name(item_id)
			var icon := TextureRect.new()
			icon.texture = _inventory_texture_for(item_id)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 4
			icon.offset_top = 4
			icon.offset_right = -4
			icon.offset_bottom = -4
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
			label = Label.new()
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
			label.add_theme_constant_override("shadow_offset_x", 2)
			label.add_theme_constant_override("shadow_offset_y", 2)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.offset_left = 4
			label.offset_top = 4
			label.offset_right = -4
			label.offset_bottom = -4
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(label)
			_inventory_panel.add_child(slot)
			_inventory_labels[item_id] = label
		label.text = "×%d" % count


func _pretty_item_name(item_id: String) -> String:
	match item_id:
		"slime_gel": return "Galaretka"
		"coin": return "Moneta"
		"spring_coil": return "Sprężynka"
		"ore_iron": return "Żelazo"
		"wood_oak": return "Drewno"
		"star": return "Gwiazdka"
		_:
			return item_id.capitalize()


func _inventory_texture_for(item_id: String) -> Texture2D:
	match item_id:
		"wood_oak", "wood": return HUD_ICON_WOOD
		"ore_iron", "stone", "brick_red": return HUD_ICON_STONE
		"meal", "apple": return HUD_ICON_WORKBENCH
		"slime_gel": return HUD_ICON_GRASS
		_: return HUD_ICON_HAMMER


## Gear grinding loop: when kid has the materials, auto-upgrade weapon
## to the next tier and consume the inputs. Now routed through
## GearProgressionService (Adv 1 H1 — pure RefCounted, no Godot leak).
## Falls back to the legacy inline `_weapon_tiers` Array when no
## GearTierResource files are loaded so existing kid runs don't break.
func _try_auto_upgrade_weapon(inv: Dictionary) -> void:
	# Service-driven path — Resource-backed tier ladder.
	if not _gear_tiers.is_empty() and _gear_service != null:
		var next_idx := _gear_service.next_eligible_tier(
			_gear_tiers, inv, _player_xp_level(), _current_weapon_index
		)
		if next_idx < 0:
			return
		var tier_res: GearTierResource = _gear_tiers[next_idx]
		if not _gear_service.consume_materials(inv, tier_res.recipe):
			return
		_apply_tier(next_idx, tier_res.display_name, tier_res.weapon_damage, inv)
		return

	# Legacy inline ladder — kept until res://data/gear/*.tres exists
	# and parents have authored their preferred curve. Slated for
	# deletion once data files ship.
	if _current_weapon_index >= _weapon_tiers.size() - 1:
		return
	var next_tier: Dictionary = _weapon_tiers[_current_weapon_index + 1]
	var needs: Dictionary = next_tier.get("needs", {})
	for k in needs.keys():
		if int(inv.get(k, 0)) < int(needs[k]):
			return
	for k in needs.keys():
		inv[k] = int(inv.get(k, 0)) - int(needs[k])
	_apply_tier(_current_weapon_index + 1, String(next_tier.get("label", "")),
		int(next_tier.get("damage", 4)), inv)


func _apply_tier(index: int, label: String, damage: int, inv: Dictionary) -> void:
	if _rules_runtime != null:
		_rules_runtime.set_context_value("inventory", inv)
	_current_weapon_index = index
	if _player_controller != null and _player_controller.has_method("equip_weapon_damage"):
		_player_controller.equip_weapon_damage(damage)
	if _player_controller != null and _player_controller.has_method("set_weapon_visual"):
		_player_controller.set_weapon_visual(String(_weapon_tiers[index].get("id", "")))
	if _weapon_label != null:
		_weapon_label.text = "%s" % label
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 0.95, 0.4), 0.3)
	if _effect_spawner != null and _player_controller != null:
		_effect_spawner.spawn_sparkle_burst(_player_controller.global_position)
	print("[gear] upgraded to %s (%d dmg)" % [label, damage])
	_refresh_inventory_panel(inv)
	# Refresh hotbar slot 0 so the weapon icon reflects new tier
	# immediately. Was Adv N partial-fix — slot 0 stayed stale until
	# next hotbar_changed event (kid pressing 1-5 keys).
	_rebuild_hotbar_panel(0)


func _player_xp_level() -> int:
	return _xp_level


## Award XP and re-render the XP bar. Multi-level skips handled by
## XpProgressionService. Level-up triggers a brief flash + sparkle
## burst — the dopamine feedback Adv 4 ROI 2 flagged as missing.
func _grant_xp(amount: int) -> void:
	if _xp_service == null:
		_xp_service = XpProgressionService.new()
	var before := _xp_level
	var result := _xp_service.apply_gain(_xp_level, _xp_current, amount)
	_xp_level = int(result.get("level", _xp_level))
	_xp_current = int(result.get("xp", _xp_current))
	_refresh_xp_hud()
	if _xp_level > before:
		_on_level_up(before, _xp_level)


func _refresh_xp_hud() -> void:
	if _xp_bar == null or _xp_service == null:
		return
	var needed := _xp_service.xp_required(_xp_level)
	_xp_bar.max_value = maxi(needed, 1)
	_xp_bar.value = _xp_current
	if _xp_label != null:
		_xp_label.text = "Lv %d  •  %d/%d XP" % [_xp_level, _xp_current, needed]


## VS-025: Refresh nutrition and training HUD
func _refresh_nutrition_hud() -> void:
	if _protein_bar == null or _carbs_bar == null or _nutrition == null:
		return
	_protein_bar.value = _nutrition.protein_level
	_carbs_bar.value = _nutrition.carbohydrate_level
	if _training_label != null and _training != null:
		_training_label.text = "Trening: %d sesji" % _training.total_sessions()
	if _body_level_label != null and _body_progression != null:
		_body_level_label.text = "Forma: %s" % _body_progression.get_body_level_name()


## Kid-friendly level-up: flash + sparkle + audio cue + STAT BOOST
## (Adv F/H #5 fix — was purely cosmetic, kid saw "Lv 3" but felt
## nothing). Now: +5 max_hp per level (cap +50) and +1 weapon
## damage every 3rd level. Lets gear progression compound through
## play even when the kid hasn't crafted up the gear ladder yet.
func _on_level_up(before: int, after: int) -> void:
	print("[xp] level up: %d → %d" % [before, after])
	_audit_combat("combat_level_up", {
		"from_level": before,
		"to_level": after,
		"profile_id": _profile_id,
	})
	# Apply stat boost per level gained (multi-level skip-safe).
	if _player_controller != null and is_instance_valid(_player_controller):
		for lvl in range(before + 1, after + 1):
			# +5 HP each level, capped so kid doesn't snowball
			if _player_controller.has_method("get_health"):
				var h: HealthState = _player_controller.get_health()
				if h != null and h.max_hp < PlayerController.PLAYER_MAX_HP + 50:
					h.max_hp += 5
					h.current_hp = mini(h.current_hp + 5, h.max_hp)
					_player_controller.hp_changed.emit(h.current_hp, h.max_hp)
			# +1 weapon dmg every 3rd level
			if (lvl % 3) == 0 and _player_controller.has_method("equip_weapon_damage"):
				var current_dmg := _current_weapon_damage()
				_player_controller.equip_weapon_damage(current_dmg + 1)
				print("[xp] +1 base damage at level %d → %d" % [lvl, current_dmg + 1])
	if _screen_feedback != null:
		_screen_feedback.flash(Color(0.5, 1.0, 0.6), 0.35)
	if _effect_spawner != null and _player_controller != null:
		_effect_spawner.spawn_sparkle_burst(_player_controller.global_position)
	if _audio_bus != null and _player_controller != null:
		_audio_bus.emit_sfx("collect", _player_controller.global_position)


## Pretty PL label for the kid's current weapon. Used by the hotbar
## slot-0 rebuild + the stats-panel weapon label, so they stay in
## sync as the kid upgrades.
func _current_weapon_label() -> String:
	if _current_weapon_index >= 0 and _current_weapon_index < _weapon_tiers.size():
		var tier: Dictionary = _weapon_tiers[_current_weapon_index]
		return String(tier.get("label", "Pięść"))
	return "Pięść"


func _current_weapon_damage() -> int:
	if _player_controller == null:
		return 4
	if "_equipped_weapon_damage" in _player_controller:
		return int(_player_controller._equipped_weapon_damage)
	return 4


func _rebuild_hotbar_panel(active_slot: int) -> void:
	if _hotbar_panel == null:
		return
	for child in _hotbar_panel.get_children():
		child.queue_free()
	# Slot 0 is the tool, slots 1-4 are build materials. The previous version
	# painted each slot with the bundled Kenney Blue/Yellow placeholder
	# textures, which read as debug UI rather than a kid game. Reuse the same
	# translucent panel system as the rest of the HUD; the active slot is
	# marked by a brighter accent border, the icon stays as a real kit
	# thumbnail.
	var catalog := BlockKind.default_catalog()
	var slots: Array = []
	slots.append({"id": "weapon", "name": _current_weapon_label()})
	for i in mini(catalog.size(), 4):
		var kind: BlockKind = catalog[i]
		slots.append({"id": kind.block_id, "name": kind.display_name})
	for i in slots.size():
		var entry: Dictionary = slots[i]
		var slot := Control.new()
		slot.name = "HotbarSlot_%d" % i
		slot.custom_minimum_size = Vector2(82, 82)
		slot.tooltip_text = String(entry["name"])
		var panel := PanelContainer.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		var accent := Color(0.78, 0.62, 0.32) if i == active_slot else Color(0.45, 0.55, 0.70)
		panel.add_theme_stylebox_override("panel", _hud_panel_style(accent, 0.92 if i == active_slot else 0.78))
		slot.add_child(panel)
		var icon := TextureRect.new()
		icon.texture = _hotbar_texture_for(String(entry["id"]), i)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 14
		icon.offset_top = 14
		icon.offset_right = -14
		icon.offset_bottom = -14
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		# Tiny numeric hint is retained for older children/keyboard use; all
		# gameplay meaning comes from the picture rather than a word label.
		var num_label := Label.new()
		num_label.text = "%d" % (i + 1)
		num_label.add_theme_font_size_override("font_size", 13)
		num_label.add_theme_color_override("font_color", Color.WHITE)
		num_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		num_label.add_theme_constant_override("shadow_offset_x", 2)
		num_label.add_theme_constant_override("shadow_offset_y", 2)
		num_label.position = Vector2(10, 8)
		num_label.size = Vector2(16, 18)
		num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(num_label)
		_hotbar_panel.add_child(slot)


## Emoji icon for a hotbar slot. Slot 0 is the weapon (icon follows the
## current tier: fist -> stick -> sword -> epic sword); slots 1-4 are blocks.
func _hotbar_icon_for(entry_id: String, slot_index: int) -> String:
	if slot_index == 0 or entry_id == "weapon":
		match _weapon_tiers[_current_weapon_index].get("id", "fist"):
			"stick": return "WOOD"
			"sword_iron": return "SWORD"
			"sword_epic": return "EPIC"
			_: return "FIST"
	match entry_id:
		"grass": return "GRASS"
		"dirt": return "DIRT"
		"wood_oak", "wood": return "WOOD"
		"stone", "brick_red", "brick": return "STONE"
		"sand": return "SAND"
		_: return "BUILD"


func _hotbar_texture_for(entry_id: String, slot_index: int) -> Texture2D:
	if slot_index == 0 or entry_id == "weapon":
		return HUD_ICON_AXE
	match entry_id:
		"grass", "dirt", "sand": return HUD_ICON_GRASS
		"wood_oak", "wood": return HUD_ICON_WOOD
		"stone", "brick_red", "brick": return HUD_ICON_STONE
		_: return HUD_ICON_HAMMER


func _on_hotbar_changed(active_slot: int, _block_id: String) -> void:
	_rebuild_hotbar_panel(active_slot)


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	if _hp_bar == null:
		return
	if _stats_panel != null:
		# Do not occupy the opening with an unexplained empty dashboard. Health
		# appears when it matters—after an encounter has actually hurt the child.
		_stats_panel.visible = current < max_hp
	_hp_bar.max_value = max_hp
	_hp_bar.value = current
	# Adv W #3 — color ramp + low-HP panic cue. Default ProgressBar
	# gives no visual signal at low HP; kid keeps swinging into a
	# slime not realizing they're 5 HP from defeat. Color blindness
	# fallback: also use saturation drop at low HP (red ≈ desaturated
	# gray-red so red-green CB still sees a contrast shift).
	var ratio: float = float(current) / float(maxi(max_hp, 1))
	if ratio < 0.3:
		_hp_bar.modulate = Color(1.0, 0.4, 0.4)
	elif ratio < 0.6:
		_hp_bar.modulate = Color(1.0, 0.85, 0.4)
	else:
		_hp_bar.modulate = Color(0.7, 1.0, 0.7)


func _on_player_defeated() -> void:
	# Kid-safe defeat — soft fade + respawn at spawn point, no game-over.
	print("[combat] player defeated — soft respawn")
	_audit_combat("combat_player_defeated", {
		"wave_number": _wave_number,
		"profile_id": _profile_id,
	})
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 0.85, 0.85), 0.5)
	if _world_renderer != null and _player_controller != null:
		var spawn_pos := _world_renderer.get_spawn_position(0)
		_player_controller.spawn_at(spawn_pos + Vector3(0, 0.10, 0))
		if _player_controller.has_method("get_health"):
			var h: HealthState = _player_controller.get_health()
			if h != null:
				h.current_hp = h.max_hp
				h.is_alive = true
				_player_controller.hp_changed.emit(h.current_hp, h.max_hp)


## Image-first shell controls keep the always-visible HUD understandable before
## a child can read. Tooltips remain for parents, keyboard users, and assistive
## technology; the visual affordance itself does not depend on words.
func _make_hud_icon_button(name: String, icon: Texture2D, tooltip: String, accent: Color) -> Button:
	var button := Button.new()
	button.name = name
	button.text = ""
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(64, 64)
	button.icon = icon
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _hud_panel_style(accent, 0.90))
	button.add_theme_stylebox_override("hover", _hud_panel_style(accent.lightened(0.16), 0.98))
	button.add_theme_stylebox_override("pressed", _hud_panel_style(accent.darkened(0.18), 0.98))
	button.add_theme_stylebox_override("focus", _hud_panel_style(Color(1.0, 0.94, 0.48), 0.98))
	return button


## Kid-facing HUD: image-led controls and a small contextual prompt so a 5-7
## year-old sees what to do after world load without an on-screen legend.
func _build_hud() -> void:
	if has_node("HUD"):
		return
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 5
	add_child(hud)

	# Keep the first scenic frame free of a row of unexplained editor buttons.
	# A single compact menu preserves the two infrequent actions (customization
	# and safe return) without competing with the character, guide or world.
	var menu := MenuButton.new()
	menu.name = "AdventureMenuBtn"
	menu.tooltip_text = "Menu gry"
	menu.icon = HUD_ICON_RETURN
	menu.expand_icon = true
	menu.focus_mode = Control.FOCUS_ALL
	menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu.offset_left = 28
	menu.offset_top = 28
	menu.offset_right = 80
	menu.offset_bottom = 80
	menu.add_theme_stylebox_override("normal", _hud_panel_style(Color(0.38, 0.62, 0.76), 0.82))
	menu.add_theme_stylebox_override("hover", _hud_panel_style(Color(0.50, 0.74, 0.88), 0.96))
	menu.add_theme_stylebox_override("pressed", _hud_panel_style(Color(0.24, 0.46, 0.62), 0.96))
	menu.add_theme_stylebox_override("focus", _hud_panel_style(Color(1.0, 0.86, 0.38), 0.96))
	var menu_popup := menu.get_popup()
	menu_popup.add_icon_item(HUD_ICON_STAR, "Wygląd postaci", 1)
	menu_popup.add_icon_item(HUD_ICON_RETURN, "Wróć do menu", 2)
	menu_popup.id_pressed.connect(func(id: int) -> void:
		if id == 1:
			_on_customize_pressed()
		elif id == 2:
			end_session())
	hud.add_child(menu)

	var undo_btn := _make_hud_icon_button("UndoBtn", HUD_ICON_UNDO, "Cofnij ostatnią zmianę", Color(0.92, 0.72, 0.30))
	undo_btn.name = "UndoBtn"
	undo_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	undo_btn.offset_left = 88
	undo_btn.offset_top = 28
	undo_btn.offset_right = 140
	undo_btn.offset_bottom = 80
	undo_btn.pressed.connect(_on_hud_undo_pressed)
	undo_btn.visible = false
	_undo_button = undo_btn
	hud.add_child(undo_btn)

	# VS-025: Nutrition/Training panel (bottom-right)
	_nutrition_panel = PanelContainer.new()
	_nutrition_panel.name = "NutritionPanel"
	_nutrition_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_nutrition_panel.offset_left = -280
	_nutrition_panel.offset_top = -200
	_nutrition_panel.offset_right = -16
	_nutrition_panel.offset_bottom = -16
	_nutrition_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.45, 0.85, 0.55), 0.84))
	
	var nutrition_vbox := VBoxContainer.new()
	nutrition_vbox.add_theme_constant_override("separation", 4)
	_nutrition_panel.add_child(nutrition_vbox)
	
	# Nutrition bars
	var nutrition_label := Label.new()
	nutrition_label.text = "Odżywianie"
	nutrition_label.add_theme_font_size_override("font_size", 18)
	nutrition_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	nutrition_vbox.add_child(nutrition_label)
	
	_protein_bar = ProgressBar.new()
	_protein_bar.name = "ProteinBar"
	_protein_bar.min_value = 0
	_protein_bar.max_value = 100
	_protein_bar.value = 0
	_protein_bar.custom_minimum_size = Vector2(140, 16)
	_protein_bar.add_theme_color_override("font_color", Color.WHITE)
	nutrition_vbox.add_child(_protein_bar)
	
	_carbs_bar = ProgressBar.new()
	_carbs_bar.name = "CarbsBar"
	_carbs_bar.min_value = 0
	_carbs_bar.max_value = 100
	_carbs_bar.value = 0
	_carbs_bar.custom_minimum_size = Vector2(140, 16)
	_carbs_bar.add_theme_color_override("font_color", Color.WHITE)
	nutrition_vbox.add_child(_carbs_bar)
	
	# Training and body level
	_training_label = Label.new()
	_training_label.name = "TrainingLabel"
	_training_label.text = "Trening: 0 sesji"
	_training_label.add_theme_font_size_override("font_size", 16)
	_training_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	nutrition_vbox.add_child(_training_label)
	
	_body_level_label = Label.new()
	_body_level_label.name = "BodyLevelLabel"
	_body_level_label.text = "Forma: Podstawowy"
	_body_level_label.add_theme_font_size_override("font_size", 16)
	_body_level_label.add_theme_color_override("font_color", Color(0.96, 0.93, 1.0))
	nutrition_vbox.add_child(_body_level_label)
	
	hud.add_child(_nutrition_panel)
	# Nutrition and training are secondary sandbox systems. Keeping their
	# developer-style text card permanently visible breaks the image-first HUD
	# and competes with the world. State still updates in the background and can
	# later be surfaced from the inventory/character screen.
	_nutrition_panel.visible = false

	# HP bar + score panel (top-right). 7yo combat HUD.
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	_stats_panel = stats_panel
	stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats_panel.offset_left = -240
	stats_panel.offset_top = 32
	stats_panel.offset_right = -32
	stats_panel.offset_bottom = 132
	stats_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.32, 0.72, 0.92), 0.84))
	stats_panel.visible = false
	hud.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_vbox)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(180, 24)
	_hp_bar.add_theme_color_override("font_color", Color.WHITE)
	stats_vbox.add_child(_hp_bar)

	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_END
	stats_vbox.add_child(score_row)
	var score_icon := TextureRect.new()
	score_icon.texture = HUD_ICON_STAR
	score_icon.custom_minimum_size = Vector2(26, 26)
	score_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	score_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	score_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_row.add_child(score_icon)
	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.text = "0"
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	_score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_score_label.add_theme_constant_override("shadow_offset_x", 2)
	_score_label.add_theme_constant_override("shadow_offset_y", 2)
	score_row.add_child(_score_label)

	var weapon_icon := TextureRect.new()
	weapon_icon.texture = HUD_ICON_AXE
	weapon_icon.custom_minimum_size = Vector2(34, 34)
	weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_vbox.add_child(weapon_icon)
	_weapon_label = Label.new()
	_weapon_label.name = "WeaponLabel"
	_weapon_label.text = "Pięść"
	_weapon_label.add_theme_font_size_override("font_size", 18)
	_weapon_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_weapon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_weapon_label.add_theme_constant_override("shadow_offset_x", 2)
	_weapon_label.add_theme_constant_override("shadow_offset_y", 2)
	_weapon_label.visible = false
	stats_vbox.add_child(_weapon_label)

	# XP bar — Adv 4 ROI 2 dopamine fix. Sits below weapon label.
	_xp_bar = ProgressBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.min_value = 0
	_xp_bar.max_value = 4
	_xp_bar.value = 0
	_xp_bar.custom_minimum_size = Vector2(180, 18)
	_xp_bar.modulate = Color(0.6, 1.0, 0.7)
	stats_vbox.add_child(_xp_bar)
	_xp_label = Label.new()
	_xp_label.name = "XpLabel"
	_xp_label.text = "Lv 0  •  0/4 XP"
	_xp_label.add_theme_font_size_override("font_size", 16)
	_xp_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_xp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_xp_label.add_theme_constant_override("shadow_offset_x", 2)
	_xp_label.add_theme_constant_override("shadow_offset_y", 2)
	_xp_label.visible = false
	stats_vbox.add_child(_xp_label)
	_refresh_xp_hud()

	# Pictorial backpack — bottom-left. Items appear as familiar resource/tool
	# thumbnails with a small numeric badge instead of a reading-heavy list.
	_inventory_panel = HBoxContainer.new()
	_inventory_panel.name = "Inventory"
	_inventory_panel.add_theme_constant_override("separation", 6)
	_inventory_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_inventory_panel.offset_left = 32
	_inventory_panel.offset_top = -176
	_inventory_panel.offset_right = 300
	_inventory_panel.offset_bottom = -110
	hud.add_child(_inventory_panel)

	# Wave 3 W3-A6: goal HUD (top-center). Visible only when setup_goal()
	# has been called with a non-null GameGoal — otherwise the panel
	# stays hidden so free-play worlds don't see an empty bar.
	_goal_panel = PanelContainer.new()
	_goal_panel.name = "GoalPanel"
	_goal_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_goal_panel.offset_left = 220
	_goal_panel.offset_top = 24
	_goal_panel.offset_right = -260
	_goal_panel.offset_bottom = 132
	_goal_panel.visible = (_goal != null)
	hud.add_child(_goal_panel)
	var goal_vbox := VBoxContainer.new()
	goal_vbox.add_theme_constant_override("separation", 4)
	_goal_panel.add_child(goal_vbox)
	_goal_label = Label.new()
	_goal_label.name = "GoalLabel"
	_goal_label.text = _goal.label if _goal != null else ""
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.add_theme_font_size_override("font_size", 24)
	_goal_label.add_theme_color_override("font_color", Color.WHITE)
	_goal_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_goal_label.add_theme_constant_override("shadow_offset_x", 2)
	_goal_label.add_theme_constant_override("shadow_offset_y", 2)
	goal_vbox.add_child(_goal_label)
	_goal_bar = ProgressBar.new()
	_goal_bar.name = "GoalBar"
	_goal_bar.min_value = 0.0
	_goal_bar.max_value = 1.0
	_goal_bar.step = 0.01
	_goal_bar.value = 0.0
	_goal_bar.show_percentage = false
	_goal_bar.custom_minimum_size = Vector2(260, 18)
	_goal_bar.modulate = Color(1.0, 0.85, 0.35)
	goal_vbox.add_child(_goal_bar)
	var meta_hbox := HBoxContainer.new()
	meta_hbox.add_theme_constant_override("separation", 18)
	meta_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	goal_vbox.add_child(meta_hbox)
	_lives_label = Label.new()
	_lives_label.name = "LivesLabel"
	_lives_label.text = _format_lives_text()
	_lives_label.add_theme_font_size_override("font_size", 18)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	_lives_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_lives_label.add_theme_constant_override("shadow_offset_x", 2)
	_lives_label.add_theme_constant_override("shadow_offset_y", 2)
	meta_hbox.add_child(_lives_label)
	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.text = _format_timer_text()
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_timer_label.add_theme_constant_override("shadow_offset_x", 2)
	_timer_label.add_theme_constant_override("shadow_offset_y", 2)
	meta_hbox.add_child(_timer_label)

	# Wire HP signal from player.
	if _player_controller != null and _player_controller.has_signal("hp_changed"):
		_player_controller.hp_changed.connect(_on_player_hp_changed)
		_player_controller.player_defeated.connect(_on_player_defeated)

	# No centre-screen FPS crosshair in third person. In build mode the 3D
	# ghost block is the world-space target preview, which shows the exact
	# placement cell without pretending the camera is the player's eyes.

	# Hotbar (bottom-center) — 5 block-kind slots, kid hits 1..5 to switch.
	_hotbar_panel = HBoxContainer.new()
	_hotbar_panel.name = "Hotbar"
	_hotbar_panel.add_theme_constant_override("separation", 8)
	_hotbar_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar_panel.offset_left = -280
	_hotbar_panel.offset_top = -96
	_hotbar_panel.offset_right = 280
	_hotbar_panel.offset_bottom = -24
	hud.add_child(_hotbar_panel)
	_rebuild_hotbar_panel(0)
	if _player_controller != null and _player_controller.has_signal("hotbar_changed"):
		_player_controller.hotbar_changed.connect(_on_hotbar_changed)

	# One contextual action prompt replaces a permanent wall of controls. It
	# appears only near a door, chair, workbench or other authored object.
	_interaction_prompt_panel = PanelContainer.new()
	_interaction_prompt_panel.name = "InteractionPrompt"
	_interaction_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_prompt_panel.offset_left = -190
	_interaction_prompt_panel.offset_top = -154
	_interaction_prompt_panel.offset_right = 190
	_interaction_prompt_panel.offset_bottom = -112
	_interaction_prompt_panel.visible = false
	_interaction_prompt_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.92, 0.72, 0.30), 0.92))
	var prompt_content := Control.new()
	prompt_content.custom_minimum_size = Vector2(380, 42)
	_interaction_prompt_panel.add_child(prompt_content)
	_interaction_prompt_icon = TextureRect.new()
	_interaction_prompt_icon.name = "InteractionIcon"
	_interaction_prompt_icon.texture = HUD_ACTION_GREEN
	_interaction_prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_interaction_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_interaction_prompt_icon.position = Vector2(4, 2)
	_interaction_prompt_icon.size = Vector2(38, 38)
	_interaction_prompt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_content.add_child(_interaction_prompt_icon)
	_interaction_prompt_label = Label.new()
	_interaction_prompt_label.name = "InteractionPromptLabel"
	_interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interaction_prompt_label.add_theme_font_size_override("font_size", 18)
	_interaction_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	_interaction_prompt_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_interaction_prompt_label.offset_left = 44
	_interaction_prompt_label.offset_right = -8
	prompt_content.add_child(_interaction_prompt_label)
	hud.add_child(_interaction_prompt_panel)
	
func _tick_world_interactions() -> void:
	if _world_renderer == null or _player_controller == null or _interaction_prompt_panel == null:
		return
	# Preserve action feedback for its short display window; otherwise the
	# proximity scan below immediately replaces “Ugotowano!” with the generic
	# E prompt on the very next physics tick.
	if _interaction_feedback_until > 0.0:
		_interaction_prompt_panel.visible = true
		return
	var nearest: Node3D = null
	var nearest_distance := 2.8
	for candidate in get_tree().get_nodes_in_group("world_interactable"):
		if not (candidate is Node3D) or not is_instance_valid(candidate):
			continue
		var distance := _player_controller.global_position.distance_to((candidate as Node3D).global_position)
		if distance < nearest_distance:
			nearest = candidate as Node3D
			nearest_distance = distance
	_nearby_world_interactable = nearest
	if nearest == null:
		_interaction_prompt_panel.visible = false
		return
	if _interaction_prompt_icon != null:
		_interaction_prompt_icon.texture = _interaction_texture_for(String(nearest.get_meta("interaction_action", "")))
	_interaction_prompt_label.text = String(nearest.get_meta("interaction_prompt", "E  Interakcja"))
	_interaction_prompt_panel.visible = true


func _activate_world_interaction() -> void:
	if _nearby_world_interactable == null or not is_instance_valid(_nearby_world_interactable):
		return
	var action := String(_nearby_world_interactable.get_meta("interaction_action", ""))
	match action:
		"door":
			_world_renderer.toggle_door(_nearby_world_interactable)
			_interaction_feedback("Drzwi gotowe — wejdź do środka.")
		"cook":
			_craft_home_meal()
		"sit":
			if _player_controller.has_method("play_sit_at"):
				_player_controller.play_sit_at(_nearby_world_interactable.global_position + Vector3(0, 0.45, 0.7))
			_interaction_feedback("Chwila odpoczynku przy stole.")
		"gather_wood", "gather_stone":
			_gather_world_resource(_nearby_world_interactable)


func _interaction_feedback(message: String) -> void:
	if _interaction_prompt_label == null:
		return
	_interaction_prompt_label.text = message
	_interaction_feedback_until = 1.8


func _interaction_texture_for(action: String) -> Texture2D:
	match action:
		"cook": return HUD_ICON_WORKBENCH
		"sit": return HUD_ICON_BEDROLL
		"door": return HUD_ICON_HAMMER
		"gather_wood": return HUD_ICON_AXE
		"gather_stone": return HUD_ICON_STONE
		_: return HUD_ACTION_GREEN


func _gather_world_resource(anchor: Node3D) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var item_id := String(anchor.get_meta("resource_item_id", ""))
	if item_id.is_empty():
		return
	var inventory: Dictionary = {}
	if _rules_runtime != null:
		var raw: Variant = _rules_runtime.get_context_value("inventory")
		if raw is Dictionary:
			inventory = raw
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	if _rules_runtime != null:
		_rules_runtime.set_context_value("inventory", inventory)
		_rules_runtime.on_event("inventory_changed", {"item": item_id})
		_rules_runtime.on_event("collect_%s" % item_id, {})
	_refresh_inventory_panel(inventory)
	_try_auto_upgrade_weapon(inventory)
	if _audio_bus != null:
		_audio_bus.emit_sfx("collect", anchor.global_position)
	if _effect_spawner != null:
		_effect_spawner.spawn_collect_effect(anchor.global_position)
	var visual_variant: Variant = anchor.get_meta("resource_visual", null)
	if visual_variant is Node and is_instance_valid(visual_variant):
		(visual_variant as Node).queue_free()
	anchor.remove_from_group("world_interactable")
	if _nearby_world_interactable == anchor:
		_nearby_world_interactable = null
	anchor.queue_free()
	_interaction_feedback("Zebrano!")


func _craft_home_meal() -> void:
	var inventory: Dictionary = {}
	if _rules_runtime != null:
		var raw: Variant = _rules_runtime.get_context_value("inventory")
		if raw is Dictionary:
			inventory = raw
	# The starter kitchen has a forgiving first recipe so the child can learn
	# the loop immediately; later meals consume an apple or gathered wood.
	var has_ingredient := int(inventory.get("apple", 0)) > 0 or int(inventory.get("wood_oak", 0)) > 0
	if has_ingredient:
		if int(inventory.get("apple", 0)) > 0:
			inventory["apple"] = int(inventory["apple"]) - 1
		else:
			inventory["wood_oak"] = int(inventory["wood_oak"]) - 1
	inventory["meal"] = int(inventory.get("meal", 0)) + 1
	if _rules_runtime != null:
		_rules_runtime.set_context_value("inventory", inventory)
		_rules_runtime.on_event("inventory_changed", {"item": "meal"})
	_refresh_inventory_panel(inventory)
	if _player_controller != null and _player_controller.get_health() != null:
		var health := _player_controller.get_health()
		health.current_hp = mini(health.current_hp + 20, health.max_hp)
		health.is_alive = true
		_player_controller.hp_changed.emit(health.current_hp, health.max_hp)
	_interaction_feedback("Ugotowano posiłek! +20 zdrowia")


func _hud_panel_style(accent: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 8
	return style

func _physics_process(delta: float) -> void:
	if _rules_active and _rules_runtime != null:
		_rules_runtime.tick(delta)
	if _autowin:
		_tick_autowin()
	_check_enemy_wave_respawn(delta)
	_check_fall_kill_plane()
	_session_elapsed_sec += delta
	_check_goal_and_lose()
	_tick_npcs(delta)
	if _world_renderer != null and _player_controller != null and is_instance_valid(_player_controller):
		_world_renderer.set_exploration_focus(_player_controller.global_position)
	_tick_world_interactions()
	if _interaction_feedback_until > 0.0:
		_interaction_feedback_until -= delta
		if _interaction_feedback_until <= 0.0 and _interaction_prompt_label != null:
			_interaction_prompt_label.text = ""


## Wave 3 W3-A/B: evaluate the active goal + lose conditions each tick.
## Idempotent via _outcome_emitted; safe to call after end_session
## scheduled but before tree-cleanup completes.
func _check_goal_and_lose() -> void:
	if _outcome_emitted or _goal_evaluator == null:
		return

	# 1) Time-limit lose path (only when a goal is set; free-play has no timer).
	if _goal != null and _time_limit_sec > 0 and int(_session_elapsed_sec) >= _time_limit_sec:
		_finish_session(_goal_evaluator.evaluate(
			_goal, _build_goal_context(), _score, WinOutcome.REASON_TIMEOUT))
		return

	# 2) Win path (goal_met). Skip for free-play (_goal == null).
	if _goal != null:
		var ctx := _build_goal_context()
		var outcome := _goal_evaluator.evaluate(_goal, ctx, _score, "")
		_last_goal_check_ratio = _goal_evaluator.progress_ratio(_goal, ctx)
		_refresh_goal_hud()
		if outcome != null and outcome.won:
			_finish_session(outcome)


## Wave 3 W3-A6: keep the goal HUD in sync with current progress, lives,
## and remaining time. Called from _check_goal_and_lose each tick.
func _refresh_goal_hud() -> void:
	if _goal_panel == null:
		return
	_goal_panel.visible = (_goal != null)
	if _goal_bar != null:
		_goal_bar.value = _last_goal_check_ratio
	if _lives_label != null:
		_lives_label.text = _format_lives_text()
	if _timer_label != null:
		_timer_label.text = _format_timer_text()


func _format_lives_text() -> String:
	if _lives_remaining < 0:
		return ""
	return "❤ × %d" % _lives_remaining


func _format_timer_text() -> String:
	if _time_limit_sec <= 0:
		return ""
	var remaining: int = max(0, _time_limit_sec - int(_session_elapsed_sec))
	var mm: int = remaining / 60
	var ss: int = remaining % 60
	return "⏱ %d:%02d" % [mm, ss]


## Snapshot the in-runtime state into the dict shape WinConditionInterpreter
## expects. Mirrors GameGoal.progress_ratio() — keep them in sync.
func _build_goal_context() -> Dictionary:
	var inventory: Dictionary = {}
	var zones: Dictionary = {}
	if _rules_runtime != null:
		var rt_inv: Variant = _rules_runtime.get_context_value("inventory")
		if rt_inv is Dictionary:
			inventory = rt_inv
		var rt_zones: Variant = _rules_runtime.get_context_value("in_zone")
		if rt_zones is Dictionary:
			zones = rt_zones
	return {
		"score": _score,
		"time": int(_session_elapsed_sec),
		"blocks_placed": _build_grid.placed_count() if _build_grid != null and _build_grid.has_method("placed_count") else 0,
		"inventory": inventory,
		"in_zone": zones,
		"quest": {},
	}


## Single funnel for terminal session states. Emits session_outcome
## then defers to end_session for the existing teardown path.
func _finish_session(outcome: WinOutcome) -> void:
	if _outcome_emitted or outcome == null:
		return
	_outcome_emitted = true
	session_outcome.emit(outcome)
	if outcome.won and _victory_sequence != null:
		# Win juice: confetti + win sting + green flash. VictorySequence
		# ends the session itself via completed -> _on_victory_completed,
		# so don't double-end here.
		_trigger_victory()
	else:
		end_session()


## Spring block can launch kid past the world edge (Adv 2 H-5). If
## player y drops below FALL_KILL_PLANE_Y, trigger soft-respawn —
## same flow as HP=0. No game-over screen, no death — just a soft
## fade-flash + teleport back to spawn point.
func _check_fall_kill_plane() -> void:
	if _player_controller == null or not is_instance_valid(_player_controller):
		return
	# Template-pack kill plane overrides the hard-coded fallback.
	var plane := _kill_plane_y if _goal != null else FALL_KILL_PLANE_Y
	if _player_controller.global_position.y < plane:
		_consume_life_or_lose()


## Wave 3: lives-aware variant of the legacy soft-respawn. With a finite
## lives budget (template-pack `lose_conditions.lives`), each fall/HP=0
## decrements; reaching 0 emits a goal-not-met WinOutcome (lose by
## abandoned-on-death — closest fit since we don't track death reason
## in the DSL).
func _consume_life_or_lose() -> void:
	if _outcome_emitted:
		return
	if _lives_remaining > 0:
		_lives_remaining -= 1
		_on_player_defeated()
		return
	if _lives_remaining == 0:
		# Lose: out of lives. Score still counts.
		var lose := WinOutcome.new(false, WinOutcome.REASON_ABANDONED, _score)
		lose.mark_completed_now()
		_finish_session(lose)
		return
	# _lives_remaining == -1 (unlimited / free-play) — legacy soft-respawn.
	_on_player_defeated()


## Endless engagement: once kid clears all enemies in a wave, after
## WAVE_RESPAWN_DELAY seconds spawn the next wave with +1 enemy and
## a stronger archetype mix. Drives the gear-grinding loop.
## Debug-only smoke driver. If a template explicitly configures a goal, this
## can defeat one live enemy per tick to exercise the generic goal pipeline
## without input automation. Adventure sandbox does not configure a goal.
func _tick_autowin() -> void:
	if _enemy_root == null or not is_instance_valid(_enemy_root):
		return
	for child in _enemy_root.get_children():
		if child is EnemyController and (child as EnemyController).health.is_alive:
			(child as EnemyController).apply_damage(9999)
			return


func _check_enemy_wave_respawn(delta: float) -> void:
	if _enemy_root == null or not is_instance_valid(_enemy_root):
		return
	if _player_controller == null or not is_instance_valid(_player_controller):
		return
	# Are there any live enemies?
	for child in _enemy_root.get_children():
		if child is EnemyController and (child as EnemyController).health.is_alive:
			_wave_respawn_timer = 0.0
			return
	_wave_respawn_timer += delta
	if _wave_respawn_timer >= WAVE_RESPAWN_DELAY:
		_wave_respawn_timer = 0.0
		_spawn_next_wave()


func _spawn_next_wave() -> void:
	if _player_controller == null or not is_instance_valid(_player_controller):
		return
	if not _is_combat_allowed():
		return
	# Honor parental wave cap (Adv 2 H-3 difficulty-cliff fix). 0 = no
	# extra waves past the starter pack. Non-zero caps wave count.
	var cap := _wave_cap()
	if cap > 0 and _wave_number >= cap:
		print("[combat] wave cap %d reached — no further spawn" % cap)
		return
	_wave_number += 1
	# Resource-driven plan via WaveDirectorService when wired; else
	# the procedural fallback inside the service handles it.
	var plan: Dictionary
	if _wave_service != null:
		plan = _wave_service.plan_wave(_wave_configs, _wave_number)
	else:
		plan = {
			"wave_number": _wave_number,
			"pack_size": mini(3 + _wave_number, 7),
			"hp_mult": 1.0,
			"speed_mult": 1.0,
			"is_boss_wave": false,
			"archetype_weights": {},
		}
	print("[combat] wave %d spawning (%s)" %
		[_wave_number, "boss" if plan.get("is_boss_wave", false) else "normal"])
	_audit_combat("combat_wave_started", {
		"wave_number": _wave_number,
		"is_boss": plan.get("is_boss_wave", false),
		"profile_id": _profile_id,
	})
	var pack_size: int = int(plan.get("pack_size", 3))
	var spawn := _player_controller.global_position
	var rng := _ensure_rng()
	# Adv F/H #1: spawn a BIG_SLIME on boss waves. Counts against
	# pack_size so the kid faces 1 boss + (pack_size-1) regular mobs.
	if bool(plan.get("is_boss_wave", false)):
		_spawn_one(EnemyDefinition.big_slime(), spawn + Vector3(0, 1, -12))
		pack_size = maxi(pack_size - 1, 1)
	# Adv F/H #2: honor archetype_weights from the service plan
	# (was previously thrown away — hardcoded 0.4 blue / 0.7 green
	# floor ignored the director's recommendation entirely).
	var weights: Dictionary = plan.get("archetype_weights", {})
	for i in pack_size:
		var def: EnemyDefinition = _sample_enemy_archetype(weights, rng)
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(8.0, 14.0)
		var pos := spawn + Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)
		_spawn_one(def, pos)
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 0.4, 0.4), 0.25)


func _register_world_rules(world: World) -> void:
	_rules_active = false
	if _rules_runtime == null or _rule_compiler == null:
		return
	if world == null or world.game_rules.is_empty():
		_rules_runtime.reset()
		return
	var compiled := _rule_compiler.compile_all(world.game_rules)
	if compiled.is_empty():
		_rules_runtime.reset()
		return
	_rules_runtime.reset()
	_rules_runtime.register_rules(compiled)
	_rules_runtime.set_context_value("score", 0)
	_rules_runtime.set_context_value("inventory", {})
	_rules_active = true
	print("[gameplay] rules engine active — %d compiled rules" % compiled.size())


## Dispatch table for fired rule actions. Mirrors CompiledRule.ActionKind.
func _on_rules_action(rule_id: String, action_kind: int, params: Dictionary) -> void:
	# Mirror in the rule_fired signal so external listeners (HUD, telemetry)
	# can react without coupling to the runtime port directly.
	emit_signal("rule_fired", rule_id, action_kind, params)
	# Match on named enum values (not int literals) — survives enum
	# reordering. Adv 6 #4 fix.
	match action_kind:
		CompiledRule.ActionKind.ADD_SCORE:
			var amount := int(params.get("amount", 0))
			_score += amount
			if _rules_runtime != null:
				_rules_runtime.set_context_value("score", _score)
			print("[gameplay] add_score(%d) -> %d (rule=%s)" % [amount, _score, rule_id])
		CompiledRule.ActionKind.SPAWN_ITEM:
			print("[gameplay] spawn_item(%s, %d) — not yet implemented" %
				[String(params.get("item", "")), int(params.get("count", 0))])
		CompiledRule.ActionKind.WIN_LEVEL:
			print("[gameplay] win_level fired (rule=%s)" % rule_id)
			_trigger_victory()
		CompiledRule.ActionKind.UNLOCK_AREA:
			print("[gameplay] unlock_area(%s) — deferred to BUILDER wave" %
				String(params.get("zone_id", "")))
		CompiledRule.ActionKind.OPEN_GATE:
			print("[gameplay] open_gate — deferred")
		CompiledRule.ActionKind.SET_RESPAWN_POINT:
			if _player_controller != null and is_instance_valid(_player_controller):
				_player_controller.set_meta("respawn_point",
					_player_controller.global_position)
		CompiledRule.ActionKind.CUSTOM_CALLBACK:
			print("[gameplay] custom_callback(%s) — deferred" %
				String(params.get("callback_name", "")))
		_:
			push_warning("Unknown action_kind: %d" % action_kind)


func end_session() -> void:
	_rules_active = false
	_teardown_adventure_sky()
	if _rules_runtime != null:
		_rules_runtime.reset()
	# Always release the cursor so post-session menus are clickable.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Fan out to the Tauri shell — passes a kid-friendly stats dict so the
	# desktop UI can render its own celebration card. Computed cheaply
	# from in-runtime state so this stays a single forward, not a query.
	_notify_shell("notify_session_ended", [{
		"score": _score,
		"xp_level": _xp_level,
		"xp_current": _xp_current,
		"wave_number": _wave_number,
		"weapon_index": _current_weapon_index,
	}])
	if _build_grid != null and is_instance_valid(_build_grid):
		_build_grid.clear_all()
	if _enemy_root != null and is_instance_valid(_enemy_root):
		for e in _enemy_root.get_children():
			if e is EnemyController:
				e.queue_free()
	if _loot_root != null and is_instance_valid(_loot_root):
		for l in _loot_root.get_children():
			if l is LootPickup:
				l.queue_free()
	_inventory_labels.clear()
	_current_weapon_index = 0
	_wave_number = 0
	_wave_respawn_timer = 0.0
	_xp_level = 0
	_xp_current = 0
	_world_renderer.clear_world()
	if _player_controller != null:
		_player_controller.visible = false
		_player_controller.set_process_input(false)
		_player_controller.set_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore Main/Layout (NavBar + Body) so the kid sees Landing on return.
	_set_main_layout_visible(true)
	session_ended.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_activate_world_interaction()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		# ESC only ever TOGGLES the mouse cursor — it never ends the
		# session. The old two-press "second ESC quits" fired on the
		# first press whenever the cursor was already visible (kid on
		# HUD, or capture never took), ending the game by accident. The
		# visible red Back button is the one and only exit.
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()

func _on_footstep() -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("step", _player_controller.global_position)


## G-key's optional silly interaction is visual/social only: a real local SFX,
## a short readable cloud, and role-aware nearby reactions. Angry characters
## perform one harmless air-swat; this never damages the player or changes
## combat progression.
func _on_player_farted(effect_origin: Vector3) -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("fart_kid_safe", effect_origin)
	if _effect_spawner != null:
		_effect_spawner.spawn_stink_cloud(effect_origin)
	if _npc_root == null:
		return
	# Do not build an ever-growing second social queue when the kid presses G
	# again before the current group has had its short turn.
	if _npc_reaction_queue_active:
		return
	for npc_variant in _npc_root.get_children():
		var npc_root := npc_variant as Node3D
		if npc_root == null or npc_root.global_position.distance_to(effect_origin) > SILLY_FART_REACTION_RANGE:
			continue
		var reaction := _fart_reaction_for(npc_root)
		_match_npc_fart_animation(npc_root, String(reaction.action))
		_queue_npc_reaction(npc_root, reaction)


## Every NPC in range gets an in-character line. The queue deliberately owns
## the single shared subtitle/voice channel so a crowd does not talk over or
## mute itself. If another fart happens while these reactions are playing, its
## visible effect still runs but its social beat waits behind the first group.
func _queue_npc_reaction(npc_root: Node3D, reaction: Dictionary) -> void:
	if npc_root == null:
		return
	if _npc_reaction_queue.size() >= SILLY_FART_MAX_QUEUED_REACTIONS:
		return
	var line := String(reaction.get("line", "")).strip_edges()
	if line.is_empty():
		return
	_npc_reaction_queue.append({
		"npc": weakref(npc_root),
		"npc_id": String(npc_root.get_meta("npc_id", "")),
		"name_pl": String(npc_root.get_meta("npc_name_pl", "Ktoś")),
		"line": line,
		"emotion": int(reaction.get("emotion", FacialPerformance.Emotion.HAPPY)),
		"request_id": _next_npc_reaction_request_id(),
	})
	if _npc_reaction_queue_active or not is_inside_tree():
		return
	_npc_reaction_queue_active = true
	_drain_npc_reaction_queue()


func _drain_npc_reaction_queue() -> void:
	while not _npc_reaction_queue.is_empty():
		var turn: Dictionary = _npc_reaction_queue.pop_front()
		var npc_ref := turn.get("npc", null) as WeakRef
		var npc_root := npc_ref.get_ref() as Node3D if npc_ref != null else null
		if npc_root == null or not is_instance_valid(npc_root):
			continue
		var line := String(turn.get("line", ""))
		var name_pl := String(turn.get("name_pl", "Ktoś"))
		_show_npc_reaction_bubble(npc_root, line)
		_animate_npc_speech(String(turn.get("npc_id", "")), line, int(turn.get("emotion", FacialPerformance.Emotion.HAPPY)))
		_active_npc_reaction_line = line
		_active_npc_reaction_name = name_pl
		_active_npc_reaction_request_id = int(turn.get("request_id", -1))
		_active_npc_reaction_audio_started = false
		_active_npc_reaction_audio_finished = false
		_active_npc_reaction_audio_skipped = false
		if _npc_voice != null and _npc_voice.is_available():
			# The caption waits for playback_started; it cannot get ahead of a
			# slow ElevenLabs synthesis or replace an audible previous line.
			_npc_voice.speak(line, "pl-PL", _active_npc_reaction_request_id)
			var voice_deadline_msec := Time.get_ticks_msec() + int(SILLY_FART_VOICE_TIMEOUT_SECONDS * 1000.0)
			while not _active_npc_reaction_audio_finished and is_inside_tree():
				if Time.get_ticks_msec() >= voice_deadline_msec:
					# HTTPRequest also owns a timeout, but retain a runtime circuit
					# breaker so a misbehaving custom adapter cannot stall the world.
					_npc_voice.cancel()
					_active_npc_reaction_audio_skipped = true
					_active_npc_reaction_audio_finished = true
					break
				await get_tree().process_frame
			if _active_npc_reaction_audio_skipped and is_inside_tree():
				_show_npc_dialogue(name_pl, line, false)
				await get_tree().create_timer(_speech_duration_for_line(line)).timeout
			_hide_npc_dialogue()
		else:
			# Offline mode remains accessible through a timed visual caption.
			_show_npc_dialogue(name_pl, line, false)
			var tree := get_tree()
			if tree == null:
				break
			await tree.create_timer(_speech_duration_for_line(line) + SILLY_FART_REACTION_GAP_SECONDS).timeout
			_hide_npc_dialogue()
		_active_npc_reaction_line = ""
		_active_npc_reaction_name = ""
		_active_npc_reaction_request_id = -1
	_npc_reaction_queue_active = false


func _next_npc_reaction_request_id() -> int:
	_npc_reaction_request_sequence += 1
	return _npc_reaction_request_sequence


func _on_npc_voice_playback_started(line: String, request_id: int = 0) -> void:
	if _active_npc_reaction_line != line or _active_npc_reaction_request_id != request_id:
		return
	_active_npc_reaction_audio_started = true
	_show_npc_dialogue(_active_npc_reaction_name, line, false)


func _on_npc_voice_playback_finished(line: String, request_id: int = 0) -> void:
	if _active_npc_reaction_line == line and _active_npc_reaction_request_id == request_id:
		_active_npc_reaction_audio_finished = true


func _on_npc_voice_playback_skipped(line: String, request_id: int = 0) -> void:
	if _active_npc_reaction_line == line and _active_npc_reaction_request_id == request_id:
		_active_npc_reaction_audio_skipped = true
		_active_npc_reaction_audio_finished = true


func _fart_reaction_for(npc_root: Node3D) -> Dictionary:
	var visual_id := String(npc_root.get_meta("npc_id", ""))
	var role := String(npc_root.get_meta("npc_role", ""))
	if visual_id == "npc_parrot":
		return {"line": "Ćwir! To był bąbelkowy podmuch!", "emotion": FacialPerformance.Emotion.HAPPY, "action": "laugh"}
	if visual_id == "npc_pirate":
		return {"line": "Arrr! Dość tych gazowych armat!", "emotion": FacialPerformance.Emotion.ANGRY, "action": "swat"}
	if role == NPCCharacter.ROLE_VENDOR:
		return {"line": "Fuj! Otwórzmy okno, proszę!", "emotion": FacialPerformance.Emotion.SURPRISED, "action": "recoil"}
	if role == NPCCharacter.ROLE_HOSTILE:
		return {"line": "Ej! To wcale nie jest śmieszne!", "emotion": FacialPerformance.Emotion.ANGRY, "action": "swat"}
	return {"line": "Haha! To był naprawdę mały wiaterek!", "emotion": FacialPerformance.Emotion.HAPPY, "action": "laugh"}


func _show_npc_reaction_bubble(npc_root: Node3D, line: String) -> void:
	var bubble := npc_root.get_node_or_null("FartReaction") as Label3D
	if bubble == null:
		bubble = Label3D.new()
		bubble.name = "FartReaction"
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.no_depth_test = false
		bubble.pixel_size = 0.0035
		bubble.font_size = 24
		bubble.outline_size = 4
		bubble.modulate = Color(0.92, 1.0, 0.76)
		bubble.outline_modulate = Color(0.04, 0.08, 0.02, 0.9)
		# Every NPC source has a different body height. The spawn path can supply
		# a precise speech anchor; otherwise this compact default stays close to a
		# human head rather than hovering above small props such as the parrot.
		bubble.position = Vector3(0.0, float(npc_root.get_meta("speech_bubble_height", 1.75)), 0.0)
		npc_root.add_child(bubble)
	bubble.text = line
	bubble.visible = true
	var tree := get_tree()
	if tree == null:
		return
	# Keep a weak reference: streamed NPCs can be freed before the timeout and
	# a lambda must never retain (or dereference) their old speech bubble.
	var bubble_ref: WeakRef = weakref(bubble)
	tree.create_timer(2.8).timeout.connect(func() -> void:
		var captured_bubble: Label3D = bubble_ref.get_ref() as Label3D
		if captured_bubble != null and is_instance_valid(captured_bubble):
			captured_bubble.visible = false)


func _match_npc_fart_animation(npc_root: Node3D, action: String) -> void:
	var visual := npc_root.get_child(0) as Node3D if npc_root.get_child_count() > 0 else null
	if visual == null:
		return
	var original_yaw := visual.rotation.y
	var tween := create_tween()
	match action:
		"swat":
			# Whole-rig roll was tipping characters and visibly lifting their feet.
			# A quick planted-foot yaw is a readable, harmless "hey!" gesture.
			tween.tween_property(visual, "rotation:y", original_yaw + 0.18, 0.12)
			tween.tween_property(visual, "rotation:y", original_yaw - 0.10, 0.12)
			tween.tween_property(visual, "rotation:y", original_yaw, 0.16)
		"recoil":
			tween.tween_property(visual, "rotation:y", original_yaw - 0.12, 0.12)
			tween.tween_property(visual, "rotation:y", original_yaw, 0.20)
		_:
			tween.tween_property(visual, "rotation:y", original_yaw + 0.10, 0.10)
			tween.tween_property(visual, "rotation:y", original_yaw - 0.10, 0.12)
			tween.tween_property(visual, "rotation:y", original_yaw, 0.12)

func _on_landed() -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("land", _player_controller.global_position)
	if _effect_spawner != null:
		var feet_pos := _player_controller.global_position - Vector3(0, _player_controller.scale.y * 0.9, 0)
		_effect_spawner.spawn_dust_puff(feet_pos)

func _on_jumped() -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("jump", _player_controller.global_position)

func _on_hard_landed() -> void:
	if _screen_feedback != null:
		_screen_feedback.shake(4.0, 0.2)

func _on_trigger_area_entered(body: Node3D, area: Area3D) -> void:
	if body != _player_controller:
		return
	var trigger_type: String = area.get_meta("trigger_type", "collectible")
	# Forward zone-enter to rules runtime so on_<event> triggers can fire.
	if _rules_active and _rules_runtime != null:
		_rules_runtime.on_event("zone_%s" % trigger_type, {"zone_id": area.name})
		_rules_runtime.on_event("reach_%s" % trigger_type, {"zone_id": area.name})
		_rules_runtime.on_event("touch_%s" % trigger_type, {"zone_id": area.name})
	match trigger_type:
		"win", "win_zone":
			_trigger_victory()
		"collectible", _:
			_trigger_collectible(area)

func _trigger_collectible(area: Area3D) -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("collect", area.global_position)
	if _effect_spawner != null:
		_effect_spawner.spawn_collect_effect(area.global_position)
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 1.0, 1.0), 0.15)
	# Disable the trigger so it can only be collected once
	area.set_deferred("monitoring", false)
	area.visible = false
	# Forward to rules runtime — increment inventory + fire ON_COLLECT_COUNT.
	if _rules_active and _rules_runtime != null:
		var item_name: String = area.get_meta("item_name", area.name)
		var inv: Dictionary = _rules_runtime.get_context_value("inventory")
		if inv == null:
			inv = {}
		inv[item_name] = int(inv.get(item_name, 0)) + 1
		_rules_runtime.set_context_value("inventory", inv)
		_rules_runtime.on_event("inventory_changed", {"item": item_name})
		_rules_runtime.on_event("collect_%s" % item_name, {})

func _trigger_victory() -> void:
	if _victory_sequence != null:
		_victory_sequence.play()

func _on_victory_completed() -> void:
	end_session()


# ──────────────────────────────────────────────────────────────────────────────
# VS-022 character customization wiring. Loads from disk once per session,
# applies to the player, and lets a compact overlay mutate + persist it.
# ──────────────────────────────────────────────────────────────────────────────

func _apply_loaded_customization() -> void:
	if _player_controller == null or not _player_controller.has_method("apply_customization"):
		return
	if _customization == null:
		_customization = CharacterCustomization.load_from_disk()
	_player_controller.apply_customization(_customization)


func _on_customize_pressed() -> void:
	if _customization_panel != null and is_instance_valid(_customization_panel):
		_close_customization_panel()
		return
	if _customization == null:
		_customization = CharacterCustomization.load_from_disk()
	var hud := get_node_or_null("HUD")
	if hud == null:
		return
	_customization_panel = CharacterCustomizationPanel.new().setup(_customization)
	_customization_panel.customization_changed.connect(_on_customization_panel_changed)
	_customization_panel.panel_closed.connect(_close_customization_panel)
	hud.add_child(_customization_panel)
	# Release mouse capture so the kid can interact with the panel without the
	# camera fighting their cursor. Recaptured on panel close.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_customization_panel_changed(c: CharacterCustomization) -> void:
	if c == null:
		return
	_customization = c
	if _player_controller != null and _player_controller.has_method("apply_customization"):
		_player_controller.apply_customization(c)
	c.save_to_disk()


func _close_customization_panel() -> void:
	if _customization_panel != null and is_instance_valid(_customization_panel):
		_customization_panel.queue_free()
	_customization_panel = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Helper to check if reduce-motion is enabled via the global accessibility policy
func _is_reduce_motion_enabled() -> bool:
	var AccessibilityPolicyPort_class := load("res://src/ports/outbound/accessibility_policy_port.gd")
	if AccessibilityPolicyPort_class != null:
		return AccessibilityPolicyPort_class._global_instance.is_reduce_motion_enabled() if AccessibilityPolicyPort_class._global_instance else false
	return false


## VS-016: Trigger evidence capture for a specific capture point
## Only triggers once per point to avoid duplicate screenshots
func _trigger_evidence_capture(capture_point: int) -> void:
	if _captured_evidence_points.has(capture_point):
		return
	_captured_evidence_points.append(capture_point)
	emit_signal("evidence_capture_requested", capture_point)


## Update ambient particles based on reduce-motion setting
func _update_ambient_particles_from_reduce_motion() -> void:
	if _ambient_particles != null:
		_ambient_particles.emitting = not _is_reduce_motion_enabled()
