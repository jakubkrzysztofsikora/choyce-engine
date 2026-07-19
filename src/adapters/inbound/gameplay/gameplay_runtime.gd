class_name GameplayRuntime
extends Node3D

const FACIAL_PERFORMANCE_SCRIPT := preload("res://src/adapters/inbound/gameplay/facial_performance.gd")
const SKY3D_SCRIPT := preload("res://addons/sky_3d/src/Sky3D.gd")
const PICTORIAL_VITALITY_METER: Script = preload("res://src/adapters/inbound/shared/ui/pictorial_vitality_meter.gd")
const COMPANION_RUNTIME := preload("res://src/adapters/inbound/gameplay/companion_runtime.gd")

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

## VS-026: Emitted BEFORE end_session tears down state, carrying the
## full SandboxState snapshot. PlayShell / main.gd connects this to
## SandboxPersistenceService.save_sandbox() for automatic persistence.
signal session_save_requested(state: SandboxState)

var _world_renderer: WorldRenderer
var _player_controller: PlayerController
var _companion_runtime: Node3D = null
var _session: Session

## VS-016: Track which evidence capture points have been triggered
## to ensure we only capture once per point
var _captured_evidence_points: Array = []
var _opening_evidence_timer: Timer = null
var _evidence_session_token := 0
var _terrain_collision_probe_generation := 0
var _audio_bus: AudioEventBus
var _sfx_player: SFXPlayer
## Live NPC voice (ElevenLabs TTS). Silent no-op without ELEVENLABS_API_KEY.
var _npc_voice: VoicePromptPort = null
var _npc_library_service: NPCAnswerLibraryService = null
var _local_npc_voice: AudioStreamPlayer = null
var _local_npc_voice_line := ""
var _local_npc_voice_request_id := -1
var _effect_spawner: EffectSpawner
var _screen_feedback: ScreenFeedback
var _victory_sequence: VictorySequence
var _ambient_player: AudioStreamPlayer
var _ambient_particles: GPUParticles3D
var _adventure_sky: WorldEnvironment = null
var _adventure_legacy_environment: WorldEnvironment = null
var _adventure_legacy_environment_resource: Environment = null
var _adventure_legacy_light_visibility: Dictionary = {}
var _adventure_legacy_fill_light_state: Dictionary = {}

# VS-025: Nutrition, Training, and Body Progression
var _nutrition_manager: NutritionManager = null
var _training_manager: TrainingManager = null
var _feedback_manager: FeedbackManager = null
var _nutrition_hud: NutritionHUD = null

# Rules engine — injected by main.gd via setup_rules() before start_session.
# Optional: GameplayRuntime keeps working with null rules (legacy worlds).
var _rules_runtime: RulesRuntimePort
var _rule_compiler: RuleCompilerService
var _score: int = 0
var _rules_active: bool = false

# Combat HUD references — built lazily in _build_hud. The visible emergency
# indicator is a pictorial radial meter rather than an unreadable dashboard.
var _hp_meter: Control
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
## The rules runtime is authoritative when injected, but direct/demo sessions
## must not lose collected items just because that optional integration is
## absent. This local mirror is also the hand-off seam for local co-op.
var _local_inventory: Dictionary = {}
var _inventory_overlay: PanelContainer = null
var _inventory_backdrop: ColorRect = null
var _inventory_grid: GridContainer = null
var _craft_recipe_list: VBoxContainer = null
var _inventory_open := false
const SANDBOX_RECIPES := {
	"meal": {"needs": {"food_apple": 1}, "gives": {"meal": 1}, "label": "Posiłek"},
	"stick": {"needs": {"wood_oak": 3}, "gives": {"stick": 1}, "label": "Patyk"},
	"sword_iron": {"needs": {"wood_oak": 3, "ore_iron": 2}, "gives": {"sword_iron": 1}, "label": "Żelazny miecz"},
}
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

# VS-026: Sandbox persistence - current sandbox state
var _sandbox_state: SandboxState = null

# VS-021: Vehicle system
var _vehicle_spawner: VehicleSpawner = null
var _destruction_tracker: DestructionTracker = null
var _active_vehicle: VehicleBase = null
var _adventure_music_state := ""
var _next_adventure_music_rotation_sec := 0.0
const ADVENTURE_MUSIC_ROTATION_SECONDS := {
	"explore": 75.0,
	"drive": 55.0,
	"danger": 45.0,
	"night": 95.0,
}

const WAVE_RESPAWN_DELAY := 6.0
## Kid falls below this y → soft-respawn. Fixes spring-launch
## softlock (Adv 2 H-5). Default world floor is y=0; -50 leaves a
## comfortable buffer for tall builds.
const FALL_KILL_PLANE_Y := -50.0
const HUD_ACTION_GREEN: Texture2D = preload("res://data/textures/ui/PNG/Green/Double/button_round_depth_gloss.png")
const HUD_ICON_AXE: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/tool-axe.png")
const HUD_ICON_PICKAXE: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/tool-pickaxe.png")
const HUD_ICON_HAMMER: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/tool-hammer.png")
const HUD_ICON_GRASS: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/grass.png")
const HUD_ICON_WOOD: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/resource-wood.png")
const HUD_ICON_STONE: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/resource-stone.png")
const HUD_ICON_WORKBENCH: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/workbench.png")
const HUD_ICON_BEDROLL: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/bedroll.png")
const HUD_ICON_STAR: Texture2D = preload("res://data/textures/ui/PNG/Yellow/Double/star.png")
const HUD_ICON_RETURN: Texture2D = preload("res://data/textures/ui/PNG/Blue/Double/arrow_basic_w.png")
const HUD_ICON_CAMP: Texture2D = preload("res://data/models/kenney/survival_kit/Previews/campfire-pit.png")
const HUD_ICON_UNDO: Texture2D = preload("res://data/textures/ui/PNG/Yellow/Double/arrow_basic_w.png")
const HUD_ICON_SILLY_PUFF: Texture2D = preload("res://data/textures/generated/silly-puff-icon-v1.png")

# These core Adventure lines are generated with ElevenLabs at asset-prep time
# and shipped with the game. Finder/editor runs do not inherit a developer
# shell API key, so the cast must not go silent in those normal play paths.
const LOCAL_NPC_VOICE_STREAMS := {
	"Hej! Jestem Olek. Wybierz kierunek i zobaczmy, co odkryjemy.": preload("res://data/audio/voice/adventure_olek_greeting.mp3"),
	"Arr! Jestem Pablo. Nie dotykaj mojego kompasu, ale rozejrzyj się do woli.": preload("res://data/audio/voice/adventure_pablo_greeting.mp3"),
	"Ćwir-ćwir! Jestem Pestka. Lubię śmiech, fale i błyszczące kamyki!": preload("res://data/audio/voice/adventure_pestka_greeting.mp3"),
	"Ojej! Ten wiatr ma własny plan podróży!": preload("res://data/audio/voice/adventure_olek_fart.mp3"),
	"Arrr! Jeszcze jeden taki podmuch i wymachnę szablą w powietrzu!": preload("res://data/audio/voice/adventure_pablo_fart.mp3"),
	"Ćwir-haha! Pestka słyszała głośniejsze fale!": preload("res://data/audio/voice/adventure_pestka_fart.mp3"),
}

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
# PlayShell from NPCDialogueLoader.filtered_for_policy(). An empty list
# skips the authored Adventure NPCs, but starter-camp residents still
# spawn so free-play sessions have a lived-in, child-safe camp.
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
var _sandbox_hint_panel: PanelContainer = null
var _nearby_world_interactable: Node3D = null
var _interaction_feedback_until: float = 0.0
const SILLY_FART_REACTION_RANGE := 10.0
## A reaction is a tiny social beat, not a crowd of voices competing at once.
## Every nearby NPC gets an immediate world-space response. Spoken turns then
## use one channel, so a crowd never mutters over itself.
const SILLY_FART_REACTION_GAP_SECONDS := 0.12
## Every nearby character gets its own visible bubble, but only a few close
## voices use the shared caption/TTS channel. This keeps a crowded village
## readable instead of letting an optional gag suppress normal conversation.
const SILLY_FART_MAX_SPOKEN_REACTIONS := 3
const SILLY_FART_VOICE_TIMEOUT_SECONDS := 3.0
const NORMAL_NPC_VOICE_TIMEOUT_SECONDS := 5.0
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
## Normal greetings share the same one ElevenLabs player as reactions. Track
## their request separately so an optional gag waits rather than talking over
## or cancelling an ordinary encounter.
var _normal_npc_voice_active := false
var _normal_npc_voice_request_id := -1
var _normal_npc_voice_line := ""

# Intelligent NPC dialogue variables
var _npc_llm_port: LLMPort = null
var _npc_moderation: ModerationPort = null
var _npc_dialogue_panel: PanelContainer = null
var _npc_dialogue_input: LineEdit = null
var _npc_dialogue_send: Button = null
var _npc_dialogue_close: Button = null
var _npc_dialogue_history: Dictionary = {}
# A provider is optional enrichment, never a modal gameplay dependency. Keep a
# generation token so a late model callback cannot overwrite a local reply
# after its short fail-safe timeout.
var _npc_dialogue_request_sequence := 0
var _active_npc_dialogue_request_id := -1
const NPC_DIALOGUE_REPLY_TIMEOUT_SECONDS := 4.0


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


## Imported characters are normally a Node3D/armature wrapper around one or
## more render meshes.  Keep systems such as body progression independent from
## that importer detail by resolving the first actual MeshInstance3D safely.
func _find_first_mesh_instance(root: Node) -> MeshInstance3D:
	if root == null:
		return null
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found := _find_first_mesh_instance(child)
		if found != null:
			return found
	return null


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
	# VS-025: Initialize nutrition and training managers
	_nutrition_manager = $NutritionManager if has_node("NutritionManager") else null
	_training_manager = $TrainingManager if has_node("TrainingManager") else null
	_feedback_manager = $FeedbackManager if has_node("FeedbackManager") else null
	_nutrition_hud = $NutritionHUD if has_node("NutritionHUD") else null
	# The standalone NutritionHUD predates the Adventure image-first HUD and is
	# a separate CanvasLayer at layer 100.  Merely hiding the later in-code
	# nutrition panel did not affect it, leaving the old English Energy /
	# Nutrition / Training text floating over the first scenic frame.  Nutrition
	# still runs in the sandbox; detailed state belongs in the future inventory
	# or character screen, not in a permanent launch overlay.
	if _nutrition_hud != null:
		var legacy_nutrition_panel := _nutrition_hud.get_node_or_null("Panel") as CanvasItem
		if legacy_nutrition_panel != null:
			legacy_nutrition_panel.hide()

	# VS-025: Set up player mesh reference for BlendShape body progression
	if _training_manager != null and has_node("PlayerController/CharacterMesh"):
		# Imported GLB characters use a Node3D/armature root, rather than a
		# MeshInstance3D root.  The old typed assignment raised at startup and
		# aborted _ready before voice, vehicle and accessibility setup could run.
		# Resolve the first render mesh inside the actual character hierarchy.
		var player_mesh_node := _find_first_mesh_instance($PlayerController/CharacterMesh)
		if player_mesh_node != null:
			_training_manager.set_player_mesh(player_mesh_node)
	
	# VS-025: Wire up manager signals
	if _nutrition_manager != null and _feedback_manager != null:
		_nutrition_manager.caption_requested.connect(_feedback_manager.show_caption)
		_nutrition_manager.voice_requested.connect(_feedback_manager.play_voice)
	if _training_manager != null and _feedback_manager != null:
		_training_manager.caption_requested.connect(_feedback_manager.show_caption)
		_training_manager.voice_requested.connect(_feedback_manager.play_voice)

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
	_npc_voice = preload("res://src/adapters/outbound/tailnet_voice_adapter.gd").new().setup(self, eleven_key, eleven_voice)
	if _npc_voice != null:
		_npc_voice.playback_started.connect(_on_npc_voice_playback_started)
		_npc_voice.playback_finished.connect(_on_npc_voice_playback_finished)
		_npc_voice.playback_skipped.connect(_on_npc_voice_playback_skipped)
	_setup_local_npc_voice()
	_npc_library_service = preload("res://src/application/npc_answer_library_service.gd").new()

	# Ambient music is now driven by AudioBank (play_music called from PlayShell
	# when the world is chosen). The _ambient_player node is kept so the scene
	# tree is unchanged, but we no longer generate procedural noise here.
	# _ambient_player remains silent until AudioBank drives the music bus.

	if _player_controller != null:
		_player_controller.visible = false
		_player_controller.set_process_input(false)
		_player_controller.set_process(false)
		_player_controller.set_physics_process(false)
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
		if _player_controller.has_signal("tool_used"):
			_player_controller.tool_used.connect(_on_player_tool_used)
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


func setup_npc_llm(llm: LLMPort, moderation: ModerationPort) -> void:
	_npc_llm_port = llm
	_npc_moderation = moderation



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


