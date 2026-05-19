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
signal attacked(damage: int, hit_position: Vector3)
signal hp_changed(current: int, max_hp: int)
signal player_defeated

## Combat state. Player HP regenerates 2/sec when not recently hit.
## Equipped weapon damage drives _on_attack hit value; defaults to a
## starter "fist" 4-damage weapon until inventory injects something.
const ATTACK_COOLDOWN := 0.4
const ATTACK_RANGE := 1.8
const ATTACK_ARC_RADIANS := 1.4   ## ~80° front cone
const STARTER_WEAPON_DAMAGE := 4
const PLAYER_MAX_HP := 100
const PLAYER_REGEN_PER_SEC := 2.0

var _health: HealthState
var _attack_cooldown: float = 0.0
var _equipped_weapon_damage: int = STARTER_WEAPON_DAMAGE

## Voxel build hookup. GameplayRuntime injects via setup_build_grid().
## Hotbar tracks which BlockKind id maps to slots 1..5; default first
## 5 from BlockKind.default_catalog().
var _build_grid: BuildGrid = null
var _hotbar: Array = []        ## Array[String] block_ids
var _active_slot: int = 0      ## 0-based index into _hotbar

signal hotbar_changed(active_slot: int, block_id: String)

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
	_health = HealthState.new(PLAYER_MAX_HP)
	hp_changed.emit(_health.current_hp, _health.max_hp)
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

	# Combat tick — regen + cooldowns + attack input.
	if _health != null:
		_health.tick(delta, PLAYER_REGEN_PER_SEC)
		hp_changed.emit(_health.current_hp, _health.max_hp)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if Input.is_action_pressed("attack") and _attack_cooldown <= 0.0:
		_perform_attack()
	_process_build_input()

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

	# Roblox-style mouse layout for 7yo combat player:
	#   left mouse  = attack (passes through to Input.is_action_pressed via _physics_process)
	#   right mouse = hold-drag camera look (cursor visible, no capture)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Input.action_press("attack")
			else:
				Input.action_release("attack")
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
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

## Sweep the front cone for enemies. Hit each EnemyController within
## ATTACK_RANGE + ATTACK_ARC. Emit `attacked` signal so gameplay
## runtime can spawn swing VFX / SFX.
func _perform_attack() -> void:
	_attack_cooldown = ATTACK_COOLDOWN
	# Squash a tiny attack scale tween for game feel.
	var attack_tween := create_tween()
	attack_tween.tween_property(self, "scale", _base_scale * Vector3(1.05, 0.95, 1.05), 0.08)
	attack_tween.tween_property(self, "scale", _base_scale, 0.12)

	var hit_origin := global_position + Vector3(0, 0.8, 0)
	var forward := -transform.basis.z.normalized()
	var hit_point := hit_origin + forward * (ATTACK_RANGE * 0.5)
	attacked.emit(_equipped_weapon_damage, hit_point)

	# Hit-detect: scan scene tree for EnemyControllers in arc.
	# (Cheap O(N) — kid maps will rarely hold > 20 enemies.)
	var tree := get_tree()
	if tree == null:
		return
	for body in tree.get_nodes_in_group("enemies"):
		if not (body is EnemyController):
			continue
		var to_enemy: Vector3 = body.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance > ATTACK_RANGE:
			continue
		var angle := forward.angle_to(to_enemy.normalized())
		if angle > ATTACK_ARC_RADIANS * 0.5:
			continue
		(body as EnemyController).apply_damage(_equipped_weapon_damage, global_position)


## Called by EnemyController on touch contact. Routes through
## HealthState which enforces invuln + per-hit damage cap.
func apply_damage_from_enemy(amount: int, source_position: Vector3) -> void:
	if _health == null:
		return
	if not _health.apply_damage(amount):
		return
	hp_changed.emit(_health.current_hp, _health.max_hp)
	# Knockback away from source.
	var away := (global_position - source_position).normalized()
	away.y = 0.0
	velocity = away * 5.0
	velocity.y = 4.0
	if not _health.is_alive:
		player_defeated.emit()


func get_health() -> HealthState:
	return _health


func equip_weapon_damage(damage: int) -> void:
	_equipped_weapon_damage = maxi(damage, 1)


## Injection point for Minecraft-lite block placement. Called by
## GameplayRuntime once per session, after the BuildGrid node is
## added to the scene tree. Sets a default 5-block hotbar.
func setup_build_grid(grid: BuildGrid) -> void:
	_build_grid = grid
	var default := BlockKind.default_catalog()
	_hotbar.clear()
	for i in mini(default.size(), 5):
		_hotbar.append((default[i] as BlockKind).block_id)
	_active_slot = 0
	if not _hotbar.is_empty():
		hotbar_changed.emit(_active_slot, _hotbar[0])


func _process_build_input() -> void:
	if _build_grid == null or _hotbar.is_empty():
		return
	# Hotbar slot selection.
	for i in range(_hotbar.size()):
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			_active_slot = i
			hotbar_changed.emit(_active_slot, _hotbar[i])
	# Place or break — raycast 6m ahead.
	if Input.is_action_just_pressed("place_block"):
		_try_place_block()
	if Input.is_action_just_pressed("break_block"):
		_try_break_block()


func _build_raycast() -> Dictionary:
	if _build_grid == null:
		return {}
	var origin := global_position + Vector3(0, 0.8, 0)
	var forward := -transform.basis.z.normalized()
	var end := origin + forward * 6.0
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, end, 1, [self])
	return space.intersect_ray(params)


func _try_place_block() -> void:
	var hit := _build_raycast()
	var cell: Vector3i
	if hit.is_empty():
		# No hit — place at point 3m ahead, snapped to ground level.
		var forward := -transform.basis.z.normalized()
		var pos := global_position + forward * 3.0
		pos.y = global_position.y - 0.5  ## one cell below player feet
		cell = _build_grid.world_to_cell(pos)
	else:
		# Place adjacent to hit face — use normal to offset.
		var hit_pos: Vector3 = hit.get("position", global_position)
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		cell = _build_grid.world_to_cell(hit_pos + normal * 0.5)
	_build_grid.place_block(cell, _hotbar[_active_slot])


func _try_break_block() -> void:
	var hit := _build_raycast()
	if hit.is_empty():
		return
	var hit_pos: Vector3 = hit.get("position", global_position)
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	# Step into the block by half a cell in the negative-normal direction.
	var cell := _build_grid.world_to_cell(hit_pos - normal * 0.5)
	_build_grid.break_block(cell)


func _landing_squash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(_base_scale.x * 1.12, _base_scale.y * 0.72, _base_scale.z * 1.12), 0.05)
	tween.tween_property(self, "scale", _base_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hard_landing_feedback() -> void:
	hard_landed.emit()
