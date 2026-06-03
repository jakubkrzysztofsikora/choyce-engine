class_name GameplayRuntime
extends Node3D

signal session_ended
## Emitted at session-end with the WinOutcome so HUD/celebration
## can branch on win vs. lose vs. reason. Always fires before
## session_ended for backwards-compat consumers.
signal session_outcome(outcome: WinOutcome)
## Emitted when a rule's action fires.
##   action_kind: int — CompiledRule.ActionKind value
##   params:      Dict — action params
signal rule_fired(rule_id: String, action_kind: int, params: Dictionary)

var _world_renderer: WorldRenderer
var _player_controller: PlayerController
var _session: Session
var _audio_bus: AudioEventBus
var _sfx_player: SFXPlayer
var _effect_spawner: EffectSpawner
var _screen_feedback: ScreenFeedback
var _victory_sequence: VictorySequence
var _ambient_player: AudioStreamPlayer

# Rules engine — injected by main.gd via setup_rules() before start_session.
# Optional: GameplayRuntime keeps working with null rules (legacy worlds).
var _rules_runtime: RulesRuntimePort
var _rule_compiler: RuleCompilerService
var _score: int = 0
var _rules_active: bool = false

# Combat HUD references — built lazily in _build_hud.
var _hp_bar: ProgressBar
var _score_label: Label
var _enemy_root: Node3D
var _loot_root: Node3D
var _build_grid: BuildGrid
var _hotbar_panel: HBoxContainer
var _inventory_panel: VBoxContainer
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
const WAVE_RESPAWN_DELAY := 6.0
## Kid falls below this y → soft-respawn. Fixes spring-launch
## softlock (Adv 2 H-5). Default world floor is y=0; -50 leaves a
## comfortable buffer for tall builds.
const FALL_KILL_PLANE_Y := -50.0

# Goal + lose-condition injection (Wave 3 W3-A/B). Populated by
# setup_goal() from main.gd composition root, sourced from the
# template pack's default_goal + lose_conditions. Null = legacy
# free-play mode (no win-screen, no lose, kid taps back).
var _goal: GameGoal = null
var _goal_evaluator: EvaluateGoalService = null
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
## Pass null `goal` for legacy free-play worlds — the runtime stays in
## collect-or-touch-win mode and emits an "abandoned" outcome on exit.
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
	var t0 := Time.get_ticks_msec()
	print("[gameplay] start_session: world=%s nodes=%d rules=%d" %
		[world.world_id, world.scene_nodes.size(), world.game_rules.size()])
	# Fan out to the Tauri shell (if registered) so the desktop UI can close
	# its world picker / show an in-session badge. No-op when shell bridge
	# is off (default).
	_notify_shell("notify_session_started", [world.world_id, _profile_id])
	_world_renderer.render_world(world)
	print("[gameplay] render_world done in %d ms" % (Time.get_ticks_msec() - t0))
	_register_world_rules(world)
	var spawn_pos := _world_renderer.get_spawn_position(0)
	_player_controller.spawn_at(spawn_pos + Vector3(0, 1, 0))
	_player_controller.visible = true
	_player_controller.set_process_input(true)
	_player_controller.set_process(true)
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
	_spawn_starter_enemies()
	_spawn_npcs()
	_setup_build_grid()

	print("[gameplay] session live in %d ms total" % (Time.get_ticks_msec() - t0))


## Hide / restore the InboundMain Layout (NavBar + Body) for fullscreen
## gameplay. Pure visibility toggle — session-init side effects moved
## back into start_session per Adv D code-quality review.
func _set_main_layout_visible(value: bool) -> void:
	var layout := get_node_or_null("/root/Main/Layout")
	if layout != null:
		layout.visible = value


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
	_seed_resource_nodes()


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
	if _rules_runtime != null:
		_rules_runtime.set_context_value("blocks_placed", _build_grid.block_count())
		_rules_runtime.on_event("place_block", {"kind": kind_id, "cell": cell})


func _on_block_removed(cell: Vector3i, kind_id: String) -> void:
	if _rules_runtime != null:
		_rules_runtime.set_context_value("blocks_placed", _build_grid.block_count())
		_rules_runtime.on_event("break_block", {"kind": kind_id, "cell": cell})


