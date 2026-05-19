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
var _character_mesh: Node3D
var _anim_player: AnimationPlayer
var _current_anim: String = ""
const WALK_VELOCITY_THRESHOLD := 0.5

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
	# Kenney character authored facing +Z (toward camera). Rotate 180° so it
	# faces forward (-Z, away from camera) matching movement direction.
	_character_mesh = get_node_or_null("CharacterMesh")
	if _character_mesh != null:
		_character_mesh.rotation.y = PI
		# Kenney GLB embeds an AnimationPlayer with idle/walk/sprint/jump/fall.
		_anim_player = _character_mesh.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim_player != null:
			_play_anim("idle")

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

	# Head bob (was at the tail of _physics_process — kept here)
	if is_on_floor() and direction.length() > 0 and _camera != null:
		_head_bob_time += delta * speed * 0.8
		var bob_offset := sin(_head_bob_time * TAU) * 0.04
		_camera.position.y = _camera_base_y + bob_offset
	elif _camera != null:
		_camera.position.y = lerp(_camera.position.y, _camera_base_y, 10.0 * delta)

	# Drive character animation from horizontal velocity.
	if _anim_player != null:
		var horiz := Vector2(velocity.x, velocity.z).length()
		var want := "idle"
		if not is_on_floor():
			want = "fall"
		elif horiz > WALK_VELOCITY_THRESHOLD:
			want = "sprint" if is_sprinting else "walk"
		_play_anim(want)


## Animation names that should loop continuously. Kenney glTFs default to
## loop_mode = NONE on import; without overriding, walk/idle play once
## (~1 s) and stop while the kid is still moving. (Bug reported via
## /dev:debug 'walking animation works for a moment then stops'.)
const LOOPING_ANIMS := ["idle", "walk", "sprint", "static"]


## Switch to the named animation if not already playing. Falls back to whatever
## is in the GLB if the name isn't found (some Kenney packs name them differently).
func _play_anim(name: String) -> void:
	if _anim_player == null or _current_anim == name:
		return
	if not _anim_player.has_animation(name):
		# Try a fuzzy fallback to anything starting with the name.
		for a in _anim_player.get_animation_list():
			if String(a).to_lower().begins_with(name.to_lower()):
				name = a
				break
		if not _anim_player.has_animation(name):
			return
	# Force loop on continuous-state anims (idle/walk/sprint). Glb import
	# defaults to LOOP_NONE; the play() call stalls on the last frame
	# otherwise and we don't restart because _current_anim == name guards
	# above.
	for loop_name in LOOPING_ANIMS:
		if name.to_lower().begins_with(loop_name):
			var anim := _anim_player.get_animation(name)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
			break
	_anim_player.play(name)
	_current_anim = name

const KEY_ROTATE_SPEED := 2.5  # rad/s for Q/E fallback rotation
const STICK_ROTATE_SPEED := 3.0  # rad/s at full joypad deflection
const STICK_DEADZONE := 0.2
const MOUSE_DRAG_SENSITIVITY := 0.005  # rad per pixel while dragging

var _mouse_dragging: bool = false

func _input(event: InputEvent) -> void:
	if not is_processing_input():
		return

	# Left- or right-mouse drag rotates camera. Cursor stays visible. macOS
	# trackpad's right-click is inconsistent (two-finger tap, system gesture
	# bindings), so we accept both buttons. Cursor remains free for HUD/Wróć.
	if event is InputEventMouseButton and (
		event.button_index == MOUSE_BUTTON_LEFT
		or event.button_index == MOUSE_BUTTON_RIGHT
	):
		_mouse_dragging = event.pressed
		return

	if event is InputEventMouseMotion:
		if _mouse_dragging:
			rotate_y(-event.relative.x * MOUSE_DRAG_SENSITIVITY)
			_vertical_look -= event.relative.y * MOUSE_DRAG_SENSITIVITY
			_vertical_look = clamp(_vertical_look, -VERTICAL_LOOK_LIMIT, VERTICAL_LOOK_LIMIT)
			if _camera != null:
				_camera.rotation.x = _vertical_look
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			_vertical_look -= event.relative.y * MOUSE_SENSITIVITY
			_vertical_look = clamp(_vertical_look, -VERTICAL_LOOK_LIMIT, VERTICAL_LOOK_LIMIT)
			_camera.rotation.x = _vertical_look

func _process(delta: float) -> void:
	if not is_processing():
		return
	# Camera rotation: Q/E keys (fallback) + controller right-stick.
	# Right-mouse drag is handled in _input.
	var rot := 0.0
	if Input.is_key_pressed(KEY_Q):
		rot += 1.0
	if Input.is_key_pressed(KEY_E):
		rot -= 1.0
	if rot != 0.0:
		rotate_y(rot * KEY_ROTATE_SPEED * delta)
	# Controller right-stick: axis 2 = X (yaw), axis 3 = Y (pitch).
	var stick_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var stick_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(stick_x) > STICK_DEADZONE:
		rotate_y(-stick_x * STICK_ROTATE_SPEED * delta)
	if absf(stick_y) > STICK_DEADZONE and _camera != null:
		_vertical_look -= stick_y * STICK_ROTATE_SPEED * delta
		_vertical_look = clamp(_vertical_look, -VERTICAL_LOOK_LIMIT, VERTICAL_LOOK_LIMIT)
		_camera.rotation.x = _vertical_look

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
