extends CharacterBody3D
## Sandbox player.
##
## Aim model (rewritten after review — the original was unplayable):
##   - `_aim` is a Node3D at head height carrying look yaw + pitch.
##   - the camera orbits BEHIND `_aim` at tuning.cam_distance.
##   - every gameplay ray starts at `_aim.global_position` and points along
##     -_aim.basis.z.
## The original cast from `camera.global_position` toward `-camera.basis.z`
## while the camera was `look_at`-ing the player, so every ray passed through
## the player's own head and targeted whatever was BEHIND them; the build ghost
## was pinned to the player's feet and FREE mode buried blocks in the ground.

signal died_signal(player_id: int)
signal respawned(player_id: int)

@export var tuning: PlayerTuning

var profile: SandboxPlayerProfile
var device: int = -1

var _aim: Node3D
var _cam: Camera3D
var _cam_snap_pending: bool = false
var _yaw: float = 0.0
var _pitch: float = -0.18
var _hold_point: Node3D
var _held: GrabComponent
var _build: BuildController
var _throw_charge: float = 0.0
var _health: HealthComponent
var _spawn_point: Vector3
var _dead: bool = false
var _mesh: MeshInstance3D
var _suppress_build_place_once: bool = false


func setup(p: SandboxPlayerProfile) -> void:
	profile = p
	device = p.device_id


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	add_to_group(&"players")
	collision_layer = Layers.PLAYER_BODY
	collision_mask = Layers.SOLID_WORLD | Layers.PROP_DYNAMIC | Layers.VEHICLE
	_spawn_point = global_position if is_inside_tree() else position

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)

	var col: Color = profile.colour if profile else Color.WHITE

	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	_mesh.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.6
	_mesh.material_override = mat
	add_child(_mesh)

	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	var nm := BoxMesh.new()
	nm.size = Vector3(0.25, 0.25, 0.5)
	nose.mesh = nm
	nose.position = Vector3(0, 0.4, -0.55)
	nose.material_override = mat
	add_child(nose)

	# Aim pivot. top_level so its rotation is independent of the body's facing.
	_aim = Node3D.new()
	_aim.name = "Aim"
	_aim.top_level = true
	add_child(_aim)

	_hold_point = Node3D.new()
	_hold_point.name = "HoldPoint"
	_aim.add_child(_hold_point)
	_hold_point.position = Vector3(0, -tuning.hold_height, -tuning.hold_distance)

	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	var cfg := HealthConfig.new()
	cfg.max_health = tuning.max_health
	_health.config = cfg
	add_child(_health)
	_health.died.connect(_on_died)

	# The player NEEDS a hurtbox on the PLAYER_HURTBOX layer. Without one,
	# melee (which masks PLAYER_HURTBOX) can never touch a player and the whole
	# health stack is decorative on the entity it matters most for.
	var hurt := HurtboxComponent.new()
	hurt.name = "HurtboxComponent"
	hurt.faction = HurtboxComponent.Faction.PLAYER
	var hurt_shape := CollisionShape3D.new()
	var hurt_capsule := CapsuleShape3D.new()
	hurt_capsule.radius = 0.45
	hurt_capsule.height = 1.9
	hurt_shape.shape = hurt_capsule
	hurt.add_child(hurt_shape)
	add_child(hurt)

	var team := TeamComponent.new()
	team.name = "TeamComponent"
	team.team_id = 0
	team.owner_player_id = profile.player_id if profile else -1
	add_child(team)

	_build = BuildController.new()
	_build.name = "BuildController"
	add_child(_build)
	_build.setup(profile.player_id if profile else -1, device)

	if profile:
		profile.aim = _aim


