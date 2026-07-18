## VehicleBase.gd - predictable third-person arcade vehicle controller.
##
## Uses CharacterBody3D instead of the wheel solver: streamed Terrain3D can
## report no wheel contact, which made an entered car unable to move. The
## ready-made model supplies the visual wheels/tracks; this body supplies the
## reliable grounded movement children need.
class_name VehicleBase
extends CharacterBody3D

const ENGINE_IDLE_STREAM: AudioStream = preload("res://data/audio/sfx/eleven/vehicle_engine_idle.mp3")
const ENGINE_START_STREAM: AudioStream = preload("res://data/audio/sfx/eleven/vehicle_engine_start.mp3")
const ENGINE_BRAKE_STREAM: AudioStream = preload("res://data/audio/sfx/eleven/vehicle_brake.mp3")

signal entered(player: PlayerController)
signal exited(player: PlayerController, exit_position: Vector3)
signal destroyed(object: Node3D)

@export var max_engine_force: float = 200.0 ## retained for variant tuning/UI
@export var max_brake_force: float = 400.0  ## retained for variant tuning/UI
@export var max_steering_angle: float = 0.5
@export var steering_speed: float = 2.0
@export var max_speed: float = 15.0
@export var acceleration: float = 18.0
@export var deceleration: float = 24.0
@export var turn_speed: float = 2.15
@export var reverse_turn_multiplier: float = 0.72
@export var camera_follow_distance: float = 5.0
@export var camera_follow_height: float = 2.0
@export var camera_follow_smoothness: float = 10.0

var current_engine_force: float = 0.0
var current_steering: float = 0.0
var is_braking: bool = false
var is_active: bool = false
var current_player: PlayerController = null
var entry_points: Array[Area3D] = []
var exit_points: Array[Area3D] = []
var vehicle_camera: Camera3D = null
var _previous_camera: Camera3D = null
var _drive_speed := 0.0
var _player_collision_layer := 1
var _player_collision_mask := 1
var _engine_audio: AudioStreamPlayer3D = null
var _engine_one_shot: AudioStreamPlayer3D = null
var _was_braking := false


func _ready() -> void:
	entry_points.clear()
	exit_points.clear()
	floor_max_angle = deg_to_rad(52.0)
	floor_stop_on_slope = true
	floor_snap_length = 0.55
	for child in get_children():
		if child is Area3D and "entry" in child.name.to_lower():
			entry_points.append(child as Area3D)
			if not child.body_entered.is_connected(_on_entry_body_entered):
				child.body_entered.connect(_on_entry_body_entered)
		elif child is Area3D and "exit" in child.name.to_lower():
			exit_points.append(child as Area3D)
		elif child is Camera3D:
			vehicle_camera = child as Camera3D
			vehicle_camera.top_level = true
	_setup_engine_audio()


func _setup_engine_audio() -> void:
	_engine_audio = AudioStreamPlayer3D.new()
	_engine_audio.name = "VehicleEngineIdle"
	_engine_audio.bus = "SFX"
	_engine_audio.stream = ENGINE_IDLE_STREAM
	_engine_audio.unit_size = 10.0
	_engine_audio.max_distance = 42.0
	_engine_audio.volume_db = -48.0
	_engine_audio.pitch_scale = 0.78
	if _engine_audio.stream is AudioStreamMP3:
		(_engine_audio.stream as AudioStreamMP3).loop = true
	add_child(_engine_audio)
	_engine_one_shot = AudioStreamPlayer3D.new()
	_engine_one_shot.name = "VehicleEngineOneShot"
	_engine_one_shot.bus = "SFX"
	_engine_one_shot.unit_size = 10.0
	_engine_one_shot.max_distance = 42.0
	add_child(_engine_one_shot)


func _play_engine_one_shot(stream: AudioStream) -> void:
	if _engine_one_shot == null or stream == null:
		return
	_engine_one_shot.stream = stream
	_engine_one_shot.pitch_scale = 1.0
	_engine_one_shot.play()


## Compatibility shims for the authored vehicle variants. Their wheel layout
## methods remain useful documentation for ready-made visuals, but physics is
## now intentionally body-driven, so these are no-ops rather than hidden wheel
## bodies competing with CharacterBody3D collision.
func set_wheel_count(_count: int) -> void: pass
func set_wheel_position(_index: int, _wheel_position: Vector3) -> void: pass
func set_wheel_dimensions(_index: int, _radius: float, _width: float) -> void: pass
func set_suspension_travel(_value: float) -> void: pass
func set_suspension_stiffness(_value: float) -> void: pass
func set_suspension_damping(_value: float) -> void: pass


func _input(event: InputEvent) -> void:
	# InputEvent does not have is_action_just_pressed() - that is an Input singleton
	# method. Use Input.is_action_just_pressed() to check if the exit_vehicle action
	# was pressed, regardless of whether this specific event triggered it.
	if is_active and Input.is_action_just_pressed("exit_vehicle"):
		exit_vehicle()