## VS-026: Collect a snapshot of the current runtime state for persistence.
## Returns a fresh SandboxState populated from live fields — never mutates
## the cached _sandbox_state so callers get a consistent read.
func get_sandbox_state() -> SandboxState:
	var state := SandboxState.new()

	# --- identity ---
	if _session != null:
		state.world_id = _session.world_id

	# --- player position ---
	if _player_controller != null:
		state.player_position = _player_controller.global_position

	# --- inventory ---
	# RulesRuntime is authoritative when injected, but a launcher/direct/co-op
	# session can intentionally run without it. Persist the same local fallback
	# used by the live inventory UI instead of silently saving an empty backpack.
	state.inventory = _get_inventory().duplicate(true)

	# --- placed blocks from build grid cell map ---
	if _build_grid != null and is_instance_valid(_build_grid):
		for cell: Vector3i in _build_grid._kind_for_cell.keys():
			var kind_id: String = String(_build_grid._kind_for_cell[cell])
			state.placed_blocks.append({"cell": cell, "kind": kind_id})

	# --- progression fields ---
	state.progression.score = _score
	state.progression.collectibles = {}
	if _session != null and _session.progress != null:
		state.progression.collectibles = _session.progress.collectibles.duplicate(true)
		state.progression.achievements = _session.progress.achievements.duplicate()
		state.progression.unlocks = _session.progress.unlocks.duplicate()
		state.progression.quest_progress = _session.progress.quest_progress.duplicate(true)

	state.saved_at_unix = int(Time.get_unix_time_from_system())
	return state


## VS-026: Restore sandbox state from a previously saved snapshot.
## Called deferred after world render + build grid init so all targets exist.
func restore_sandbox_state(state: SandboxState) -> void:
	_sandbox_state = state
	if state == null or state.is_empty():
		return

	print("[gameplay] VS-026: restoring sandbox state (world=%s, blocks=%d, inv=%d items)" %
		[state.world_id, state.placed_blocks.size(), state.inventory.size()])

	# --- player position ---
	if _player_controller != null and state.player_position != Vector3.ZERO:
		_player_controller.global_position = state.player_position

	# --- inventory → rules_runtime context ---
	if not state.inventory.is_empty():
		_local_inventory = state.inventory.duplicate(true)
		if _rules_runtime != null:
			_rules_runtime.set_context_value("inventory", state.inventory.duplicate(true))
		_refresh_inventory_panel(state.inventory)

	# --- placed blocks → build grid ---
	if _build_grid != null and is_instance_valid(_build_grid) and not state.placed_blocks.is_empty():
		for entry in state.placed_blocks:
			if entry is Dictionary:
				var cell_raw: Variant = entry.get("cell", null)
				var kind_id: String = String(entry.get("kind", ""))
				if cell_raw is Vector3i and not kind_id.is_empty():
					_build_grid.place_block(cell_raw as Vector3i, kind_id, false)

	# --- progression ---
	_score = state.progression.score
	if _score_label != null:
		_score_label.text = str(_score)


## VS-026: Deferred restore to ensure world is fully rendered
func _deferred_restore_sandbox_state() -> void:
	if _sandbox_state != null and not _sandbox_state.is_empty():
		restore_sandbox_state(_sandbox_state)


func start_session(world: World, session: Session, sandbox_state: SandboxState = null) -> void:
	_cancel_opening_spawn_evidence()
	_evidence_session_token += 1
	_terrain_collision_probe_generation += 1
	var terrain_probe_generation := _terrain_collision_probe_generation
	_session = session
	_score = 0
	_session_elapsed_sec = 0.0
	_outcome_emitted = false
	_last_goal_check_ratio = 0.0
	_autowin = (OS.has_feature("debug") or OS.has_feature("editor")) \
		and OS.get_environment("CHOYCE_AUTOWIN") == "1"
	# VS-026: Store sandbox state reference to restore after world render
	if sandbox_state != null:
		_sandbox_state = sandbox_state
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
	# Terrain3D collision is asynchronous. Keep the invisible legacy floor as a
	# safety catch until direct physics rays prove the spawned terrain has live
	# collision at both the player start and the north bridge approach.
	_set_legacy_ground_collision_enabled(true)
	print("[gameplay] render_world done in %d ms" % (Time.get_ticks_msec() - t0))
	_register_world_rules(world)
	# VS-026: Restore sandbox state after world is rendered and player is available
	# Use call_deferred to ensure world is fully rendered before restoring
	if _sandbox_state != null and not _sandbox_state.is_empty():
		call_deferred("_deferred_restore_sandbox_state")
	var spawn_pos := _world_renderer.get_spawn_position(0)
	# Capsule bottom is 0.1m below the player root (shape centre y=0.8,
	# total height 1.8). Spawn it directly on the floor instead of one metre
	# above it and waiting for a visible physics drop.
	_player_controller.spawn_at(spawn_pos + Vector3(0, 0.10, 0))
	_player_controller.visible = true
	_player_controller.set_process_input(true)
	_player_controller.set_process(true)
	# Vehicle entry deliberately disables physics. A reused runtime must never
	# carry that disabled state into a new Adventure session, otherwise a player
	# remains suspended at its spawn coordinate despite the visible ground below.
	_player_controller.set_physics_process(true)
	_apply_loaded_customization()
	# Bella (ragdoll cat follower) spawns behind the hero. Cosmetic only —
	# no gameplay impact, no interaction. Derived from Styloo CC0 cat.
	_spawn_companion(spawn_pos)
	if use_adventure_sky and _world_renderer.has_runtime_terrain_collision():
		call_deferred("_confirm_runtime_terrain_collision", terrain_probe_generation,
			_world_renderer.get_runtime_terrain_adapter())
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

	_schedule_opening_spawn_evidence()

	print("[gameplay] session live in %d ms total" % (Time.get_ticks_msec() - t0))


func _ensure_session_music() -> void:
	# Direct test/demo launch paths bypass PlayShell. Keep a dynamic, local,
	# non-lyrical phonk/ambient bed alive there too, so the world is never silent.
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("set_adventure_music_state"):
		bank.call("set_adventure_music_state", "explore")
		_adventure_music_state = "explore"
		_next_adventure_music_rotation_sec = ADVENTURE_MUSIC_ROTATION_SECONDS["explore"]
	elif bank != null and bank.has_method("play_music"):
		bank.call("play_music", "adventure_island", true)


func _tick_adventure_music() -> void:
	var bank := get_node_or_null("/root/AudioBank")
	if bank == null or not bank.has_method("set_adventure_music_state"):
		return
	var desired := "explore"
	if _active_vehicle != null and is_instance_valid(_active_vehicle):
		desired = "drive"
	elif _player_controller != null and is_instance_valid(_player_controller):
		for enemy_variant in get_tree().get_nodes_in_group("enemies"):
			if not (enemy_variant is EnemyController) or not is_instance_valid(enemy_variant):
				continue
			var enemy := enemy_variant as EnemyController
			if enemy.health != null and enemy.health.is_alive \
				and enemy.global_position.distance_to(_player_controller.global_position) < 15.0:
				desired = "danger"
				break
	if desired != _adventure_music_state:
		bank.call("set_adventure_music_state", desired)
		_adventure_music_state = desired
		_next_adventure_music_rotation_sec = _session_elapsed_sec + float(ADVENTURE_MUSIC_ROTATION_SECONDS.get(desired, 75.0))
	if _session_elapsed_sec >= _next_adventure_music_rotation_sec \
		and bank.has_method("rotate_adventure_track"):
		bank.call("rotate_adventure_track")
		_next_adventure_music_rotation_sec = _session_elapsed_sec + float(ADVENTURE_MUSIC_ROTATION_SECONDS.get(desired, 75.0))


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
	_interaction_feedback("E  Wyjdź z pojazdu")


func _on_vehicle_exited(vehicle: VehicleBase, player: PlayerController, exit_position: Vector3) -> void:
	if _active_vehicle == vehicle:
		_active_vehicle = null

	if player != null and is_instance_valid(player):
		player.set_physics_process(true)
		player.visible = true

	# Restore input
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_interaction_feedback("Wysiadłeś z pojazdu.")


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
	# ActiveIndicator is deliberately a sibling of Main/Layout so it can animate
	# across launcher tabs. That also meant it survived the layout hide and left
	# a disconnected lime dash in the gameplay sky. It belongs to shell
	# navigation, never to the in-world HUD.
	var active_indicator := get_node_or_null("/root/Main/ActiveIndicator")
	if active_indicator != null:
		active_indicator.visible = value
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


## The legacy StaticBody3D is an invisible safety catch while Terrain3D is
## streaming its local collision. It is disabled only after verified ray hits;
## that keeps a failed/lazy extension build from letting a child sink through
## visible ground on the first frame of a session.
func _set_legacy_ground_collision_enabled(value: bool) -> void:
	var ground_collision := get_node_or_null("GroundPlane/GroundCollider") as CollisionShape3D
	if ground_collision != null:
		ground_collision.set_deferred("disabled", not value)


func _confirm_runtime_terrain_collision(probe_generation: int, expected_adapter: Node3D) -> void:
	# Dynamic Terrain3D collision is populated after the import/update request;
	# wait for four physics frames rather than treating the request as a ready
	# signal. The legacy floor remains active throughout the check.
	for _frame in 4:
		await get_tree().physics_frame
	if probe_generation != _terrain_collision_probe_generation:
		return
	if _world_renderer == null or not _world_renderer.has_runtime_terrain_collision():
		return
	if _world_renderer.get_runtime_terrain_adapter() != expected_adapter:
		return
	var ground_plane := get_node_or_null("GroundPlane") as CollisionObject3D
	var excluded: Array[RID] = []
	if ground_plane != null:
		excluded.append(ground_plane.get_rid())
	if _player_controller != null:
		excluded.append(_player_controller.get_rid())
	var contacts: Array[Vector3] = [
		_world_renderer.get_spawn_position(0),
		Vector3(0.0, 0.0, -46.0),
		Vector3(14.0, 0.0, -43.0),
	]
	var terrain_session_token := _world_renderer.get_terrain_import_session_token() if _world_renderer else 0
	if _world_renderer.verify_runtime_terrain_contacts(contacts, excluded, expected_adapter, terrain_session_token):
		_set_legacy_ground_collision_enabled(false)
		print("[gameplay] Terrain3D collision verified at spawn and bridge bank; safety floor disabled")
	else:
		push_warning("Terrain3D collision did not verify; retaining hidden safety floor")


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
	# Do not create a replacement shader material here. Sky3D initializes its
	# first material with cloud/noise textures and all of its atmosphere uniform
	# values during enter-tree. Swapping in a blank ShaderMaterial afterward
	# technically renders a sky, but it is the featureless grey field seen in
	# the opening capture.
	# Adventure needs a readable daylight grade, not the high-ambient gray wash
	# inherited from the generic runtime scene. Keep surfaces warm but restrained,
	# preserve shadow contrast under trees and reduce horizon haze without showing
	# the world boundary.
	# Keep a physical ambient floor separate from the sky colour. Sky3D's night
	# sky becomes near-black by design; without this floor the playable terrain,
	# NPCs and bridge collapsed into silhouettes even though moonlight existed.
	environment.ambient_light_energy = 1.15
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
	# Sky3D's custom Environment setter forwards into its SkyDome, which has
	# already entered the tree. Preserve that initialized material while moving
	# the project's Environment settings across. This keeps the same material in
	# SkyDome's cloud processor and the viewport instead of making the former
	# animate one material while the latter shows an uninitialized one.
	var initialized_sky: Sky = sky.environment.sky if sky.environment != null else null
	if initialized_sky != null and initialized_sky.sky_material is ShaderMaterial:
		environment.sky = initialized_sky
	else:
		# Defensive fallback for an unexpected addon initialization failure. The
		# normal code path above always preserves the addon-owned material.
		environment.sky = Sky.new()
		environment.sky.sky_material = ShaderMaterial.new()
		environment.sky.sky_material.shader = load("res://addons/sky_3d/shaders/SkyMaterial.gdshader")
	sky.environment = environment
	# Rebinding gives the dome the retained project Environment. Its material is
	# intentionally the same initialized object, so time and clouds keep their
	# prepared uniforms and texture bindings.
	var sky_dome := sky.get_node_or_null("SkyDome")
	if sky_dome != null and environment.sky != null:
		sky_dome.set("environment", environment)
		sky_dome.set("sky_material", environment.sky.sky_material)
		sky_dome.set("cumulus_material", environment.sky.sky_material)
	_adventure_sky = sky
	# Set these after the node enters the tree, once Sky3D has created its
	# TimeOfDay/SunLight/MoonLight/SkyDome children.
	sky.set("current_time", 13.25)
	# A child should explore a daylight session before night begins. A 24-minute
	# cycle repeatedly threw the live demo into its darkest phase while testing.
	sky.set("minutes_per_day", 48.0)
	sky.set("update_interval", 0.20)
	sky.set("clouds_enabled", true)
	sky.set("cloud_intensity", 0.24)
	sky.set("sun_energy", 1.30)
	# Adventure night remains atmospheric but navigable: children must be able
	# to read the ground, trail and landmark silhouettes without a flashlight.
	sky.set("moon_energy", 1.15)
	sky.set("ambient_energy", 1.15)
	sky.set("sky_contribution", 0.52)
	# Sky3D only reveals ambient energy at night when this is lower than the
	# daytime sky contribution. The previous 0.92 value was clamped to 0.62,
	# making a full night effectively unlit.
	sky.set("night_ambient_boost", true)
	sky.set("night_sky_contribution", 0.16)
	sky.set("tonemap_exposure", 1.02)
	# Existing Environment fog is already tuned to hide the large-world horizon;
	# do not stack Sky3D's fullscreen fog shader over it.
	sky.set("fog_enabled", false)
	# Sky3D supplies the changing key light. Retain the scene's low-energy,
	# shadowless FillLight as a stable readability floor; it prevents an outdoor
	# sandbox from becoming unplayably black during a clouded moonlit phase.
	var night_fill := get_node_or_null("FillLight") as DirectionalLight3D
	if night_fill != null:
		_adventure_legacy_fill_light_state = {
			"energy": night_fill.light_energy,
			"color": night_fill.light_color,
		}
		var time_of_day := sky.get_node_or_null("TimeOfDay")
		if time_of_day != null and time_of_day.has_signal("time_changed"):
			time_of_day.time_changed.connect(_update_adventure_fill_light.bind(sky))
		_update_adventure_fill_light(float(sky.get("current_time")), sky)
	for legacy_light_name in ["DirectionalLight3D"]:
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
	var fill_light := get_node_or_null("FillLight") as DirectionalLight3D
	if fill_light != null and not _adventure_legacy_fill_light_state.is_empty():
		fill_light.light_energy = float(_adventure_legacy_fill_light_state.get("energy", fill_light.light_energy))
		fill_light.light_color = _adventure_legacy_fill_light_state.get("color", fill_light.light_color)
	_adventure_legacy_fill_light_state.clear()
	_adventure_legacy_environment = null
	_adventure_legacy_environment_resource = null