func attach_camera(cam: Camera3D) -> void:
	_cam = cam
	# A rebuilt pane hands us a fresh Camera3D at the origin; snap it to the orbit
	# point on the next update so it does not lerp across the map from (0,0,0).
	_cam_snap_pending = true
	if _build:
		_build.set_camera(cam)
		_build.set_profile(profile)
	# Per-player visual layer so this player's build ghost is visible ONLY in
	# their own pane. Everything shares one World3D, so without a cull mask all
	# four ghosts float in everyone's view.
	if profile and cam:
		var own_bit := 1 << (10 + profile.player_id)
		var all_player_bits := 0
		for i in PlayerRegistrySystem.MAX_PLAYERS:
			all_player_bits |= 1 << (10 + i)
		cam.cull_mask = (cam.cull_mask & ~all_player_bits) | own_bit
		if _build:
			_build.set_visual_layer(own_bit)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look belongs to the keyboard player only.
	if device != MultiplayerInputSystem.KEYBOARD_DEVICE:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.pressed:
			_suppress_build_place_once = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * tuning.look_speed_mouse
		_pitch = clampf(_pitch - mm.relative.y * tuning.look_speed_mouse,
			deg_to_rad(tuning.pitch_min_degrees), deg_to_rad(tuning.pitch_max_degrees))


func _physics_process(delta: float) -> void:
	var mp := MultiplayerInputSystem.instance
	if profile == null or mp == null:
		return
	var suppress_build_place := _suppress_build_place_once
	_suppress_build_place_once = false

	if _dead:
		_update_aim_and_camera(delta)
		return

	_apply_look(mp, delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	if mp.is_action_just_pressed(device, &"jump") and is_on_floor():
		velocity.y = tuning.jump_velocity

	var stick := mp.get_vector(device, &"move_left", &"move_right", &"move_fwd", &"move_back")
	# Movement is relative to the LOOK yaw, which is now a real value rather
	# than a constant 0.0.
	var wish := Basis(Vector3.UP, _yaw) * Vector3(stick.x, 0.0, stick.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	var target := wish * tuning.speed
	velocity.x = move_toward(velocity.x, target.x, tuning.acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, tuning.acceleration * delta)
	if wish.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-wish.x, -wish.z), 12.0 * delta)

	move_and_slide()
	_update_aim_and_camera(delta)
	_handle_build(mp, suppress_build_place)
	_handle_grab(mp, delta)
	_handle_melee(mp)
	_check_kill_plane()


func _apply_look(mp, delta: float) -> void:
	var look: Vector2 = mp.get_vector(device, &"look_left", &"look_right", &"look_up", &"look_down")
	_yaw -= look.x * tuning.look_speed_stick * delta
	_pitch = clampf(_pitch - look.y * tuning.look_speed_stick * delta,
		deg_to_rad(tuning.pitch_min_degrees), deg_to_rad(tuning.pitch_max_degrees))


func _update_aim_and_camera(delta: float) -> void:
	if not is_instance_valid(_aim):
		return
	_aim.global_position = global_position + Vector3.UP * tuning.cam_look_at_height
	_aim.global_rotation = Vector3(_pitch, _yaw, 0.0)

	# _cam lives in a per-pane SubViewport that SplitScreenManager queue_free()s
	# and rebuilds on every roster change. For the frame between free and
	# re-attach the camera is still valid but out of tree, so its global_transform
	# would assert; skip the orbit until it is back in the tree.
	if not is_instance_valid(_cam) or not _cam.is_inside_tree():
		return

	var back := _aim.global_transform.basis.z
	var wanted := _aim.global_position + back * tuning.cam_distance \
		+ Vector3.UP * tuning.cam_height

	# Spring arm: keep the camera out of geometry. Backing into a corner used to
	# put the camera inside the wall and show the world's backfaces.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_aim.global_position, wanted)
	q.collision_mask = Layers.SOLID_WORLD | Layers.CAMERA_OCCLUDER
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var n: Vector3 = hit.get("normal", Vector3.UP)
		wanted = (hit["position"] as Vector3) + n * tuning.cam_collision_margin

	# Framerate-independent smoothing via half-life. A freshly attached camera
	# snaps to the target instead of lerping from the origin.
	if _cam_snap_pending:
		_cam_snap_pending = false
		_cam.global_position = wanted
	else:
		var t := 1.0 - pow(0.5, delta / maxf(0.0001, tuning.cam_smoothing_halflife))
		_cam.global_position = _cam.global_position.lerp(wanted, t)
	_cam.look_at(_aim.global_position, Vector3.UP)