## MVP: spawn a small kid-safe enemy pack around the player so the
## 7yo Roblox-fluent kid has someone to fight from the moment the
## world loads. Procedural — no Kenney character meshes needed.
## Three enemies: 2 green slimes + 1 pink bouncer at 8m / 12m / 14m
## from spawn.
##
## Gated by ParentalControlPolicy.combat_enabled (Adv 2 TB-1 fix).
## When combat is off, the runtime stays in the legacy
## collect-and-touch-win mode — no enemies, no waves.
## Wave 3 W3-A3: spawn one visible NPC marker per roster entry around
## the player spawn. Each gets a capsule body + Area3D so walking up
## triggers the greeting bubble. Visuals are placeholder geometry
## (capsule + role-tinted material) so the kid sees a distinct
## character; KayKit/Quaternius rigs swap in a follow-up commit.
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
	# Arrange NPCs on a ring around the player so the kid sees a small
	# friendly crowd at spawn. Radius 6m is just outside arm's reach.
	var count: int = _npc_roster.size()
	for i in count:
		var npc_variant: Variant = _npc_roster[i]
		if not (npc_variant is NPCCharacter):
			continue
		var npc: NPCCharacter = npc_variant
		var angle := (TAU / float(count)) * float(i)
		var pos := origin + Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0)
		_spawn_one_npc(npc, pos)


## Spawn a single NPC marker: capsule mesh + collision + Area3D for
## the greeting trigger. Color encodes role so the kid can tell a
## guide (green) from a vendor (gold) from a (degraded) hostile (red).
func _spawn_one_npc(npc: NPCCharacter, pos: Vector3) -> void:
	var root := StaticBody3D.new()
	root.name = "npc_%s" % npc.npc_id
	root.global_position = pos
	root.set_meta("npc_id", npc.npc_id)
	root.set_meta("npc_name_pl", npc.name_pl)
	root.set_meta("greeting_pl", npc.line_for("greeting"))
	root.add_to_group("npcs")

	var capsule := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.height = 1.6
	mesh.radius = 0.35
	capsule.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color_for_role(npc.role)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.15
	capsule.material_override = mat
	root.add_child(capsule)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.6
	shape.radius = 0.35
	col.shape = shape
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

	_npc_root.add_child(root)


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
	_show_npc_dialogue(name_pl, greeting)


func _on_npc_trigger_exited(body: Node, npc_root: Node3D) -> void:
	if body != _player_controller:
		return
	var leaving_id: String = String(npc_root.get_meta("npc_id", ""))
	if leaving_id == _active_npc_id:
		_hide_npc_dialogue()
		_active_npc_id = ""


## Lazily build a single shared dialogue label at the bottom-center.
## Kept on the HUD CanvasLayer so it sits above 3D geometry.
func _show_npc_dialogue(name_pl: String, line_pl: String) -> void:
	if _npc_dialogue_label == null:
		_npc_dialogue_label = _build_npc_dialogue_label()
	if _npc_dialogue_label == null:
		return
	_npc_dialogue_label.text = "%s: %s" % [name_pl, line_pl]
	_npc_dialogue_label.visible = true


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

	_spawn_one(def_a, spawn + Vector3(8, 1, 0))
	_spawn_one(def_b, spawn + Vector3(-7, 1, 6))
	_spawn_one(def_c, spawn + Vector3(0, 1, 14))


func _spawn_one(def: EnemyDefinition, pos: Vector3) -> void:
	var enemy := EnemyController.new()
	enemy.add_to_group("enemies")
	# setup() before add_child so definition is non-null when _ready fires.
	enemy.setup(def, _player_controller)
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