## Keep daylight contrast intact while giving moonlit play a predictable
## readability floor. Sky3D owns the key lights; this is only a shadowless fill
## that follows its actual night state instead of permanently washing the day.
func _update_adventure_fill_light(_time: float, sky: WorldEnvironment) -> void:
	var fill_light := get_node_or_null("FillLight") as DirectionalLight3D
	if fill_light == null or sky == null or not is_instance_valid(sky):
		return
	var is_night := bool(sky.call("is_night")) if sky.has_method("is_night") else false
	fill_light.light_energy = 0.62 if is_night else 0.24
	fill_light.light_color = Color(0.48, 0.62, 0.88, 1.0) if is_night else Color(0.75, 0.85, 1.0, 1.0)


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
				# Civilian NPCs follow a small, authored loop around their work/home
				# marker. They stay at terrain height—no idle bob or floating labels—so
				# the opening reads as a lived-in place rather than a prop showroom.
				var wander_origin: Vector3 = body.get_meta("npc_wander_origin", body.global_position) as Vector3
				var wander_radius := float(body.get_meta("npc_wander_radius", 1.25))
				var wander_speed := float(body.get_meta("npc_wander_speed", 0.32))
				var phase := float(body.get_meta("npc_wander_phase", 0.0))
				var orbit := Vector3(cos(t * wander_speed + phase), 0.0,
					sin(t * wander_speed * 0.83 + phase)) * wander_radius
				var desired := wander_origin + orbit
				desired.y = base_y
				var horizontal := desired - body.global_position
				horizontal.y = 0.0
				var is_walking := horizontal.length() > 0.10
				if is_walking:
					body.global_position = body.global_position.move_toward(desired, delta * 0.72)
					body.look_at(body.global_position + horizontal, Vector3.UP)
				body.global_position.y = base_y
				_set_npc_locomotion(body, is_walking)
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


## Spawn Bella (ragdoll cat follower) behind the hero. Cosmetic companion —
## no combat, no dialogue, follows the nearest player at a soft leash.
func _spawn_companion(spawn_pos: Vector3) -> void:
	if _companion_runtime != null and is_instance_valid(_companion_runtime):
		_companion_runtime.queue_free()
		_companion_runtime = null
	_companion_runtime = COMPANION_RUNTIME.new()
	_companion_runtime.name = "CompanionRuntime"
	add_child(_companion_runtime)
	# Place Bella just behind+beside the hero so she doesn't clip the capsule.
	var offset := Vector3(0.6, 0.0, 1.2)
	_companion_runtime.global_position = spawn_pos + offset


## Wave 3 W3-A3: spawn one visible NPC per roster entry around the opening
## path. Each gets a collision body + Area3D so walking up triggers the
## greeting bubble. Quaternius rigs provide recognizable silhouettes.
func _spawn_npcs() -> void:
	if _player_controller == null:
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

	# Spawn authored Adventure NPCs only when a roster was injected. The roster
	# may be empty in free-play sessions, but the starter-camp residents below
	# still populate the opening so the world never feels abandoned.
	if not _npc_roster.is_empty():
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

	# A small, ordinary camp population makes the north-bank home feel lived in
	# before the later village expansion. These reuse the grounded human rigs and
	# local facial attachment path; none are color blobs or passive billboards.
	var residents: Array[NPCCharacter] = [
		NPCCharacter.new("npc_hania", NPCCharacter.ROLE_GUIDE, "Hania", {
			"greeting_pl": "Cześć! Właśnie wracam z lasu. Masz już siekierę?",
			"fart_reaction": {"kind": "laugh", "line": "Ha! Ale numer!"},
		}),
		NPCCharacter.new("npc_bartek", NPCCharacter.ROLE_VENDOR, "Bartek", {
			"greeting_pl": "Pilnuję opału przy domu. Drewno przyda się do gotowania.",
			"fart_reaction": {"kind": "disgust", "line": "Ej, przewietrzmy to!"},
		}),
		NPCCharacter.new("npc_lena", NPCCharacter.ROLE_GUIDE, "Lena", {
			"greeting_pl": "Miło cię widzieć! Za mostem znajdziesz kamienie do zbierania.",
			"fart_reaction": {"kind": "curious", "line": "To było naprawdę głośne!"},
		}),
	]
	var resident_positions := [
		origin + Vector3(-7.5, 0.0, -35.5),
		origin + Vector3(20.5, 0.0, -48.0),
		origin + Vector3(4.5, 0.0, -57.0),
	]
	for resident_index in residents.size():
		_spawn_one_npc(residents[resident_index], resident_positions[resident_index], 2.15)


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
func _spawn_one_npc(npc: NPCCharacter, pos: Vector3, wander_radius: float = 1.25) -> void:
	var root := StaticBody3D.new()
	var is_small_companion := npc.visual_id == "npc_parrot"
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
	root.set_meta("npc_wander_origin", pos)
	root.set_meta("npc_wander_radius", wander_radius)
	root.set_meta("npc_wander_speed", 0.31 + float(abs(npc.npc_id.hash()) % 9) * 0.015)
	root.set_meta("npc_wander_phase", deg_to_rad(float(abs(npc.npc_id.hash()) % 360)))
	root.set_meta("speech_bubble_height", 0.90 if is_small_companion else 1.75)
	var fart_reaction: Variant = npc.lines_pl.get("fart_reaction", {})
	if fart_reaction is Dictionary:
		root.set_meta("fart_reaction", (fart_reaction as Dictionary).duplicate(true))
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
	label.position = Vector3(0, 0.95 if is_small_companion else 2.05, 0)
	label.visible = false
	root.add_child(label)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.height = 0.68 if is_small_companion else 1.2
	shape.radius = 0.21 if is_small_companion else 0.28
	col.shape = shape
	col.position.y = 0.34 if is_small_companion else 0.6
	root.add_child(col)

	# Interaction trigger — 1.8m radius so walking up greets the kid
	# without requiring precise alignment.
	var trigger := Area3D.new()
	trigger.name = "GreetTrigger"
	var trig_shape := SphereShape3D.new()
	trig_shape.radius = 1.0 if is_small_companion else 1.8
	var trig_col := CollisionShape3D.new()
	trig_col.shape = trig_shape
	trigger.add_child(trig_col)
	trigger.body_entered.connect(_on_npc_trigger_entered.bind(root))
	trigger.body_exited.connect(_on_npc_trigger_exited.bind(root))
	root.add_child(trigger)


const _NPC_WALK_HINTS := ["Walk", "walk", "CharacterArmature|Walk", "SkeletonArmature|Skeleton_Walk"]


func _set_npc_locomotion(body: StaticBody3D, walking: bool) -> void:
	var desired_state := "walk" if walking else "idle"
	if String(body.get_meta("npc_locomotion", "")) == desired_state:
		return
	var visual := body.get_child(0) as Node3D if body.get_child_count() > 0 else null
	var anim := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer if visual != null else null
	if anim == null:
		return
	var hints := _NPC_WALK_HINTS if walking else _NPC_IDLE_HINTS
	for hint in hints:
		if anim.has_animation(hint):
			anim.get_animation(hint).loop_mode = Animation.LOOP_LINEAR
			anim.play(hint)
			body.set_meta("npc_locomotion", desired_state)
			return

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
				# Kenney's visible feet sit 10cm above its imported root.  The player
				# controller calibrates this same rig; civilians need the matching
				# resting offset or they visibly hover above their collision capsule.
				model.position.y = -0.10
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
	# No suitable bird model exists in the compatible local packs. Keep a compact,
	# readable parrot silhouette (body, wings, tail, beak and feet) rather than
	# degrading this NPC to a humanoid or a smooth chicken-shaped blob.
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
	# A yellow head read as a tiny human with a coloured helmet from the
	# third-person camera. Keep the head in the parrot's green plumage; reserve
	# yellow for a compact chest patch and the red beak.
	head.material_override = green
	head.position = Vector3(0.0, 0.76, -0.10)
	parrot.add_child(head)
	var chest := MeshInstance3D.new()
	var chest_mesh := SphereMesh.new()
	chest_mesh.radius = 0.18
	chest_mesh.height = 0.30
	chest.mesh = chest_mesh
	chest.material_override = yellow
	chest.position = Vector3(0.0, 0.46, -0.25)
	chest.scale = Vector3(0.75, 1.0, 0.45)
	parrot.add_child(chest)
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
	# The reaction queue owns the one spoken-dialogue channel.  Walking past an
	# NPC while a nearby character is reacting must not create a second voice on
	# top of the first one.
	if _npc_reaction_queue_active:
		return
	if _normal_npc_voice_active:
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
	if _npc_dialogue_panel != null:
		_npc_dialogue_panel.visible = true

	# Clear input text
	if _npc_dialogue_input != null:
		_npc_dialogue_input.text = ""

	# Conversation is an optional overlay, never a modal state. In particular,
	# do not focus its LineEdit on greeting: that previously swallowed E and
	# other gameplay bindings before a child had chosen to type anything.

	# Start conversation history if empty
	if not _npc_dialogue_history.has(_active_npc_id) or _npc_dialogue_history[_active_npc_id].is_empty():
		_npc_dialogue_history[_active_npc_id] = [
			{"role": "assistant", "content": line_pl}
		]

	# Speak the line aloud (ElevenLabs). Caption stays as the fallback. Normal
	# encounters are also request-aware; the reaction queue waits for this turn
	# to finish instead of starting a second concurrent voice.
	if speak_line:
		_normal_npc_voice_request_id = _next_npc_reaction_request_id()
		_normal_npc_voice_line = line_pl
		_normal_npc_voice_active = _speak_npc_line(line_pl, _normal_npc_voice_request_id)


func _setup_local_npc_voice() -> void:
	if _local_npc_voice != null:
		return
	_local_npc_voice = AudioStreamPlayer.new()
	_local_npc_voice.name = "AdventureNpcVoiceFallback"
	_local_npc_voice.bus = "Voice"
	add_child(_local_npc_voice)
	_local_npc_voice.finished.connect(_on_local_npc_voice_finished)


## Test doubles continue through VoicePromptPort. The production adapter uses
## exact shipped ElevenLabs takes for authored Adventure lines, then falls
## back to the live request path for future/un-authored lines.
func _speak_npc_line(line: String, request_id: int) -> bool:
	if _npc_voice != null:
		if _npc_voice.has_method("set_active_voice_id"):
			_npc_voice.set_active_voice_id(_active_npc_id)
		if _npc_voice.is_available():
			_npc_voice.speak(line, "pl-PL", request_id)
			return true
	return _play_local_npc_voice(line, request_id)


func _play_local_npc_voice(line: String, request_id: int) -> bool:
	if _local_npc_voice == null:
		return false
	var stream := LOCAL_NPC_VOICE_STREAMS.get(line, null) as AudioStream
	if stream == null:
		return false
	_local_npc_voice.stop()
	_local_npc_voice.stream = stream
	_local_npc_voice_line = line
	_local_npc_voice_request_id = request_id
	_local_npc_voice.play()
	_on_npc_voice_playback_started(line, request_id)
	return true


func _on_local_npc_voice_finished() -> void:
	if _local_npc_voice_line.is_empty():
		return
	var line := _local_npc_voice_line
	var request_id := _local_npc_voice_request_id
	_local_npc_voice_line = ""
	_local_npc_voice_request_id = -1
	_on_npc_voice_playback_finished(line, request_id)


func _cancel_active_npc_voice() -> void:
	if _npc_voice != null:
		_npc_voice.cancel()
	if _local_npc_voice != null:
		_local_npc_voice.stop()
	_local_npc_voice_line = ""
	_local_npc_voice_request_id = -1


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
	if _npc_dialogue_panel != null:
		_npc_dialogue_panel.visible = false
	if _player_controller != null and _player_controller.has_method("set_input_disabled") and _player_controller.is_input_disabled():
		_player_controller.set_input_disabled(false)