func _physics_process(delta: float) -> void:
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	if is_active:
		var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("reverse")
		var steering_input := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
		is_braking = Input.is_action_pressed("brake")
		if is_braking and not _was_braking and absf(_drive_speed) > 1.6:
			_play_engine_one_shot(ENGINE_BRAKE_STREAM)
		current_steering = move_toward(current_steering, steering_input, steering_speed * delta)
		var target_speed := throttle * max_speed
		var rate := deceleration if is_braking or is_zero_approx(throttle) else acceleration
		_drive_speed = move_toward(_drive_speed, target_speed, rate * delta)
		if is_braking:
			_drive_speed = move_toward(_drive_speed, 0.0, max_brake_force * 0.08 * delta)
		var turn_factor := clampf(absf(_drive_speed) / maxf(max_speed, 0.1), 0.16, 1.0)
		var direction_sign := -1.0 if _drive_speed < -0.05 else 1.0
		var reverse_factor := reverse_turn_multiplier if direction_sign < 0.0 else 1.0
		# Godot vehicle visuals face -Z. Positive Y yaw turns that forward vector
		# left, while the input value is positive for `steer_right`; invert once at
		# this adapter boundary so A/left and D/right match their labels.
		rotation.y -= current_steering * turn_speed * turn_factor * direction_sign * reverse_factor * delta
		velocity.x = -global_transform.basis.z.x * _drive_speed
		velocity.z = -global_transform.basis.z.z * _drive_speed
		current_engine_force = throttle * max_engine_force
	else:
		_drive_speed = move_toward(_drive_speed, 0.0, deceleration * delta)
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	_was_braking = is_braking
	_update_engine_audio()
	move_and_slide()


func _update_engine_audio() -> void:
	if _engine_audio == null:
		return
	if not is_active:
		_engine_audio.stop()
		return
	if not _engine_audio.playing:
		_engine_audio.play()
	var speed_ratio := clampf(absf(_drive_speed) / maxf(max_speed, 0.1), 0.0, 1.0)
	_engine_audio.volume_db = lerpf(-17.0, -6.5, speed_ratio)
	_engine_audio.pitch_scale = lerpf(0.78, 1.28, speed_ratio)


func _on_entry_body_entered(body: Node3D) -> void:
	if body is PlayerController and current_player == null:
		enter(body as PlayerController)


func enter(player: PlayerController) -> void:
	if current_player != null:
		return
	current_player = player
	is_active = true
	_snap_to_surface()
	_player_collision_layer = player.collision_layer
	_player_collision_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.set_process_input(false)
	player.visible = false
	if not entry_points.is_empty():
		player.global_transform = entry_points[0].global_transform
	else:
		player.global_position = global_position
	if vehicle_camera != null:
		var viewport := get_viewport()
		_previous_camera = viewport.get_camera_3d() if viewport != null else null
		if _previous_camera == vehicle_camera:
			_previous_camera = null
		vehicle_camera.make_current()
	_play_engine_one_shot(ENGINE_START_STREAM)
	_update_engine_audio()
	entered.emit(player)


func exit_vehicle() -> void:
	if current_player == null:
		return
	is_active = false
	_drive_speed = 0.0
	if _engine_audio != null:
		_engine_audio.stop()
	var exit_position := get_exit_position()
	var player_ref := current_player
	player_ref.global_position = exit_position
	player_ref.collision_layer = _player_collision_layer
	player_ref.collision_mask = _player_collision_mask
	player_ref.visible = true
	player_ref.set_physics_process(true)
	player_ref.set_process_input(true)
	if vehicle_camera != null:
		vehicle_camera.clear_current()
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	_previous_camera = null
	current_player = null
	exited.emit(player_ref, exit_position)


func get_exit_position() -> Vector3:
	if not exit_points.is_empty():
		return exit_points[0].global_position + Vector3.UP * 0.05
	return global_position + global_transform.basis.x * 1.8 + Vector3.UP * 0.2


func snap_to_surface() -> bool:
	return _snap_to_surface()


func _snap_to_surface() -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return false
	var origin := global_position + Vector3.UP * 80.0
	var target := global_position + Vector3.DOWN * 160.0
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	var floor_offset := 0.0
	if collision != null and collision.shape is BoxShape3D:
		floor_offset = collision.position.y - (collision.shape as BoxShape3D).size.y * 0.5
	global_position.y = (hit.position as Vector3).y - floor_offset + 0.03
	velocity = Vector3.ZERO
	return true


func _process(delta: float) -> void:
	if not is_active or vehicle_camera == null or current_player == null:
		return
	var target_pos := global_position + global_transform.basis.z.normalized() * camera_follow_distance
	target_pos.y += camera_follow_height
	var follow_weight := 1.0 - exp(-camera_follow_smoothness * delta)
	vehicle_camera.global_position = vehicle_camera.global_position.lerp(target_pos, follow_weight)
	vehicle_camera.look_at(global_position + Vector3.UP, Vector3.UP)