func aim_origin() -> Vector3:
	return _aim.global_position if is_instance_valid(_aim) else global_position + Vector3.UP


func aim_direction() -> Vector3:
	return -_aim.global_transform.basis.z if is_instance_valid(_aim) else -global_transform.basis.z


func _handle_build(mp, suppress_build_place: bool = false) -> void:
	if _build == null:
		return
	if mp.is_action_just_pressed(device, &"build_toggle"):
		_build.set_active(not _build.active)
	if not _build.active:
		return
	if not suppress_build_place and mp.is_action_just_pressed(device, &"build_place"):
		_build.try_place()
	if mp.is_action_just_pressed(device, &"build_remove"):
		_build.try_remove()
	if mp.is_action_just_pressed(device, &"build_next"):
		_build.cycle_selection(1)
	if mp.is_action_just_pressed(device, &"build_rotate"):
		_build.rotate_step(1)
	if mp.is_action_just_pressed(device, &"build_mode"):
		_build.cycle_mode()


func _handle_grab(mp, delta: float) -> void:
	# The component can self-release (hold point gone, distance broken). Poll
	# rather than trusting the cached reference, or the player is stuck unable
	# to grab anything until they press and release the button again.
	if _held and (not is_instance_valid(_held) or not _held.is_held()):
		_held = null
		_throw_charge = 0.0

	if _held:
		if mp.is_action_pressed(device, &"grab"):
			_throw_charge = minf(1.0, _throw_charge + delta * 1.5)
		if mp.is_action_just_released(device, &"grab"):
			_held.release(_throw_charge)
			_held = null
			_throw_charge = 0.0
		return

	if not mp.is_action_just_pressed(device, &"grab"):
		return

	var sys := InteractionSystem.instance
	var focus := sys.focused_for(profile.player_id) if sys else null
	if focus == null:
		return
	var grab := Components.get_comp(focus.entity, Components.GRAB) as GrabComponent
	if grab and grab.grab(profile.player_id, _hold_point):
		_held = grab
		_throw_charge = 0.0


func _handle_melee(mp) -> void:
	if not mp.is_action_just_pressed(device, &"attack"):
		return
	# Along the AIM direction, not the body's facing. The body yaw lags toward
	# the movement vector, so swinging along rotation.y hit a different
	# direction from the one the player was looking.
	var from := aim_origin()
	var q := PhysicsRayQueryParameters3D.create(from, from + aim_direction() * tuning.melee_range)
	q.collision_mask = Layers.PROP_DYNAMIC | Layers.BUILD_PLACED | Layers.NPC_BODY \
		| Layers.NPC_HURTBOX | Layers.PLAYER_HURTBOX
	q.exclude = [get_rid()]
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return

	var info := DamageInfo.make(tuning.melee_damage, DamageInfo.Type.IMPACT,
		profile.player_id, hit["position"], hit.get("normal", Vector3.UP))
	info.source_team = TeamComponent.team_of(self)
	HurtboxComponent.deliver(hit["collider"], info)


func _check_kill_plane() -> void:
	if global_position.y < tuning.kill_plane_y and not _dead:
		_health.apply(DamageInfo.make(1e9, DamageInfo.Type.FALL))


func _on_died(_info: DamageInfo) -> void:
	if _dead:
		return
	_dead = true
	if _held and is_instance_valid(_held):
		_held.release()
		_held = null
	if _build:
		_build.set_active(false)
	velocity = Vector3.ZERO
	if _mesh:
		_mesh.visible = false
	died_signal.emit(profile.player_id if profile else -1)
	get_tree().create_timer(tuning.respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	if not is_inside_tree():
		return
	global_position = _spawn_point
	velocity = Vector3.ZERO
	_health.revive()
	_dead = false
	if _mesh:
		_mesh.visible = true
	respawned.emit(profile.player_id if profile else -1)


func set_spawn_point(p: Vector3) -> void:
	_spawn_point = p


func is_dead() -> bool:
	return _dead


func health() -> HealthComponent:
	return _health


func build_controller() -> BuildController:
	return _build