func _build_npc_dialogue_label() -> Label:
	var hud := get_node_or_null("HUD")
	if hud == null:
		return null
	var panel := PanelContainer.new()
	panel.name = "NPCDialogue"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 280
	if _npc_llm_port != null:
		panel.offset_top = -240
	else:
		panel.offset_top = -160
	panel.offset_right = -280
	panel.offset_bottom = -90
	hud.add_child(panel)
	_npc_dialogue_panel = panel
	# The conversation composer is an interaction surface, not a permanent HUD
	# element.  A visible empty panel at boot read as a developer chat overlay
	# and covered the lower third of the opening scene before the child had met
	# anyone. `_show_npc_dialogue()` reveals it only after entering an NPC's
	# intentional conversation radius.
	panel.visible = false

	var vbox := VBoxContainer.new()
	vbox.name = "DialogueVBox"
	panel.add_child(vbox)

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
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(label)

	if _npc_llm_port != null:
		var hbox := HBoxContainer.new()
		hbox.name = "DialogueInputHBox"
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(hbox)

		var input := LineEdit.new()
		input.name = "DialogueInput"
		input.placeholder_text = "Napisz cos do NPC..."
		input.focus_mode = Control.FOCUS_CLICK
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.add_theme_font_size_override("font_size", 18)
		hbox.add_child(input)
		_npc_dialogue_input = input
		input.text_submitted.connect(_on_npc_dialogue_submitted)
		# The controller polls Input actions every frame. GUI consumption alone
		# therefore cannot stop E/G/W from also becoming world actions while their
		# letters are typed. Disable player input only while this LineEdit owns
		# focus; gravity and physics keep running normally.
		input.focus_entered.connect(_on_npc_dialogue_input_focus_entered)
		input.focus_exited.connect(_on_npc_dialogue_input_focus_exited)

		var send_btn := Button.new()
		send_btn.name = "DialogueSendButton"
		send_btn.text = "Wyslij"
		send_btn.focus_mode = Control.FOCUS_CLICK
		send_btn.add_theme_font_size_override("font_size", 18)
		hbox.add_child(send_btn)
		_npc_dialogue_send = send_btn
		send_btn.pressed.connect(func() -> void: _on_npc_dialogue_submitted(""))

		var close_btn := Button.new()
		close_btn.name = "DialogueCloseButton"
		close_btn.text = "Pozegnaj"
		close_btn.focus_mode = Control.FOCUS_CLICK
		close_btn.add_theme_font_size_override("font_size", 18)
		hbox.add_child(close_btn)
		_npc_dialogue_close = close_btn
		close_btn.pressed.connect(_hide_npc_dialogue)

	return label


func _on_npc_dialogue_submitted(text: String = "") -> void:
	if text.strip_edges().is_empty():
		if _npc_dialogue_input != null:
			text = _npc_dialogue_input.text
	if text.strip_edges().is_empty():
		return

	if _npc_dialogue_input != null:
		_npc_dialogue_input.text = ""
		_npc_dialogue_input.release_focus()

	var npc_name := ""
	if _npc_root != null:
		for child in _npc_root.get_children():
			if child.get_meta("npc_id", "") == _active_npc_id:
				npc_name = child.get_meta("npc_name_pl", "")
				break
	if npc_name.is_empty():
		npc_name = _active_npc_id

	if _npc_dialogue_label != null:
		_npc_dialogue_label.text = "%s myśli..." % npc_name

	_npc_dialogue_request_sequence += 1
	var request_id := _npc_dialogue_request_sequence
	_active_npc_dialogue_request_id = request_id
	if _npc_llm_port == null:
		_present_npc_reply(_active_npc_id, npc_name, _authored_npc_fallback_line(_active_npc_from_roster()))
		_active_npc_dialogue_request_id = -1
		return
	_execute_npc_completions(text, request_id)
	# A local model can accept a request and never invoke its callback. Do not
	# strand a child in a permanent “thinking” UI; present the authored response
	# after a short bound and ignore a late callback by request id.
	var tree := get_tree()
	if tree != null:
		tree.create_timer(NPC_DIALOGUE_REPLY_TIMEOUT_SECONDS).timeout.connect(func() -> void:
			if _active_npc_dialogue_request_id != request_id:
				return
			_present_npc_reply(_active_npc_id, npc_name, _authored_npc_fallback_line(_active_npc_from_roster()))
			_active_npc_dialogue_request_id = -1
		)


func _on_npc_dialogue_input_focus_entered() -> void:
	if _player_controller != null and _player_controller.has_method("set_input_disabled"):
		_player_controller.set_input_disabled(true)


func _on_npc_dialogue_input_focus_exited() -> void:
	if _player_controller != null and _player_controller.has_method("set_input_disabled"):
		_player_controller.set_input_disabled(false)


func _active_npc_from_roster() -> NPCCharacter:
	for npc_variant in _npc_roster:
		if npc_variant is NPCCharacter and npc_variant.npc_id == _active_npc_id:
			return npc_variant as NPCCharacter
	return null


func _get_inventory() -> Dictionary:
	if _rules_runtime != null:
		var raw: Variant = _rules_runtime.get_context_value("inventory")
		if raw is Dictionary:
			return raw
	return _local_inventory


func _commit_inventory(inventory: Dictionary, changed_item_id: String = "") -> void:
	_local_inventory = inventory.duplicate(true)
	if _rules_runtime != null:
		_rules_runtime.set_context_value("inventory", inventory)
		if not changed_item_id.is_empty():
			_rules_runtime.on_event("inventory_changed", {"item": changed_item_id})
	_refresh_inventory_panel(inventory)


func _add_inventory_item(item_id: String, amount: int = 1) -> void:
	var inventory := _get_inventory()
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount
	_commit_inventory(inventory, item_id)


func _execute_npc_completions(player_text: String, request_id: int = -1) -> void:
	if _npc_llm_port == null:
		return

	var active_npc: NPCCharacter = null
	for npc_variant in _npc_roster:
		if npc_variant is NPCCharacter and npc_variant.npc_id == _active_npc_id:
			active_npc = npc_variant
			break

	var npc_name_pl := _active_npc_id
	var npc_role := "guide"
	if active_npc != null:
		npc_name_pl = active_npc.name_pl
		npc_role = active_npc.role

	if not _npc_dialogue_history.has(_active_npc_id):
		_npc_dialogue_history[_active_npc_id] = []

	_npc_dialogue_history[_active_npc_id].append({"role": "user", "content": player_text})

	var inv_str := ""
	var inv := _get_inventory()
	for item_id in inv.keys():
		inv_str += "%s: %d, " % [item_id, inv[item_id]]
	if inv_str.is_empty():
		inv_str = "pusty"
	else:
		inv_str = inv_str.left(inv_str.length() - 2)

	var player_hp_ratio := 1.0
	if _player_controller != null and _player_controller.get_health() != null:
		player_hp_ratio = float(_player_controller.get_health().current_hp) / float(_player_controller.get_health().max_hp)

	var psych_context := ""
	if active_npc != null:
		active_npc.update_emotional_state(player_hp_ratio, _score)
		psych_context = "\n\nProfil psychologiczny postaci (OCEAN & Emocje):\n" \
			+ "- Otwartość (Openness): %.2f\n" \
			+ "- Sumienność (Conscientiousness): %.2f\n" \
			+ "- Ekstrawersja (Extraversion): %.2f\n" \
			+ "- Ugodowość (Agreeableness): %.2f\n" \
			+ "- Neurotyczność (Neuroticism): %.2f\n" \
			+ "- Zadowolenie (Happiness): %.2f\n" \
			+ "- Irytacja (Irritability): %.2f\n" \
			+ "- Lęk (Anxiety): %.2f\n" \
			+ "Twoje zachowanie, wypowiedzi i decyzje o przyznaniu/odebraniu przedmiotów, zdrowia lub punktów muszą być spójne z powyższym profilem psychologicznym oraz Twoim aktualnym stanem emocjonalnym."
		psych_context = psych_context % [
			active_npc.openness,
			active_npc.conscientiousness,
			active_npc.extraversion,
			active_npc.agreeableness,
			active_npc.neuroticism,
			active_npc.happiness,
			active_npc.irritability,
			active_npc.anxiety
		]

	var sys_prompt := "Jesteś postacią w grze przygodowej dla dzieci. " \
		+ "Nazywasz się: %s.\n" \
		+ "Twoja rola to: %s (guide = pomocnik/trener, vendor = kupiec, hostile = wróg).\n" \
		+ "Stan gry:\n" \
		+ "- Punkty gracza: %d\n" \
		+ "- Życie gracza: %d/%d\n" \
		+ "- Ekwipunek gracza: %s\n\n" \
		+ "Odpowiadaj po polsku. Pisz krótko (1-3 zdania), dostosowując ton do swojego charakteru.\n" \
		+ "Możesz modyfikować stan gry (dawać/odbierać przedmioty, leczyć, zadawać obrażenia, dawać punkty).\n" \
		+ "Jeśli podejmiesz decyzję o zmianie stanu gry, na samym końcu swojej odpowiedzi dopisz dokładnie blok w tagu <decision>:\n" \
		+ "<decision>\n" \
		+ "{\n" \
		+ "  \"action\": \"give_item|take_item|give_score|heal|damage\",\n" \
		+ "  \"item_id\": \"wood_oak|ore_iron|slime_gel|food_apple|banana\",\n" \
		+ "  \"amount\": 1\n" \
		+ "}\n" \
		+ "</decision>\n" \
		+ "W zwykłym tekście nie wspomominaj o tym bloku ani o tagach." \
		+ "%s"

	sys_prompt = sys_prompt % [
		npc_name_pl,
		npc_role,
		_score,
		_player_controller.get_health().current_hp if _player_controller != null and _player_controller.get_health() != null else 100,
		_player_controller.get_health().max_hp if _player_controller != null and _player_controller.get_health() != null else 100,
		inv_str,
		psych_context
	]

	# Load candidates from our pregenerated/dynamic ready answers library
	var ready_sentences: Array[Dictionary] = []
	if _npc_library_service != null and active_npc != null:
		ready_sentences = _npc_library_service.load_library(_active_npc_id, active_npc.lines_pl)

	var ready_sentences_str := ""
	if not ready_sentences.is_empty():
		ready_sentences_str = "\n\nOpcjonalne gotowe zdania z Twojej biblioteki wypowiedzi (możesz użyć jednego z nich, jeśli idealnie pasuje, zwracając tag np. <use_ready>0</use_ready>, lub wygenerować całkowicie nową unikalną wypowiedź. Zawsze twórz nową wypowiedź, jeśli gotowa nie pasuje idealnie):\n"
		for item in ready_sentences:
			var desc := ""
			if not str(item.get("player_prompt", "")).is_empty():
				desc = " (poprzednia reakcja na: '%s')" % item["player_prompt"]
			ready_sentences_str += "[%d]: \"%s\"%s\n" % [item["index"], item["text"], desc]
		ready_sentences_str += "\nInstrukcja wyboru gotowej wypowiedzi:\n" \
			+ "- Jeśli gotowa wypowiedź pasuje idealnie do słów gracza i Twojego profilu/roli, zwróć dokładnie tag z indeksem: <use_ready>indeks</use_ready>\n"

	sys_prompt = sys_prompt + ready_sentences_str

	var prompt_text := ""
	for msg in _npc_dialogue_history[_active_npc_id]:
		var prefix := "Gracz: " if msg["role"] == "user" else (npc_name_pl + ": ")
		prompt_text += prefix + msg["content"] + "\n"
	prompt_text += npc_name_pl + ":"

	var envelope := PromptEnvelope.new(prompt_text, "pl-PL")
	envelope.system_prompt = sys_prompt
	envelope.max_tokens = 250

	var npc_id := _active_npc_id
	var captured_npc_name := npc_name_pl
	var captured_authored_npc := active_npc

	_npc_llm_port.complete(
		envelope,
		{},
		func(_token: String) -> void: pass,
		func(result: Dictionary) -> void:
			if request_id >= 0 and _active_npc_dialogue_request_id != request_id:
				return
			var reply_text := str(result.get("text", "")).strip_edges()
			# Providers are optional enrichment. A transport/model failure must
			# never become an NPC's line; the child gets a real authored response
			# immediately, even offline or while LiteLLM/Ollama is restarting.
			if _is_unusable_npc_model_result(result, reply_text):
				var local_reply := _authored_npc_fallback_line(captured_authored_npc)
				_present_npc_reply(npc_id, captured_npc_name, local_reply)
				_active_npc_dialogue_request_id = -1
				return

			if _npc_moderation != null:
				# GameplayRuntime receives only a profile id; preserve the child-safe
				# default until a typed profile-age seam is injected by the shell.
				var age_band := AgeBand.new()
				var check := _npc_moderation.check_text(reply_text, age_band)
				if check.is_blocked():
					reply_text = check.safe_alternative if not check.safe_alternative.is_empty() else "Ojej, nie moge o tym rozmawiac."

			var clean_text := reply_text
			var decision_json := ""
			if reply_text.contains("<decision>") and reply_text.contains("</decision>"):
				var start := reply_text.find("<decision>") + 10
				var end := reply_text.find("</decision>")
				decision_json = reply_text.substr(start, end - start).strip_edges()
				clean_text = reply_text.substr(0, reply_text.find("<decision>")).strip_edges()

			# Handle <use_ready> tag selection
			var is_ready_selection := false
			if clean_text.contains("<use_ready>") and clean_text.contains("</use_ready>"):
				var tag_open := clean_text.find("<use_ready>")
				var start_idx := tag_open + 11
				var end_idx := clean_text.find("</use_ready>", start_idx)
				if end_idx > start_idx:
					var idx_str := clean_text.substr(start_idx, end_idx - start_idx).strip_edges()
					if idx_str.is_valid_int():
						var idx := idx_str.to_int()
						if idx >= 0 and idx < ready_sentences.size():
							clean_text = ready_sentences[idx]["text"]
							is_ready_selection = true
				if not is_ready_selection:
					var tag_close := clean_text.find("</use_ready>", tag_open)
					if tag_close > tag_open:
						clean_text = (clean_text.substr(0, tag_open) + clean_text.substr(tag_close + 12)).strip_edges()

			# Persist dynamic generated sentences so the NPC's library grows!
			if not is_ready_selection and not clean_text.is_empty() and _npc_library_service != null:
				var emotion_str := "happiness: %.2f, irritability: %.2f, anxiety: %.2f" % [
					captured_authored_npc.happiness if captured_authored_npc != null else 0.5,
					captured_authored_npc.irritability if captured_authored_npc != null else 0.2,
					captured_authored_npc.anxiety if captured_authored_npc != null else 0.1
				]
				_npc_library_service.save_new_answer(npc_id, clean_text, player_text, emotion_str)

			_present_npc_reply(npc_id, captured_npc_name, clean_text)
			_active_npc_dialogue_request_id = -1

			if not decision_json.is_empty():
				_apply_npc_decision(decision_json)
	)


