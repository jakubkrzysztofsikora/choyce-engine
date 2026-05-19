class_name PlayerController
extends CharacterBody3D

const WALK_SPEED := 5.0
const SPRINT_SPEED := 10.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
const VERTICAL_LOOK_LIMIT := 1.2
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1
const FOOTSTEP_INTERVAL := 0.4
const BASE_FOV := 75.0
const SPRINT_FOV := 82.0
const GRAVITY_RISE_MULTIPLIER := 1.0
const GRAVITY_FALL_MULTIPLIER := 1.35

signal footstep
signal landed
signal hard_landed
signal jumped

var _camera: Camera3D
var _vertical_look: float = 0.0
var _coyote_time: float = 0.0
var _jump_buffer: float = 0.0
var _was_on_floor: bool = false
var _footstep_timer: float = 0.0
var _head_bob_time: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _camera_base_y: float = 1.6

func _ready() -> void:
	_camera = $Camera3D
	if _camera == null:
		push_error("PlayerController: Camera3D child not found")
	_base_scale = scale
	if _camera != null:
		_camera_base_y = _camera.position.y
		_camera.fov = BASE_FOV
		# Without make_current(), the root viewport has no active camera and
		# only the Environment sky_blue clears the frame. Kid saw a blue
		# screen instead of the 3D world. set_process(false) at construction
		# does not stop the camera from rendering — only its update loop.
		_camera.make_current()
		print("[player_controller] _ready: camera current=%s pos=%s viewport=%s" %
			[_camera.current, _camera.global_position, _camera.get_viewport()])

func _physics_process(delta: float) -> void:
	if not is_processing():
		return

	# Coyote time
	if is_on_floor():
		_coyote_time = COYOTE_TIME
	else:
		_coyote_time -= delta

	# Jump buffer
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer -= delta

	# Better gravity curve
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	if not is_on_floor():
		var gravity_mult := GRAVITY_RISE_MULTIPLIER if velocity.y > 0 else GRAVITY_FALL_MULTIPLIER
		velocity.y -= gravity * gravity_mult * delta

	# Jump with coyote time and buffering
	if _jump_buffer > 0.0 and _coyote_time > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote_time = 0.0
		jumped.emit()

	# Movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_sprinting := Input.is_action_pressed("sprint")
	var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED

	if direction.length() > 0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# Landing detection and squash
	if is_on_floor() and not _was_on_floor:
		landed.emit()
		_landing_squash()
		if velocity.y < -5.0:
			_hard_landing_feedback()
	_was_on_floor = is_on_floor()

	# Footstep rhythm
	if is_on_floor() and direction.length() > 0:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = FOOTSTEP_INTERVAL
			footstep.emit()
	else:
		_footstep_timer = FOOTSTEP_INTERVAL * 0.5

	# Sprint FOV tween
	var target_fov := SPRINT_FOV if is_sprinting and direction.length() > 0 else BASE_FOV
	if _camera != null and not is_equal_approx(_camera.fov, target_fov):
		_camera.fov = lerp(_camera.fov, target_fov, 8.0 * delta)

	# Head bob
	if is_on_floor() and direction.length() > 0 and _camera != null:
		_head_bob_time += delta * speed * 0.8
		var bob_offset := sin(_head_bob_time * TAU) * 0.04
		_camera.position.y = _camera_base_y + bob_offset
	elif _camera != null:
		_camera.position.y = lerp(_camera.position.y, _camera_base_y, 10.0 * delta)

const KEY_ROTATE_SPEED := 2.5  # rad/s for Q/E rotation

func _input(event: InputEvent) -> void:
	if not is_processing_input():
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_vertical_look -= event.relative.y * MOUSE_SENSITIVITY
		_vertical_look = clamp(_vertical_look, -VERTICAL_LOOK_LIMIT, VERTICAL_LOOK_LIMIT)
		_camera.rotation.x = _vertical_look

func _process(delta: float) -> void:
	if not is_processing():
		return
	# Kid-friendly camera rotation via Q (left) / E (right) — no cursor capture.
	# Arrow keys / WASD stay reserved for movement (see _physics_process).
	var rot := 0.0
	if Input.is_key_pressed(KEY_Q):
		rot += 1.0
	if Input.is_key_pressed(KEY_E):
		rot -= 1.0
	if rot != 0.0:
		rotate_y(rot * KEY_ROTATE_SPEED * delta)

func spawn_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_was_on_floor = false
	_coyote_time = 0.0
	_jump_buffer = 0.0
	_head_bob_time = 0.0
	if _camera != null:
		_camera.position.y = _camera_base_y
		# Re-assert current — if a previous GameplayRuntime was queue_freed,
		# its Camera3D may still be holding the viewport until cleanup runs.
		_camera.make_current()
		print("[player_controller] spawn_at: player=%s camera=%s current=%s" %
			[global_position, _camera.global_position, _camera.current])

func _landing_squash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(_base_scale.x * 1.12, _base_scale.y * 0.72, _base_scale.z * 1.12), 0.05)
	tween.tween_property(self, "scale", _base_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hard_landing_feedback() -> void:
	hard_landed.emit()
