class_name GameplayRuntime
extends Node3D

signal session_ended
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
var _build_grid: BuildGrid
var _hotbar_panel: HBoxContainer

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


func start_session(world: World, session: Session) -> void:
	_session = session
	_score = 0
	var t0 := Time.get_ticks_msec()
	print("[gameplay] start_session: world=%s nodes=%d rules=%d" %
		[world.world_id, world.scene_nodes.size(), world.game_rules.size()])
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
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Hide Main/Layout so the NavBar (top tabs) and other UI don't overlap the
	# HUD overlay added below. Gameplay is full-screen 3D + HUD only.
	# gameplay_runtime is rooted at scene-tree root so it stays visible.
	_set_main_layout_visible(false)
	print("[gameplay] session live in %d ms total" % (Time.get_ticks_msec() - t0))


## Hide / restore the InboundMain Layout (NavBar + Body) for fullscreen
## gameplay. Looks up the node by absolute path so we don't take a hard
## dependency on InboundMain from this Node3D.
func _set_main_layout_visible(value: bool) -> void:
	var layout := get_node_or_null("/root/Main/Layout")
	if layout != null:
		layout.visible = value

	# Spawn sparkle at player spawn
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(_player_controller.global_position)

	# Connect trigger areas
	for child in _world_renderer.get_children():
		if child is Area3D:
			if not child.body_entered.is_connected(_on_trigger_area_entered):
				child.body_entered.connect(_on_trigger_area_entered.bind(child))

	_build_hud()
	_spawn_starter_enemies()
	_setup_build_grid()


## Minecraft-lite voxel placement. Mounts a BuildGrid as a child of
## the gameplay runtime so blocks are siblings to enemies + world
## scenery. Player gets the grid reference for input handling.
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
func _spawn_starter_enemies() -> void:
	if _player_controller == null:
		return
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
	_enemy_root.add_child(enemy)
	enemy.global_position = pos


func _on_enemy_defeated(enemy_id: String, position: Vector3, loot: Array) -> void:
	print("[combat] defeated %s at %s loot=%s" % [enemy_id, position, loot])
	if _audio_bus != null:
		_audio_bus.emit_sfx("collect", position)
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(position)
	# Forward to rules engine — on_defeat_<enemy> events + inventory items.
	if _rules_runtime != null:
		_rules_runtime.on_event("defeat_%s" % enemy_id, {"enemy_id": enemy_id})
		var inv: Variant = _rules_runtime.get_context_value("inventory")
		var inv_dict: Dictionary = inv if inv is Dictionary else {}
		for drop in loot:
			if not (drop is Dictionary):
				continue
			var item := String((drop as Dictionary).get("item_id", ""))
			var qty := int((drop as Dictionary).get("quantity", 0))
			if item == "":
				continue
			inv_dict[item] = int(inv_dict.get(item, 0)) + qty
			_rules_runtime.on_event("inventory_changed", {"item": item})
			_rules_runtime.on_event("collect_%s" % item, {})
		_rules_runtime.set_context_value("inventory", inv_dict)
	# Default scoring fallback (works even without compiled rules).
	_score += 5
	if _score_label != null:
		_score_label.text = "★ %d" % _score


func _rebuild_hotbar_panel(active_slot: int) -> void:
	if _hotbar_panel == null:
		return
	for child in _hotbar_panel.get_children():
		child.queue_free()
	var catalog := BlockKind.default_catalog()
	for i in mini(catalog.size(), 5):
		var kind: BlockKind = catalog[i]
		var slot := ColorRect.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.color = kind.color
		# Active slot gets a bright outline via theme override on a wrapping
		# panel — cheap: just brighten the color.
		if i == active_slot:
			slot.color = kind.color.lightened(0.3)
		var label := Label.new()
		label.text = "%d" % (i + 1)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.position = Vector2(6, 4)
		slot.add_child(label)
		_hotbar_panel.add_child(slot)


func _on_hotbar_changed(active_slot: int, _block_id: String) -> void:
	_rebuild_hotbar_panel(active_slot)


func _on_player_hp_changed(current: int, max_hp: int) -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = max_hp
	_hp_bar.value = current


func _on_player_defeated() -> void:
	# Kid-safe defeat — soft fade + respawn at spawn point, no game-over.
	print("[combat] player defeated — soft respawn")
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

	# Wire HP signal from player.
	if _player_controller != null and _player_controller.has_signal("hp_changed"):
		_player_controller.hp_changed.connect(_on_player_hp_changed)
		_player_controller.player_defeated.connect(_on_player_defeated)

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
	hint.text = "WSAD ruch  •  SPACJA skok  •  LPM atak  •  K stawiaj  •  L niszcz  •  1-5 wybór  •  PPM obrót  •  ESC"
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
	match action_kind:
		0:  # ADD_SCORE
			var amount := int(params.get("amount", 0))
			_score += amount
			if _rules_runtime != null:
				_rules_runtime.set_context_value("score", _score)
			print("[gameplay] add_score(%d) -> %d (rule=%s)" % [amount, _score, rule_id])
		1:  # SPAWN_ITEM — deferred; logs only for MVP
			print("[gameplay] spawn_item(%s, %d) — not yet implemented" %
				[String(params.get("item", "")), int(params.get("count", 0))])
		2:  # WIN_LEVEL
			print("[gameplay] win_level fired (rule=%s)" % rule_id)
			_trigger_victory()
		3:  # UNLOCK_AREA
			print("[gameplay] unlock_area(%s) — deferred to BUILDER wave" %
				String(params.get("zone_id", "")))
		4:  # OPEN_GATE
			print("[gameplay] open_gate — deferred")
		5:  # SET_RESPAWN_POINT
			if _player_controller != null:
				_player_controller.set_meta("respawn_point",
					_player_controller.global_position)
		6:  # CUSTOM_CALLBACK
			print("[gameplay] custom_callback(%s) — deferred" %
				String(params.get("callback_name", "")))
		_:
			push_warning("Unknown action_kind: %d" % action_kind)


func end_session() -> void:
	_rules_active = false
	if _rules_runtime != null:
		_rules_runtime.reset()
	if _build_grid != null and is_instance_valid(_build_grid):
		_build_grid.clear_all()
	if _enemy_root != null and is_instance_valid(_enemy_root):
		for e in _enemy_root.get_children():
			if e is EnemyController:
				e.queue_free()
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