## LLMPort deliberately normalises providers into a compact dictionary, so the
## game must recognise failures by either explicit metadata or a small family
## of provider-error phrases. It is intentionally narrow: an authored NPC is
## still allowed to say ordinary "nie mogę" dialogue unless it refers to a
## model/provider/transport failure.
func _is_unusable_npc_model_result(result: Dictionary, reply_text: String) -> bool:
	if bool(result.get("stopped", false)) or result.has("error"):
		return true
	var normalized := reply_text.to_lower().strip_edges()
	if normalized.is_empty():
		return true
	var provider_error_terms := ["model", "llm", "provider", "błąd", "blad", "error", "unavailable", "połączeni", "polaczeni", "connection"]
	for term in provider_error_terms:
		if normalized.contains(term):
			return true
	return false


## Resolve a safe, character-specific line that ships with the adventure.
## This keeps the offline demo personable without pretending a live model is
## available or allowing a provider failure to interrupt the play loop.
func _authored_npc_fallback_line(npc: NPCCharacter) -> String:
	if npc != null:
		for trigger in ["hint", "greeting", "celebration"]:
			var line := npc.line_for(trigger)
			if not line.is_empty():
				return line
	return "Rozejrzyj się spokojnie — przygoda jest wszędzie."


func _present_npc_reply(npc_id: String, npc_name: String, reply_text: String) -> void:
	if _npc_dialogue_label != null:
		_npc_dialogue_label.text = "%s: %s" % [npc_name, reply_text]
	_normal_npc_voice_request_id = _next_npc_reaction_request_id()
	_normal_npc_voice_line = reply_text
	_normal_npc_voice_active = _speak_npc_line(reply_text, _normal_npc_voice_request_id)
	if not _npc_dialogue_history.has(npc_id):
		_npc_dialogue_history[npc_id] = []
	_npc_dialogue_history[npc_id].append({"role": "assistant", "content": reply_text})


func _apply_npc_decision(json_str: String) -> void:
	var json := JSON.new()
	if json.parse(json_str) != OK or not json.data is Dictionary:
		push_warning("Failed to parse NPC decision JSON: %s" % json_str)
		return

	var data: Dictionary = json.data
	var action := str(data.get("action", "")).strip_edges()
	var item_id := str(data.get("item_id", "")).strip_edges()
	var amount := int(data.get("amount", 1))

	match action:
		"give_item":
			if not item_id.is_empty():
				_add_inventory_item(item_id, amount)
				print("[npc_decision] gave item: %s x%d" % [item_id, amount])
		"take_item":
			if not item_id.is_empty():
				var inv := _get_inventory()
				var current := int(inv.get(item_id, 0))
				if current >= amount:
					inv[item_id] = current - amount
					if _rules_runtime != null:
						_rules_runtime.set_context_value("inventory", inv)
						_rules_runtime.on_event("inventory_changed", {"item": item_id})
					_refresh_inventory_panel(inv)
					print("[npc_decision] took item: %s x%d" % [item_id, amount])
		"give_score":
			_score += amount
			if _score_label != null:
				_score_label.text = str(_score)
			if _rules_runtime != null:
				_rules_runtime.set_context_value("score", _score)
			print("[npc_decision] gave score: %d" % amount)
		"heal":
			if _player_controller != null and _player_controller.get_health() != null:
				_player_controller.get_health().heal(amount)
				_player_controller.hp_changed.emit(_player_controller.get_health().current_hp, _player_controller.get_health().max_hp)
				print("[npc_decision] healed player: %d" % amount)
		"damage":
			if _player_controller != null:
				_player_controller.apply_damage(amount)
				print("[npc_decision] damaged player: %d" % amount)


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


## Keep an empty swing readable, but route it to a dry physical air cue rather
## than the old imported tonal whoosh that sounded like a spell being cast.
func _on_player_swing_missed(attack_origin: Vector3) -> void:
	if _audio_bus != null:
		var style := "punch"
		if _player_controller != null and _player_controller.has_method("get_last_attack_style"):
			style = _player_controller.get_last_attack_style()
		_audio_bus.emit_sfx("physical_swing_%s" % style, attack_origin)


## Cache attack style for phase-aware impact feedback. A landed hit plays only
## its contact cue below; stacking the old magic-like whoosh on top was the
## source of the reported spell-casting feel.
func _on_player_attacked(damage: int, hit_position: Vector3) -> void:
	# Cache attack style for use in _on_enemy_damaged
	if _player_controller != null and _player_controller.has_method("get_last_attack_style"):
		_last_attack_style = _player_controller.get_last_attack_style()


## A visible held tool must have a matching action. Pick the closest resource
## inside a generous child-friendly forward cone, animate the harvest as three
## deliberate hits, then reuse the normal inventory/reward path.
func _on_player_tool_used(tool_id: String, effect_origin: Vector3, forward: Vector3) -> void:
	_on_player_tool_used_for(_player_controller, tool_id, effect_origin, forward)


## Shared-world adapter for both local players. The resource/inventory state
## belongs to GameplayRuntime; only target selection belongs to the actor that
## actually swung the tool.
func _on_player_tool_used_for(actor: PlayerController, tool_id: String, effect_origin: Vector3, forward: Vector3) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var required_action := "gather_wood" if tool_id == "tool_axe" else "gather_stone"
	var target: Node3D = null
	var best_score := INF
	var candidates := get_tree().get_nodes_in_group("world_interactable")
	# The actual forest, not only isolated loot props, is harvestable with an
	# axe. These roots carry the same resource metadata as interaction anchors
	# but deliberately have no large E-radius bubble around every trunk.
	if tool_id == "tool_axe":
		candidates.append_array(get_tree().get_nodes_in_group("harvestable_tree"))
	for candidate in candidates:
		if not (candidate is Node3D) or not is_instance_valid(candidate):
			continue
		var anchor := candidate as Node3D
		if String(anchor.get_meta("interaction_action", "")) != required_action:
			continue
		var to_target := anchor.global_position - actor.global_position
		to_target.y = 0.0
		var distance := to_target.length()
		if distance > 3.4 or distance < 0.01:
			continue
		var alignment := forward.dot(to_target.normalized())
		if alignment < -0.15:
			continue
		var score := distance - alignment * 0.75
		if score < best_score:
			best_score = score
			target = anchor
	if target == null:
		if _audio_bus != null:
			_audio_bus.emit_sfx("physical_swing_%s" % ("axe" if tool_id == "tool_axe" else "pickaxe"), effect_origin)
		# Tools remain useful in danger. In creative mode the first selected item
		# is often an axe, so silently making it unable to affect a nearby monster
		# felt like combat was broken. Preserve harvesting priority, but route a
		# close visible enemy through the normal physical-hit path when no matching
		# resource was targeted.
		for enemy_candidate in get_tree().get_nodes_in_group("enemies"):
			if enemy_candidate is EnemyController and is_instance_valid(enemy_candidate):
				var enemy := enemy_candidate as EnemyController
				if enemy.global_position.distance_to(actor.global_position) <= 2.15:
					actor._perform_attack()
					break
		_interaction_feedback("Podejdź bliżej do %s." % ("drzewa" if tool_id == "tool_axe" else "skały"),
			"gather_wood" if tool_id == "tool_axe" else "gather_stone")
		return
	if _audio_bus != null:
		_audio_bus.emit_sfx("tool_axe_wood" if tool_id == "tool_axe" else "tool_pickaxe_stone", target.global_position)
	var visual_variant: Variant = target.get_meta("resource_visual") if target.has_meta("resource_visual") else null
	if visual_variant is Node3D and is_instance_valid(visual_variant):
		var visual := visual_variant as Node3D
		var base_rotation := visual.rotation
		var shake := create_tween()
		shake.tween_property(visual, "rotation:z", base_rotation.z + 0.045, 0.06)
		shake.tween_property(visual, "rotation", base_rotation, 0.10)
	var hits := int(target.get_meta("harvest_hits", 0)) + 1
	target.set_meta("harvest_hits", hits)
	if hits < 3:
		_interaction_feedback("%s %d/3" % ["Rąbiesz drzewo" if tool_id == "tool_axe" else "Rozbijasz skałę", hits],
			"gather_wood" if tool_id == "tool_axe" else "gather_stone")
		return
	_gather_world_resource(target, actor)


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
	var inventory := _get_inventory()
	inventory[item_id] = int(inventory.get(item_id, 0)) + quantity
	_commit_inventory(inventory, item_id)
	if _rules_runtime != null:
		_rules_runtime.on_event("collect_%s" % item_id, {})
	_try_auto_upgrade_weapon(inventory)


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
	_refresh_inventory_overlay(inv)


## Exploration retains a compact pictorial backpack. The complete inventory is
## Minecraft-style inventory + crafting modal. Centered overlay with two
## columns: the backpack grid on the left and the crafting recipes on the
## right. Every slot is a framed panel — empty slots show as dark cells so
## the grid always reads as a 4×N grid the kid can scan, like Minecraft's
## survival inventory.
func _build_inventory_overlay(hud: CanvasLayer) -> void:
	if _inventory_overlay != null:
		return
	# Full-screen dim so the world doesn't compete for attention while open.
	var backdrop := ColorRect.new()
	backdrop.name = "InventoryBackdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.05, 0.08, 0.62)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.visible = false
	hud.add_child(backdrop)

	# Centered modal panel — 760×520, plenty of room for two columns.
	var panel := PanelContainer.new()
	panel.name = "SandboxInventoryOverlay"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_top = -260
	panel.offset_right = 380
	panel.offset_bottom = 260
	panel.add_theme_stylebox_override("panel", _inventory_frame_style())
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(panel)
	_inventory_overlay = panel
	# Backdrop is a sibling — track it so toggling closes both.
	_inventory_backdrop = backdrop

	# Outer margin so content doesn't kiss the frame edge.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	# Title bar — big readable Minecraft-style header.
	var title := Label.new()
	title.text = " PLECAK "
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	content.add_child(title)

	# Two-column body: inventory grid (left) + crafting recipes (right).
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	content.add_child(body)

	# LEFT: Backpack (4-col grid of fixed 64×64 slots — empty cells stay
	# visible as dark framed boxes so the layout reads as a stable grid).
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	body.add_child(left_col)

	var inv_label := Label.new()
	inv_label.text = "Przedmioty"
	inv_label.add_theme_font_size_override("font_size", 18)
	inv_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.96))
	left_col.add_child(inv_label)

	var grid := GridContainer.new()
	grid.name = "InventoryGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left_col.add_child(grid)
	_inventory_grid = grid

	# RIGHT: Crafting recipes — each one a wide button with label + cost.
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 8)
	body.add_child(right_col)

	var craft_label := Label.new()
	craft_label.text = "Wytwórz"
	craft_label.add_theme_font_size_override("font_size", 18)
	craft_label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.96))
	right_col.add_child(craft_label)

	var recipes := VBoxContainer.new()
	recipes.name = "CraftRecipes"
	recipes.add_theme_constant_override("separation", 6)
	right_col.add_child(recipes)
	_craft_recipe_list = recipes
	for recipe_id in SANDBOX_RECIPES.keys():
		var recipe: Dictionary = SANDBOX_RECIPES[recipe_id]
		var button := Button.new()
		button.name = "Craft_%s" % recipe_id
		button.text = String(recipe.get("label", recipe_id))
		button.custom_minimum_size = Vector2(220, 48)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("normal", _inventory_button_style(Color(0.16, 0.22, 0.28), 0.96))
		button.add_theme_stylebox_override("hover", _inventory_button_style(Color(0.26, 0.38, 0.46), 1.0))
		button.add_theme_stylebox_override("pressed", _inventory_button_style(Color(0.12, 0.18, 0.24), 1.0))
		button.add_theme_stylebox_override("disabled", _inventory_button_style(Color(0.10, 0.12, 0.14), 0.7))
		button.focus_mode = Control.FOCUS_CLICK
		button.pressed.connect(func() -> void: _craft_inventory_recipe(recipe_id))
		recipes.add_child(button)

	# Creative catalog — collapsed under crafting, smaller 5-col grid.
	var creative_label := Label.new()
	creative_label.text = "Kreatywnie"
	creative_label.add_theme_font_size_override("font_size", 16)
	creative_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.92))
	right_col.add_child(creative_label)

	var creative_grid := GridContainer.new()
	creative_grid.name = "CreativeCatalog"
	creative_grid.columns = 5
	creative_grid.add_theme_constant_override("h_separation", 4)
	creative_grid.add_theme_constant_override("v_separation", 4)
	right_col.add_child(creative_grid)
	for item_id in _creative_catalog_item_ids():
		var item_button := TextureButton.new()
		item_button.name = "Creative_%s" % item_id
		item_button.custom_minimum_size = Vector2(46, 46)
		item_button.texture_normal = _inventory_texture_for(item_id)
		item_button.tooltip_text = _pretty_item_name(item_id)
		item_button.ignore_texture_size = true
		item_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		item_button.pressed.connect(func() -> void: _select_creative_catalog_item(item_id))
		creative_grid.add_child(item_button)

	# Footer hint — single line, centered.
	var close_hint := Label.new()
	close_hint.text = "I — zamknij  •  Kliknij przedmiot, aby wybrać"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 14)
	close_hint.modulate = Color(0.78, 0.86, 0.90)
	content.add_child(close_hint)
	_refresh_inventory_overlay(_get_inventory())


