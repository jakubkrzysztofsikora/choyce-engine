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

	if _ambient_player != null:
		_ambient_player.stream = _create_ambient_noise()
		_ambient_player.play()
		_fill_ambient_buffer()

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
	_world_renderer.render_world(world)
	var spawn_pos := _world_renderer.get_spawn_position(0)
	_player_controller.spawn_at(spawn_pos + Vector3(0, 1, 0))
	_player_controller.visible = true
	_player_controller.set_process_input(true)
	_player_controller.set_process(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Spawn sparkle at player spawn
	if _effect_spawner != null:
		_effect_spawner.spawn_sparkle_burst(_player_controller.global_position)

	# Connect trigger areas
	for child in _world_renderer.get_children():
		if child is Area3D:
			if not child.body_entered.is_connected(_on_trigger_area_entered):
				child.body_entered.connect(_on_trigger_area_entered.bind(child))

func end_session() -> void:
	_world_renderer.clear_world()
	if _player_controller != null:
		_player_controller.visible = false
		_player_controller.set_process_input(false)
		_player_controller.set_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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

func _create_ambient_noise() -> AudioStreamGenerator:
	# Soft wind/drone placeholder — actual frames are pushed in _ready after play() starts
	var gen := AudioStreamGenerator.new()
	gen.buffer_length = 2.0
	return gen

func _fill_ambient_buffer() -> void:
	if _ambient_player == null:
		return
	var playback: AudioStreamGeneratorPlayback = _ambient_player.get_stream_playback()
	var sample_rate := (_ambient_player.stream as AudioStreamGenerator).mix_rate
	var frames := int(sample_rate * 1.5)
	for i in range(frames):
		var t := float(i) / sample_rate
		# Low-frequency drone with gentle amplitude modulation
		var amp := 0.03 * (1.0 + sin(t * 0.5 * TAU)) * 0.5
		var sample := sin(t * 110.0 * TAU) * amp + sin(t * 112.0 * TAU) * amp * 0.5
		playback.push_frame(Vector2.ONE * sample)

func _on_victory_completed() -> void:
	end_session()
