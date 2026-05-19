class_name GameplayRuntime
extends Node3D

signal session_ended

var _world_renderer: WorldRenderer
var _player_controller: PlayerController
var _session: Session
var _audio_bus: AudioEventBus
var _sfx_player: SFXPlayer
var _effect_spawner: EffectSpawner
var _screen_feedback: ScreenFeedback
var _victory_sequence: VictorySequence
var _ambient_player: AudioStreamPlayer

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

func start_session(world: World, session: Session) -> void:
	_session = session
	var t0 := Time.get_ticks_msec()
	print("[gameplay] start_session: world=%s nodes=%d" % [world.world_id, world.scene_nodes.size()])
	_world_renderer.render_world(world)
	print("[gameplay] render_world done in %d ms" % (Time.get_ticks_msec() - t0))
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

	var hint := Label.new()
	hint.name = "ControlsHint"
	hint.text = "← → ↑ ↓ poruszanie  •  SPACJA skok  •  ESC wyjście"
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

func end_session() -> void:
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

func _trigger_victory() -> void:
	if _victory_sequence != null:
		_victory_sequence.play()

func _on_victory_completed() -> void:
	end_session()