## Stylebox for the inventory modal outer frame — dark wood-tone panel with
## a subtle inner border so it reads as a contained UI surface like Minecraft's
## inventory window.
func _inventory_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.20, 0.97)
	style.set_border_width_all(3)
	style.border_color = Color(0.30, 0.22, 0.16, 1.0)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(6)
	return style


## Stylebox for craft buttons — flat colored, no gradient, no glow. Same
## restrained palette Minecraft uses for its survival inventory buttons.
func _inventory_button_style(base_color: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(base_color.r, base_color.g, base_color.b, alpha)
	style.set_border_width_all(1)
	style.border_color = Color(0.08, 0.10, 0.12, alpha)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(4)
	return style


## Stylebox for one inventory slot — dark recessed cell with a faint top
## highlight, matching the visual rhythm of a Minecraft inventory grid.
func _inventory_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.13, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.18, 0.22, 0.26, 1.0)
	style.set_corner_radius_all(3)
	return style


func _refresh_inventory_overlay(inventory: Dictionary) -> void:
	if _inventory_grid == null:
		return
	for child in _inventory_grid.get_children():
		child.queue_free()
	# Always render 16 slots (4x4 grid) — empty cells show as dark framed
	# cells so the layout reads as a stable inventory like Minecraft's.
	var item_ids := inventory.keys().filter(func(id): return int(inventory[id]) > 0)
	const SLOT_COUNT := 16
	for i in range(SLOT_COUNT):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.add_theme_stylebox_override("panel", _inventory_slot_style())
		slot.tooltip_text = ""
		if i < item_ids.size():
			var item_id := String(item_ids[i])
			var count := int(inventory[item_id])
			slot.tooltip_text = "%s ×%d" % [_pretty_item_name(item_id), count]
			var icon := TextureRect.new()
			icon.texture = _inventory_texture_for(item_id)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 8
			icon.offset_top = 8
			icon.offset_right = -8
			icon.offset_bottom = -8
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
			if count > 1:
				var badge := Label.new()
				badge.text = "×%d" % count
				badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				badge.set_anchors_preset(Control.PRESET_FULL_RECT)
				badge.add_theme_font_size_override("font_size", 16)
				badge.add_theme_color_override("font_color", Color.WHITE)
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(badge)
		_inventory_grid.add_child(slot)
	if _craft_recipe_list != null:
		for child in _craft_recipe_list.get_children():
			var button := child as Button
			if button == null:
				continue
			var recipe_id := String(button.name).trim_prefix("Craft_")
			button.disabled = not _has_recipe_materials(recipe_id, inventory)


func _toggle_inventory_overlay() -> void:
	if _inventory_overlay == null:
		return
	_inventory_open = not _inventory_open
	_inventory_overlay.visible = _inventory_open
	if _inventory_backdrop != null:
		_inventory_backdrop.visible = _inventory_open
	if _player_controller != null and _player_controller.has_method("set_input_disabled"):
		_player_controller.set_input_disabled(_inventory_open)
	# Mouse cursor visible whenever the panel is open so the child can click
	# slots; captured (gameplay mode) when closed.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if _inventory_open else Input.MOUSE_MODE_CAPTURED)
	if _inventory_open:
		_refresh_inventory_overlay(_get_inventory())


func _creative_catalog_item_ids() -> Array[String]:
	var item_ids: Array[String] = ["tool_axe", "tool_pickaxe"]
	for kind_variant in BlockKind.default_catalog():
		var kind := kind_variant as BlockKind
		if kind != null:
			item_ids.append(kind.block_id)
	return item_ids


func _select_creative_catalog_item(item_id: String) -> void:
	_select_creative_catalog_item_for(_player_controller, item_id)


## Co-op seam: creative selection is player-local while the selected blocks,
## resources and world grid remain shared by this runtime.
func _select_creative_catalog_item_for(actor: PlayerController, item_id: String) -> void:
	if actor != null and is_instance_valid(actor) and actor.has_method("select_creative_item"):
		actor.select_creative_item(item_id)


func _has_recipe_materials(recipe_id: String, inventory: Dictionary = {}) -> bool:
	var recipe: Dictionary = SANDBOX_RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		return false
	var available := inventory if not inventory.is_empty() else _get_inventory()
	var needs: Dictionary = recipe.get("needs", {})
	for item_id in needs:
		if int(available.get(item_id, 0)) < int(needs[item_id]):
			return false
	return true


func _craft_inventory_recipe(recipe_id: String) -> void:
	_craft_inventory_recipe_for(_player_controller, recipe_id)


## Co-op seam: recipes debit the one shared backpack, but healing, feedback and
## sound originate from the child who pressed the craft button.
func _craft_inventory_recipe_for(actor: PlayerController, recipe_id: String) -> bool:
	var inventory := _get_inventory()
	if not _has_recipe_materials(recipe_id, inventory):
		_interaction_feedback("Brakuje składników.")
		return false
	var recipe: Dictionary = SANDBOX_RECIPES[recipe_id]
	var needs: Dictionary = recipe.get("needs", {})
	var gives: Dictionary = recipe.get("gives", {})
	for item_id in needs:
		inventory[item_id] = int(inventory.get(item_id, 0)) - int(needs[item_id])
	for item_id in gives:
		inventory[item_id] = int(inventory.get(item_id, 0)) + int(gives[item_id])
	_commit_inventory(inventory, recipe_id)
	if recipe_id == "stick":
		_apply_tier_for(actor, 1, "Patyk", 7, inventory)
	elif recipe_id == "sword_iron":
		_apply_tier_for(actor, 2, "Żelazny miecz", 12, inventory)
	elif recipe_id == "meal" and actor != null and is_instance_valid(actor) and actor.get_health() != null:
		var health := actor.get_health()
		health.heal(20)
		actor.hp_changed.emit(health.current_hp, health.max_hp)
	if _audio_bus != null and actor != null and is_instance_valid(actor):
		_audio_bus.emit_sfx("collect", actor.global_position)
	_interaction_feedback("Gotowe: %s" % String(recipe.get("label", recipe_id)))
	return true


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
func _try_auto_upgrade_weapon(inv: Dictionary, actor: PlayerController = _player_controller) -> void:
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
		_apply_tier_for(actor, next_idx, tier_res.display_name, tier_res.weapon_damage, inv)
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
	_apply_tier_for(actor, _current_weapon_index + 1, String(next_tier.get("label", "")),
		int(next_tier.get("damage", 4)), inv)


func _apply_tier(index: int, label: String, damage: int, inv: Dictionary) -> void:
	_apply_tier_for(_player_controller, index, label, damage, inv)


## Weapon tier ownership is visual and mechanical per local child. The recipe
## inventory itself stays shared, so one player can gather while the other
## crafts, without teleporting the newly crafted tool into P1's hand.
func _apply_tier_for(actor: PlayerController, index: int, label: String, damage: int, inv: Dictionary) -> void:
	if _rules_runtime != null:
		_rules_runtime.set_context_value("inventory", inv)
	_current_weapon_index = index
	if actor != null and is_instance_valid(actor) and actor.has_method("equip_weapon_damage"):
		actor.equip_weapon_damage(damage)
	if actor != null and is_instance_valid(actor) and actor.has_method("set_weapon_visual"):
		actor.set_weapon_visual(String(_weapon_tiers[index].get("id", "")))
	if _weapon_label != null:
		_weapon_label.text = "%s" % label
	if _screen_feedback != null:
		_screen_feedback.flash(Color(1.0, 0.95, 0.4), 0.3)
	if _effect_spawner != null and actor != null and is_instance_valid(actor):
		_effect_spawner.spawn_sparkle_burst(actor.global_position)
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
	var slots: Array = []
	var hotbar_items: Array = []
	if _player_controller != null and _player_controller.has_method("get_hotbar_items"):
		hotbar_items = _player_controller.get_hotbar_items()
	if hotbar_items.is_empty():
		hotbar_items = ["tool_axe", "tool_pickaxe", "grass", "wood_oak", "stone"]
	for item_variant in hotbar_items:
		var item_id := String(item_variant)
		var label := item_id.capitalize().replace("_", " ")
		if item_id == "tool_axe": label = "Siekiera"
		elif item_id == "tool_pickaxe": label = "Kilof"
		elif item_id == "fist": label = _current_weapon_label()
		slots.append({"id": item_id, "name": label})
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
		# The hotbar is picture-first for children who cannot read. Keyboard and
		# accessibility names remain available through the non-rendered tooltip;
		# the visible numeric overlay made every otherwise-icon-led slot feel like
		# a debug control legend in the captured Adventure opening.
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
	if entry_id == "tool_axe":
		return HUD_ICON_AXE
	if entry_id == "tool_pickaxe":
		return HUD_ICON_PICKAXE
	if entry_id == "fist" or entry_id == "weapon":
		return HUD_ICON_HAMMER
	match entry_id:
		"grass", "dirt", "sand": return HUD_ICON_GRASS
		"wood_oak", "wood": return HUD_ICON_WOOD
		"stone", "brick_red", "brick": return HUD_ICON_STONE
		_: return HUD_ICON_HAMMER


func _on_hotbar_changed(active_slot: int, _block_id: String) -> void:
	_rebuild_hotbar_panel(active_slot)


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	if _hp_meter == null:
		return
	if _stats_panel != null:
		# Do not occupy the opening with an unexplained empty dashboard. Health
		# appears when it matters—after an encounter has actually hurt the child.
		_stats_panel.visible = current < max_hp
	# Visual ramp: the radial ring also loses pips, so low health remains clear
	# even when the player cannot distinguish its green/amber/red colour.
	var ratio: float = float(current) / float(maxi(max_hp, 1))
	var accent := Color(0.46, 0.94, 0.58)
	if ratio < 0.3:
		accent = Color(1.0, 0.42, 0.38)
	elif ratio < 0.6:
		accent = Color(1.0, 0.76, 0.34)
	if _hp_meter.has_method("set_vitality"):
		_hp_meter.call("set_vitality", ratio, accent)


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