func _on_enemy_damaged(amount: int, position: Vector3) -> void:
	# Cheap heuristic: amount ≥ 8 → likely against a boss (bigger HP
	# bar). Future: pass enemy_id through.
	var is_boss := amount >= 8
	_spawn_damage_number(amount, position, is_boss)
	# Adv Y C1 fix: hit-stop fires on EVERY hit-connect (35ms mob /
	# 60ms boss), not only on kill. This is the single biggest "yes I
	# hit it" signal — Mick Hofman / J.W. Nijman pattern.
	_apply_hit_stop(0.06 if is_boss else 0.035)
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
			_screen_feedback.shake_directional(6.0, 0.08, dir)
		elif _screen_feedback.has_method("shake"):
			_screen_feedback.shake(6.0, 0.08)
	# Adv Y C2 fix: real punch SFX, not the coin pickup chime.
	if _audio_bus != null:
		_audio_bus.emit_sfx("punch_thud", position)


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
		_score_label.text = "★ %d" % _score


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
			label = Label.new()
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
			label.add_theme_constant_override("shadow_offset_x", 2)
			label.add_theme_constant_override("shadow_offset_y", 2)
			_inventory_panel.add_child(label)
			_inventory_labels[item_id] = label
		label.text = "%s × %d" % [_pretty_item_name(item_id), count]


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
	if _weapon_label != null:
		_weapon_label.text = "🗡 %s (%d dmg)" % [label, damage]
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
		return "🗡 %s" % String(tier.get("label", "Pięść"))
	return "🗡 Pięść"


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
	# Slot 0 is the weapon (fist by default), slots 1-4 are first 4
	# blocks from the catalog. Matches PlayerController.setup_build_grid.
	# Show the PL display name on each tile so it's not "empty squares"
	# (user-reported bug).
	var catalog := BlockKind.default_catalog()
	var slots: Array = []
	# Weapon tile (slot 0) — label reflects current tier so kid sees
	# "🗡 Patyk" → "🗡 Żelazny miecz" etc. as they upgrade. Color
	# shifts toward gold for upgraded gear (Adv H #7 fix).
	var weapon_label := _current_weapon_label()
	var weapon_color := Color(0.7, 0.7, 0.8) if _current_weapon_index <= 0 else Color(0.95, 0.78, 0.32)
	slots.append({"id": "weapon", "name": weapon_label, "color": weapon_color})
	for i in mini(catalog.size(), 4):
		var kind: BlockKind = catalog[i]
		slots.append({"id": kind.block_id, "name": kind.display_name, "color": kind.color})
	# VoxelForge frame around each hotbar slot — black surface with
	# lime border, active slot pulses brighter yellow. Inner ColorRect
	# still shows the block tint so the kid can recognize materials.
	var voxel_lime := Color(0.639, 0.902, 0.208, 1)
	var voxel_yellow := Color(0.988, 0.882, 0.278, 1)
	for i in slots.size():
		var entry: Dictionary = slots[i]
		var slot_panel := PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(80, 80)
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.0, 0.0, 0.0, 0.92)
		frame.border_color = voxel_yellow if i == active_slot else voxel_lime
		frame.set_border_width_all(3 if i == active_slot else 2)
		frame.set_corner_radius_all(8)
		frame.shadow_color = Color(voxel_yellow.r, voxel_yellow.g, voxel_yellow.b, 0.30) if i == active_slot else Color(0, 0, 0, 0)
		frame.shadow_size = 8 if i == active_slot else 0
		frame.content_margin_left = 4
		frame.content_margin_top = 4
		frame.content_margin_right = 4
		frame.content_margin_bottom = 4
		slot_panel.add_theme_stylebox_override("panel", frame)
		var slot_bg := ColorRect.new()
		slot_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_bg.color = entry["color"]
		if i == active_slot:
			slot_bg.color = (entry["color"] as Color).lightened(0.3)
		slot_panel.add_child(slot_bg)
		# Number key hint top-left.
		var num_label := Label.new()
		num_label.text = "%d" % (i + 1)
		num_label.add_theme_font_size_override("font_size", 16)
		num_label.add_theme_color_override("font_color", Color.WHITE)
		num_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		num_label.add_theme_constant_override("shadow_offset_x", 2)
		num_label.add_theme_constant_override("shadow_offset_y", 2)
		num_label.position = Vector2(6, 4)
		num_label.size = Vector2(16, 18)
		num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(num_label)
		# Item name bottom — kid sees "Trawa" not "empty square".
		var name_label := Label.new()
		name_label.text = String(entry["name"])
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.anchor_left = 0
		name_label.anchor_right = 1
		name_label.anchor_top = 1
		name_label.anchor_bottom = 1
		name_label.offset_top = -22
		name_label.offset_left = 2
		name_label.offset_right = -2
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_panel.add_child(name_label)
		_hotbar_panel.add_child(slot_panel)


func _on_hotbar_changed(active_slot: int, _block_id: String) -> void:
	_rebuild_hotbar_panel(active_slot)


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	if _hp_bar == null:
		return
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
		_player_controller.spawn_at(spawn_pos + Vector3(0, 1, 0))
		if _player_controller.has_method("get_health"):
			var h: HealthState = _player_controller.get_health()
			if h != null:
				h.current_hp = h.max_hp
				h.is_alive = true
				_player_controller.hp_changed.emit(h.current_hp, h.max_hp)