## A large sandbox should be easy to get lost in, never easy to get stranded
## in. This optional camp return is image-led in the compact menu and does not
## reset inventory, placed blocks, progression, or the saved world.
func _return_player_to_camp() -> void:
	if _world_renderer == null or _player_controller == null:
		return
	if _active_vehicle != null and is_instance_valid(_active_vehicle):
		_active_vehicle.exit_vehicle()
	var camp_position := _world_renderer.get_spawn_position(0) + Vector3(0.0, 0.10, 0.0)
	_player_controller.spawn_at(camp_position)
	_world_renderer.set_exploration_focus(camp_position)
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(camp_position + Vector3.UP * 0.8)


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
	# This is an infrequent escape/customization utility, not a primary HUD
	# element. Keep it intentionally quieter and smaller than the world-facing
	# image hotbar so the opening reads as a game scene rather than an editor.
	menu.offset_left = 20
	menu.offset_top = 20
	menu.offset_right = 60
	menu.offset_bottom = 60
	menu.add_theme_stylebox_override("normal", _hud_panel_style(Color(0.22, 0.32, 0.38), 0.62))
	menu.add_theme_stylebox_override("hover", _hud_panel_style(Color(0.38, 0.58, 0.66), 0.88))
	menu.add_theme_stylebox_override("pressed", _hud_panel_style(Color(0.16, 0.26, 0.32), 0.90))
	menu.add_theme_stylebox_override("focus", _hud_panel_style(Color(1.0, 0.86, 0.38), 0.96))
	var menu_popup := menu.get_popup()
	menu_popup.add_icon_item(HUD_ICON_STAR, "Wygląd postaci", 1)
	menu_popup.add_icon_item(HUD_ICON_CAMP, "Wróć do obozu", 2)
	menu_popup.add_icon_item(HUD_ICON_RETURN, "Wróć do menu", 3)
	menu_popup.id_pressed.connect(func(id: int) -> void:
		if id == 1:
			_on_customize_pressed()
		elif id == 2:
			_return_player_to_camp()
		elif id == 3:
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

	# Inventory / crafting panel toggle — sits next to the undo button so the
	# kid sees both as primary in-world controls. Opens the same overlay that
	# the I key binds to; the panel already includes the crafting recipes.
	var inv_btn := _make_hud_icon_button("InventoryBtn", HUD_ICON_BEDROLL, "Plecak i rzemiosło (I)", Color(0.42, 0.78, 0.72))
	inv_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	inv_btn.offset_left = 148
	inv_btn.offset_top = 28
	inv_btn.offset_right = 200
	inv_btn.offset_bottom = 80
	inv_btn.pressed.connect(_toggle_inventory_overlay)
	hud.add_child(inv_btn)

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

	# Emergency vitality only. The old rectangular status dashboard contained
	# score, XP and level text that read as a debug overlay and obscured scenery.
	# A compact pictorial ring appears only when the child has actually taken
	# damage; inventory/progression still updates in the background.
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	_stats_panel = stats_panel
	stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats_panel.offset_left = -112
	stats_panel.offset_top = 20
	stats_panel.offset_right = -20
	stats_panel.offset_bottom = 112
	stats_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.16, 0.30, 0.44), 0.72))
	stats_panel.visible = false
	hud.add_child(stats_panel)

	_hp_meter = PICTORIAL_VITALITY_METER.new() as Control
	_hp_meter.name = "PictorialVitalityMeter"
	_hp_meter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_meter.offset_left = 8
	_hp_meter.offset_top = 8
	_hp_meter.offset_right = -8
	_hp_meter.offset_bottom = -8
	stats_panel.add_child(_hp_meter)
	var vitality_icon := TextureRect.new()
	vitality_icon.name = "VitalityStar"
	vitality_icon.texture = HUD_ICON_STAR
	vitality_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vitality_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vitality_icon.set_anchors_preset(Control.PRESET_CENTER)
	vitality_icon.position = Vector2(28, 28)
	vitality_icon.size = Vector2(28, 28)
	vitality_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_child(vitality_icon)
	if _hp_meter.has_method("set_vitality"):
		_hp_meter.call("set_vitality", 1.0, Color(0.46, 0.94, 0.58))

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
	_build_inventory_overlay(hud)

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
	_interaction_prompt_panel.offset_left = -58
	_interaction_prompt_panel.offset_top = -178
	_interaction_prompt_panel.offset_right = 58
	_interaction_prompt_panel.offset_bottom = -70
	_interaction_prompt_panel.visible = false
	_interaction_prompt_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.22, 0.64, 0.42), 0.78))
	var prompt_content := Control.new()
	prompt_content.custom_minimum_size = Vector2(116, 108)
	_interaction_prompt_panel.add_child(prompt_content)
	var prompt_action_back := TextureRect.new()
	prompt_action_back.name = "InteractionActionBackdrop"
	prompt_action_back.texture = HUD_ACTION_GREEN
	prompt_action_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prompt_action_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prompt_action_back.position = Vector2(19, 12)
	prompt_action_back.size = Vector2(78, 78)
	prompt_action_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_content.add_child(prompt_action_back)
	_interaction_prompt_icon = TextureRect.new()
	_interaction_prompt_icon.name = "InteractionIcon"
	_interaction_prompt_icon.texture = HUD_ICON_AXE
	_interaction_prompt_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_interaction_prompt_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_interaction_prompt_icon.position = Vector2(33, 26)
	_interaction_prompt_icon.size = Vector2(50, 50)
	_interaction_prompt_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_content.add_child(_interaction_prompt_icon)
	# Retain the text node for keyboard/screen-reader feedback and legacy input
	# seams, but never draw it in the child-facing sandbox HUD. The image badge
	# above communicates the action without turning the world into a task list.
	_interaction_prompt_label = Label.new()
	_interaction_prompt_label.name = "InteractionPromptLabel"
	_interaction_prompt_label.visible = false
	prompt_content.add_child(_interaction_prompt_label)
	hud.add_child(_interaction_prompt_panel)
	_build_sandbox_fart_hint(hud)


## A single playful discovery hint makes the optional G-key gag findable.
## It stays compact and quiet until used, then disappears immediately.
func _build_sandbox_fart_hint(hud: CanvasLayer) -> void:
	if hud == null or _sandbox_hint_panel != null:
		return
	_sandbox_hint_panel = PanelContainer.new()
	_sandbox_hint_panel.name = "SandboxFartHint"
	_sandbox_hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_sandbox_hint_panel.offset_left = 30
	_sandbox_hint_panel.offset_top = -96
	_sandbox_hint_panel.offset_right = 82
	_sandbox_hint_panel.offset_bottom = -44
	_sandbox_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sandbox_hint_panel.add_theme_stylebox_override("panel", _hud_panel_style(Color(0.52, 0.86, 0.67), 0.90))
	var hint_icon := TextureRect.new()
	hint_icon.name = "HintIcon"
	hint_icon.texture = HUD_ICON_SILLY_PUFF
	hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hint_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint_icon.offset_left = 5
	hint_icon.offset_top = 5
	hint_icon.offset_right = -5
	hint_icon.offset_bottom = -5
	hint_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sandbox_hint_panel.add_child(hint_icon)
	# The action must be legible before reading. Keep the keyboard binding as a
	# non-rendered tooltip for grown-ups and keyboard discovery, but expose only
	# the image in the child-facing HUD.
	hint_icon.tooltip_text = "Puf (G)"
	hud.add_child(_sandbox_hint_panel)
	
func _tick_world_interactions() -> void:
	if _interaction_prompt_panel == null:
		return
	if _active_vehicle != null and is_instance_valid(_active_vehicle):
		# Never let a proximity prompt replace this while the driver is hidden.
		# It stays readable for the entire ride, not only for the 1.8s feedback
		# flash used by ordinary interactions.
		if _interaction_prompt_icon != null:
			_interaction_prompt_icon.texture = HUD_ICON_RETURN
		if _interaction_prompt_label != null:
			_interaction_prompt_label.text = "E / Esc  Wyjdź z pojazdu"
		_interaction_prompt_panel.visible = true
		return
	if _world_renderer == null or _player_controller == null:
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
				var seat_position: Vector3 = _nearby_world_interactable.get_meta(
					"seat_position", _nearby_world_interactable.global_position) as Vector3
				_player_controller.play_sit_at(seat_position)
			_interaction_feedback("Chwila odpoczynku przy stole.")
		"gather_wood", "gather_stone":
			var required_tool := "tool_axe" if action == "gather_wood" else "tool_pickaxe"
			if _player_controller == null or not _player_controller.has_method("has_equipped_tool") \
				or not _player_controller.has_equipped_tool(required_tool):
				_interaction_feedback("Wybierz %s i uderz w zasób." % ("siekierę" if action == "gather_wood" else "kilof"))
				return
			_gather_world_resource(_nearby_world_interactable)
		"find_food":
			_collect_food_item(_nearby_world_interactable)
		"train_jump", "train_run", "train_climb", "train_push", "train_pull", "train_balance":
			_start_training_session(_nearby_world_interactable)


func _interaction_feedback(message: String, action: String = "") -> void:
	if _interaction_prompt_label == null:
		return
	_interaction_prompt_label.text = message
	if not action.is_empty() and _interaction_prompt_icon != null:
		_interaction_prompt_icon.texture = _interaction_texture_for(action)
	_interaction_feedback_until = 1.8


func _interaction_texture_for(action: String) -> Texture2D:
	match action:
		"cook": return HUD_ICON_WORKBENCH
		"sit": return HUD_ICON_BEDROLL
		"door": return HUD_ICON_HAMMER
		"gather_wood": return HUD_ICON_AXE
		"gather_stone": return HUD_ICON_STONE
		"find_food": return HUD_ICON_AXE
		"train_jump", "train_run", "train_climb", "train_push", "train_pull", "train_balance": return HUD_ICON_STAR
		_: return HUD_ACTION_GREEN


## VS-025: Collect food item from world
func _collect_food_item(anchor: Node3D) -> void:
	if anchor == null or not is_instance_valid(anchor) or _nutrition_manager == null:
		return

	var item_id := String(anchor.get_meta("resource_item_id", ""))
	if item_id.is_empty():
		return

	## Get the food item from the FoodDatabase
	var food_item: FoodItem = _get_food_item_from_database(item_id)
	if food_item == null:
		push_warning("VS-025: Could not find food item for ID: %s" % item_id)
		return

	## Consume the food via NutritionManager
	if _nutrition_manager.eat_food(food_item):
		## Remove the visual
		var visual: Variant = anchor.get_meta("resource_visual", null)
		if visual != null and is_instance_valid(visual):
			visual.queue_free()

		## Remove the anchor
		anchor.queue_free()

		## Clear the nearby interactable reference
		_interaction_prompt_panel.visible = false
		_interaction_feedback_until = 0.0
		_nearby_world_interactable = null


## VS-025: Get FoodItem from FoodDatabase by item_id
func _get_food_item_from_database(item_id: String) -> FoodItem:
	## Try from WorldRenderer first
	if _world_renderer != null:
		var food_db: FoodDatabase = _world_renderer.get_food_database()
		if food_db != null:
			return food_db.get_food(item_id)

	## Fallback: create a new FoodDatabase instance
	var food_db_script = load("res://src/adapters/inbound/gameplay/food_database.gd")
	if food_db_script != null:
		var food_db_instance: FoodDatabase = food_db_script.new()
		if food_db_instance != null:
			food_db_instance._initialize_food_items()
			return food_db_instance.get_food(item_id)

	return null


## VS-025: Start training session at equipment
func _start_training_session(anchor: Node3D) -> void:
	if anchor == null or not is_instance_valid(anchor) or _training_manager == null:
		return

	var action := String(anchor.get_meta("interaction_action", ""))

	## Map action to TrainingType
	var training_type: TrainingStats.TrainingType
	match action:
		"train_jump": training_type = TrainingStats.TrainingType.STAMINA
		"train_run": training_type = TrainingStats.TrainingType.STAMINA
		"train_climb": training_type = TrainingStats.TrainingType.STRENGTH
		"train_push": training_type = TrainingStats.TrainingType.STRENGTH
		"train_pull": training_type = TrainingStats.TrainingType.POSTURE
		"train_balance": training_type = TrainingStats.TrainingType.AGILITY
		_: training_type = TrainingStats.TrainingType.STRENGTH

	## Start training via TrainingManager
	_training_manager.start_training(training_type, anchor)
	_interaction_prompt_panel.visible = false
	_interaction_feedback_until = 0.0
	_nearby_world_interactable = null


func _gather_world_resource(anchor: Node3D, actor: PlayerController = _player_controller) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var item_id := String(anchor.get_meta("resource_item_id", ""))
	if item_id.is_empty():
		return
	var inventory := _get_inventory()
	inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	_commit_inventory(inventory, item_id)
	if _rules_runtime != null:
		_rules_runtime.on_event("collect_%s" % item_id, {})
	_try_auto_upgrade_weapon(inventory, actor)
	if _audio_bus != null:
		var action := String(anchor.get_meta("resource_action", ""))
		var tool_sfx := "tool_axe_wood" if action == "gather_wood" else "tool_pickaxe_stone"
		_audio_bus.emit_sfx(tool_sfx, anchor.global_position)
		_audio_bus.emit_sfx("collect", anchor.global_position)
	if _effect_spawner != null:
		_effect_spawner.spawn_collect_effect(anchor.global_position)
	var visual_variant: Variant = anchor.get_meta("resource_visual") if anchor.has_meta("resource_visual") else null
	if visual_variant is Node and is_instance_valid(visual_variant):
		(visual_variant as Node).queue_free()
	anchor.remove_from_group("world_interactable")
	if _nearby_world_interactable == anchor:
		_nearby_world_interactable = null
	anchor.queue_free()
	_interaction_feedback("Zebrano!")


func _craft_home_meal() -> void:
	var inventory := _get_inventory()
	# The starter kitchen has a forgiving first recipe so the child can learn
	# the loop immediately; later meals consume an apple or gathered wood.
	var has_ingredient := int(inventory.get("apple", 0)) > 0 or int(inventory.get("wood_oak", 0)) > 0
	if has_ingredient:
		if int(inventory.get("apple", 0)) > 0:
			inventory["apple"] = int(inventory["apple"]) - 1
		else:
			inventory["wood_oak"] = int(inventory["wood_oak"]) - 1
	inventory["meal"] = int(inventory.get("meal", 0)) + 1
	_commit_inventory(inventory, "meal")
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
	_tick_adventure_music()
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
	_evidence_session_token += 1
	_cancel_opening_spawn_evidence()
	# Tear down Bella companion cleanly so a reused runtime doesn't carry her
	# into the next session or leak her GLB materials.
	if _companion_runtime != null and is_instance_valid(_companion_runtime):
		_companion_runtime.queue_free()
		_companion_runtime = null

	# VS-026: Snapshot sandbox state BEFORE teardown wipes it.
	# Cache into _sandbox_state so PlayShell / main.gd can persist it.
	_sandbox_state = get_sandbox_state()
	if _sandbox_state != null and not _sandbox_state.is_empty():
		print("[gameplay] VS-026: sandbox state captured (%d blocks, score=%d)" %
			[_sandbox_state.placed_blocks.size(), _sandbox_state.progression.score])
		session_save_requested.emit(_sandbox_state)

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
		_player_controller.set_physics_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Restore Main/Layout (NavBar + Body) so the kid sees Landing on return.
	_set_main_layout_visible(true)
	session_ended.emit()