## Kid-facing HUD: a Wróć button + control hint so a 5-7 year-old sees what to
## do after world load. Previously start_session hid PlayShell.Layout, left
## mouse captured, and gave no on-screen affordances — kid perceived a hang.
func _build_hud() -> void:
	if has_node("HUD"):
		return
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 5
	add_child(hud)

	var back := Button.new()
	back.name = "BackBtn"
	back.text = "← Wróć"
	back.custom_minimum_size = Vector2(160, 56)
	back.add_theme_font_size_override("font_size", 28)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 32
	back.offset_top = 32
	back.offset_right = 192
	back.offset_bottom = 88
	back.pressed.connect(end_session)
	hud.add_child(back)

	# HP bar + score panel (top-right). 7yo combat HUD.
	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stats_panel.offset_left = -240
	stats_panel.offset_top = 32
	stats_panel.offset_right = -32
	stats_panel.offset_bottom = 132
	hud.add_child(stats_panel)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_vbox)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HpBar"
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.custom_minimum_size = Vector2(180, 24)
	_hp_bar.add_theme_color_override("font_color", Color.WHITE)
	stats_vbox.add_child(_hp_bar)

	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.text = "★ 0"
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(1, 0.92, 0.4))
	_score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_score_label.add_theme_constant_override("shadow_offset_x", 2)
	_score_label.add_theme_constant_override("shadow_offset_y", 2)
	stats_vbox.add_child(_score_label)

	_weapon_label = Label.new()
	_weapon_label.name = "WeaponLabel"
	_weapon_label.text = "🗡 Pięść (4 dmg)"
	_weapon_label.add_theme_font_size_override("font_size", 18)
	_weapon_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_weapon_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_weapon_label.add_theme_constant_override("shadow_offset_x", 2)
	_weapon_label.add_theme_constant_override("shadow_offset_y", 2)
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
	stats_vbox.add_child(_xp_label)
	_refresh_xp_hud()

	# Inventory panel — bottom-left, lists collected items + counts.
	_inventory_panel = VBoxContainer.new()
	_inventory_panel.name = "Inventory"
	_inventory_panel.add_theme_constant_override("separation", 4)
	_inventory_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_inventory_panel.offset_left = 32
	_inventory_panel.offset_top = -260
	_inventory_panel.offset_right = 240
	_inventory_panel.offset_bottom = -110
	hud.add_child(_inventory_panel)
	var inv_title := Label.new()
	inv_title.text = "🎒 Plecak"
	inv_title.add_theme_font_size_override("font_size", 20)
	inv_title.add_theme_color_override("font_color", Color.WHITE)
	inv_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	inv_title.add_theme_constant_override("shadow_offset_x", 2)
	inv_title.add_theme_constant_override("shadow_offset_y", 2)
	_inventory_panel.add_child(inv_title)

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

	# Crosshair (center) — 16×16 reticle so kid sees where their
	# raycast lands. Tiny + low-contrast so it doesn't overwhelm the
	# 3D scene. CenterContainer keeps it locked to viewport center
	# regardless of resize. (Adv 5 #2 fix.)
	var crosshair_layer := CenterContainer.new()
	crosshair_layer.name = "CrosshairContainer"
	crosshair_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair_layer)
	var crosshair := ColorRect.new()
	crosshair.name = "Crosshair"
	crosshair.custom_minimum_size = Vector2(16, 16)
	# White cross drawn via two thin ColorRects (cheap; no PNG asset
	# needed for MVP). 2px thick, 16px wide.
	crosshair.color = Color(1, 1, 1, 0.0)  ## transparent root
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crosshair_h := ColorRect.new()
	crosshair_h.color = Color(1, 1, 1, 0.8)
	crosshair_h.position = Vector2(0, 7)
	crosshair_h.size = Vector2(16, 2)
	crosshair_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(crosshair_h)
	var crosshair_v := ColorRect.new()
	crosshair_v.color = Color(1, 1, 1, 0.8)
	crosshair_v.position = Vector2(7, 0)
	crosshair_v.size = Vector2(2, 16)
	crosshair_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(crosshair_v)
	crosshair_layer.add_child(crosshair)

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

	var hint := Label.new()
	hint.name = "ControlsHint"
	hint.text = "WSAD ruch  •  SPACJA skok  •  Myszka patrz  •  LPM atak/kop  •  1-5 wybór  •  ESC pokaż myszkę"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_left = -360
	hint.offset_top = 36
	hint.offset_right = 360
	hint.offset_bottom = 76
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(hint)

func _physics_process(delta: float) -> void:
	if _rules_active and _rules_runtime != null:
		_rules_runtime.tick(delta)
	_check_enemy_wave_respawn(delta)
	_check_fall_kill_plane()
	_session_elapsed_sec += delta
	_check_goal_and_lose()


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
	if event.is_action_pressed("ui_cancel"):
		# ESC: if cursor is captured (FPS look mode), release it so
		# kid can click HUD (back button, hotbar). Press ESC again
		# from HUD to actually exit the session. Two-press exit
		# prevents accidental quits during combat.
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			return
		end_session()

func _on_footstep() -> void:
	if _audio_bus != null:
		_audio_bus.emit_sfx("step", _player_controller.global_position)

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
	match trigger_type:
		"win":
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