func _input(event: InputEvent) -> void:
	# Once the child explicitly focuses the composer, the player controller is
	# already disabled via _on_npc_dialogue_input_focus_entered, so movement and
	# interaction keys cannot leak into the world. Do NOT call
	# set_input_as_handled() here — in Godot 4.6 that blocks the LineEdit's
	# own _gui_input dispatch and the typed letters never appear.
	if _npc_dialogue_panel != null and _npc_dialogue_panel.visible \
			and _npc_dialogue_input != null and not _npc_dialogue_input.has_focus() \
			and event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		_npc_dialogue_input.grab_focus()
		var dialogue_viewport := get_viewport()
		if dialogue_viewport != null:
			dialogue_viewport.set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		_toggle_inventory_overlay()
		get_viewport().set_input_as_handled()
		return
	# E is shared by generic interaction and vehicle egress. Runtime input runs
	# before dynamically spawned vehicle nodes, so consume egress first or E can
	# be swallowed by the generic interaction path and trap the player inside.
	if _active_vehicle != null and is_instance_valid(_active_vehicle) \
		and event.is_action_pressed("exit_vehicle"):
		_active_vehicle.exit_vehicle()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if Input.is_action_pressed("interact"):
		_activate_world_interaction()
		get_viewport().set_input_as_handled()
		return
	if Input.is_action_pressed("ui_cancel"):
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
	if _sandbox_hint_panel != null and is_instance_valid(_sandbox_hint_panel):
		_sandbox_hint_panel.visible = false
	if _audio_bus != null:
		_audio_bus.emit_sfx("fart_cc0_short", effect_origin)
	if _effect_spawner != null:
		_effect_spawner.spawn_stink_cloud(effect_origin)
	if _npc_root == null:
		return
	# Do not build an ever-growing second social queue when the kid presses G
	# again before the current group has had its short turn.
	if _npc_reaction_queue_active:
		return
	var spoken_reaction_count := 0
	for npc_variant in _npc_root.get_children():
		var npc_root := npc_variant as Node3D
		if npc_root == null or npc_root.global_position.distance_to(effect_origin) > SILLY_FART_REACTION_RANGE:
			continue
		var reaction := _fart_reaction_for(npc_root)
		# Everyone nearby visibly says their own short line at once in the world.
		# Only the voice/caption channel is serialized below.
		_match_npc_fart_animation(npc_root, String(reaction.action))
		_show_npc_reaction_bubble(npc_root, String(reaction.line))
		if spoken_reaction_count < SILLY_FART_MAX_SPOKEN_REACTIONS:
			_queue_npc_reaction(npc_root, reaction)
			spoken_reaction_count += 1


## Every NPC in range gets an in-character line. The queue deliberately owns
## the single shared subtitle/voice channel so a crowd does not talk over or
## mute itself. If another fart happens while these reactions are playing, its
## visible effect still runs but its social beat waits behind the first group.
func _queue_npc_reaction(npc_root: Node3D, reaction: Dictionary) -> void:
	if npc_root == null:
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
	await _wait_for_normal_npc_voice()
	while not _npc_reaction_queue.is_empty():
		var turn: Dictionary = _npc_reaction_queue.pop_front()
		var npc_ref := turn.get("npc", null) as WeakRef
		var npc_root := npc_ref.get_ref() as Node3D if npc_ref != null else null
		if npc_root == null or not is_instance_valid(npc_root):
			continue
		var line := String(turn.get("line", ""))
		var name_pl := String(turn.get("name_pl", "Ktoś"))
		_animate_npc_speech(String(turn.get("npc_id", "")), line, int(turn.get("emotion", FacialPerformance.Emotion.HAPPY)))
		_active_npc_reaction_line = line
		_active_npc_reaction_name = name_pl
		_active_npc_reaction_request_id = int(turn.get("request_id", -1))
		_active_npc_reaction_audio_started = false
		_active_npc_reaction_audio_finished = false
		_active_npc_reaction_audio_skipped = false
		if (_npc_voice != null and _npc_voice.is_available()) or LOCAL_NPC_VOICE_STREAMS.has(line):
			# The caption waits for playback_started; it cannot get ahead of a
			# slow ElevenLabs synthesis or replace an audible previous line.
			_speak_npc_line(line, _active_npc_reaction_request_id)
			var voice_deadline_msec := Time.get_ticks_msec() + int(SILLY_FART_VOICE_TIMEOUT_SECONDS * 1000.0)
			while not _active_npc_reaction_audio_finished and is_inside_tree():
				if Time.get_ticks_msec() >= voice_deadline_msec:
					# HTTPRequest also owns a timeout, but retain a runtime circuit
					# breaker so a misbehaving custom adapter cannot stall the world.
					_cancel_active_npc_voice()
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


func _wait_for_normal_npc_voice() -> void:
	if not _normal_npc_voice_active:
		return
	var deadline_msec := Time.get_ticks_msec() + int(NORMAL_NPC_VOICE_TIMEOUT_SECONDS * 1000.0)
	while _normal_npc_voice_active and is_inside_tree():
		if Time.get_ticks_msec() >= deadline_msec:
			# The adapter itself is timed, but do not let a broken custom adapter
			# block the social channel forever.
			_cancel_active_npc_voice()
			_normal_npc_voice_active = false
			_normal_npc_voice_request_id = -1
			_normal_npc_voice_line = ""
			break
		await get_tree().process_frame


func _on_npc_voice_playback_started(line: String, request_id: int = 0) -> void:
	if _normal_npc_voice_active and _normal_npc_voice_line == line and _normal_npc_voice_request_id == request_id:
		return
	if _active_npc_reaction_line != line or _active_npc_reaction_request_id != request_id:
		return
	_active_npc_reaction_audio_started = true
	_show_npc_dialogue(_active_npc_reaction_name, line, false)


func _on_npc_voice_playback_finished(line: String, request_id: int = 0) -> void:
	if _normal_npc_voice_active and _normal_npc_voice_line == line and _normal_npc_voice_request_id == request_id:
		_normal_npc_voice_active = false
		_normal_npc_voice_request_id = -1
		_normal_npc_voice_line = ""
		return
	if _active_npc_reaction_line == line and _active_npc_reaction_request_id == request_id:
		_active_npc_reaction_audio_finished = true


func _on_npc_voice_playback_skipped(line: String, request_id: int = 0) -> void:
	if _normal_npc_voice_active and _normal_npc_voice_line == line and _normal_npc_voice_request_id == request_id:
		if _play_local_npc_voice(line, request_id):
			return
		_normal_npc_voice_active = false
		_normal_npc_voice_request_id = -1
		_normal_npc_voice_line = ""
		return
	if _active_npc_reaction_line == line and _active_npc_reaction_request_id == request_id:
		if _play_local_npc_voice(line, request_id):
			return
		_active_npc_reaction_audio_skipped = true
		_active_npc_reaction_audio_finished = true


func _fart_reaction_for(npc_root: Node3D) -> Dictionary:
	var role := String(npc_root.get_meta("npc_role", ""))
	var authored: Variant = npc_root.get_meta("fart_reaction", {})
	if authored is Dictionary:
		var authored_reaction: Dictionary = (authored as Dictionary).duplicate(true)
		var line := String(authored_reaction.get("line_pl", authored_reaction.get("line", ""))).strip_edges()
		var action := String(authored_reaction.get("action", "laugh"))
		# A combat-off character remains a peaceful guide. Never surface even a
		# pretend strike after the parental policy has downgraded their role.
		if action == "swat" and role != NPCCharacter.ROLE_HOSTILE:
			return {"line": "Uff! Ten podmuch mnie zaskoczył — wolę spokojne powietrze.", "emotion": FacialPerformance.Emotion.SURPRISED, "action": "recoil"}
		if not line.is_empty():
			return {
				"line": line,
				"emotion": _fart_emotion_from_string(String(authored_reaction.get("emotion", "happy"))),
				"action": action,
			}
	if role == NPCCharacter.ROLE_VENDOR:
		return {"line": "Fuj! Otwarte okno i świeże powietrze, natychmiast!", "emotion": FacialPerformance.Emotion.SURPRISED, "action": "recoil"}
	if role == NPCCharacter.ROLE_HOSTILE:
		return {"line": "Ej! To wcale nie jest śmieszne — masz jedno ostrzeżenie!", "emotion": FacialPerformance.Emotion.ANGRY, "action": "swat"}
	return {"line": "Haha! To był mały wiaterek, ale wielka historia!", "emotion": FacialPerformance.Emotion.HAPPY, "action": "laugh"}


func _fart_emotion_from_string(value: String) -> int:
	match value.to_lower():
		"angry": return FacialPerformance.Emotion.ANGRY
		"surprised": return FacialPerformance.Emotion.SURPRISED
		"sad", "hurt": return FacialPerformance.Emotion.HURT
		_: return FacialPerformance.Emotion.HAPPY


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
	var generation := int(npc_root.get_meta("fart_bubble_generation", 0)) + 1
	npc_root.set_meta("fart_bubble_generation", generation)
	var tree := get_tree()
	if tree == null:
		return
	# Keep a weak reference: streamed NPCs can be freed before the timeout and
	# a lambda must never retain (or dereference) their old speech bubble.
	var bubble_ref: WeakRef = weakref(bubble)
	var npc_ref: WeakRef = weakref(npc_root)
	tree.create_timer(2.8).timeout.connect(func() -> void:
		var captured_bubble: Label3D = bubble_ref.get_ref() as Label3D
		var captured_npc: Node3D = npc_ref.get_ref() as Node3D
		if captured_bubble != null and is_instance_valid(captured_bubble) and captured_npc != null and is_instance_valid(captured_npc) and int(captured_npc.get_meta("fart_bubble_generation", 0)) == generation:
			captured_bubble.visible = false)


func _match_npc_fart_animation(npc_root: Node3D, action: String) -> void:
	var visual := npc_root.get_child(0) as Node3D if npc_root.get_child_count() > 0 else null
	if visual == null:
		return
	var original_yaw := visual.rotation.y
	var tween := create_tween()
	match action:
		"swat":
			# Prefer an actual right-arm air-swat. Kenney rigs expose arm-right;
			# keep the planted-foot yaw only as a fallback for non-humanoid NPCs.
			if not _tween_npc_air_swat_arm(visual, tween):
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


func _tween_npc_air_swat_arm(visual: Node3D, tween: Tween) -> bool:
	var arm := visual.find_child("arm-right", true, false) as Node3D
	if arm == null:
		return false
	var original_roll := arm.rotation.z
	tween.tween_property(arm, "rotation:z", original_roll - 0.72, 0.10)
	tween.tween_property(arm, "rotation:z", original_roll + 0.16, 0.12)
	tween.tween_property(arm, "rotation:z", original_roll, 0.16)
	return true

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
		_customization = FilesystemCharacterCustomizationStore.load_customization()
	_player_controller.apply_customization(_customization)


func _on_customize_pressed() -> void:
	if _customization_panel != null and is_instance_valid(_customization_panel):
		_close_customization_panel()
		return
	if _customization == null:
		_customization = FilesystemCharacterCustomizationStore.load_customization()
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
	# A deliberate swatch choice opts out of the authored first-run wardrobe;
	# persist that choice so a new session cannot silently overwrite it.
	c.use_signature_outfit = false
	_customization = c
	if _player_controller != null and _player_controller.has_method("apply_customization"):
		_player_controller.apply_customization(c)
	FilesystemCharacterCustomizationStore.save_customization(c)


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


func _schedule_opening_spawn_evidence() -> void:
	_cancel_opening_spawn_evidence()
	var session_token := _evidence_session_token
	var attempts := 0
	var settle_timer := Timer.new()
	_opening_evidence_timer = settle_timer
	settle_timer.wait_time = 0.25
	settle_timer.one_shot = false
	settle_timer.timeout.connect(func() -> void:
		if session_token != _evidence_session_token or _session == null or _opening_evidence_timer != settle_timer:
			settle_timer.stop()
			settle_timer.queue_free()
			return
		attempts += 1
		if _world_renderer != null and _world_renderer.is_opening_generation_settled():
			settle_timer.stop()
			settle_timer.queue_free()
			_opening_evidence_timer = null
			_trigger_evidence_capture(1) # SPAWN
		elif attempts % 32 == 0:
			# An incomplete streamed frame is diagnostic information, never visual
			# acceptance evidence. Keep waiting on slower hardware instead of
			# falsely labelling the eight-second timeout as a settled opening.
			push_warning("Opening evidence is waiting for streamed world generation (%d checks)" % attempts)
	)
	add_child(settle_timer)
	settle_timer.start()


func _cancel_opening_spawn_evidence() -> void:
	if _opening_evidence_timer != null and is_instance_valid(_opening_evidence_timer):
		_opening_evidence_timer.stop()
		_opening_evidence_timer.queue_free()
	_opening_evidence_timer = null


## Update ambient particles based on reduce-motion setting
func _update_ambient_particles_from_reduce_motion() -> void:
	if _ambient_particles != null:
		_ambient_particles.emitting = not _is_reduce_motion_enabled()
