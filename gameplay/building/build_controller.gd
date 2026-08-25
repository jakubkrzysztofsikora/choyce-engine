class_name BuildController
extends Node3D
## Per-player build cursor. One of these per player, parented to the player.
##
## Three placement modes on ONE controller, because retrofitting freeform onto a
## pure-GridMap design is a rewrite, and Rec Room / Roblox both feel good
## precisely because they are mostly-snapped but allow freeform.

enum Mode { GRID, SURFACE, FREE }

signal mode_changed(mode: Mode)
signal selection_changed(block_id: StringName)
signal placement_rejected(reason: String)

@export var cell_size: float = 1.0
@export var yaw_step_degrees: float = 90.0
@export var reach: float = 8.0
@export var ghost_valid_colour: Color = Color(0.35, 1.0, 0.45, 0.45)
@export var ghost_invalid_colour: Color = Color(1.0, 0.3, 0.3, 0.45)

var player_id: int = -1
var device_id: int = -1
var camera: Camera3D
var profile: SandboxPlayerProfile
var visual_layer: int = 1
var active: bool = false
var mode: Mode = Mode.GRID
var selected_index: int = 0
var yaw: float = 0.0

var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _last_valid: bool = false
var _last_xform: Transform3D = Transform3D.IDENTITY


func setup(p_player_id: int, p_device_id: int) -> void:
	player_id = p_player_id
	device_id = p_device_id
	_make_ghost()


func set_camera(cam: Camera3D) -> void:
	camera = cam


func set_profile(p: SandboxPlayerProfile) -> void:
	profile = p


## Puts the ghost on a per-player visual layer so it renders ONLY in that
## player's pane. All four players share one World3D, so without this every
## player sees every other player's floating ghost block.
func set_visual_layer(bit: int) -> void:
	visual_layer = bit
	if _ghost:
		_ghost.layers = bit


func _aim_origin() -> Vector3:
	if profile:
		return profile.aim_origin()
	return camera.global_position if is_instance_valid(camera) else global_position


func _aim_direction() -> Vector3:
	if profile:
		return profile.aim_direction()
	return -camera.global_transform.basis.z if is_instance_valid(camera) else Vector3.FORWARD


func _make_ghost() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = ghost_valid_colour
	# The ghost NEVER has a collision shape. It sits on BUILD_GHOST, which
	# nothing collides with, and validation is a one-shot shape query instead.
	_ghost.material_override = _ghost_material
	_ghost.visible = false
	_ghost.layers = visual_layer
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)


func selected_block() -> StringName:
	var build := BuildSystem.instance
	if build == null or build.palette.is_empty():
		return &""
	return build.palette[selected_index % build.palette.size()]


func set_active(v: bool) -> void:
	active = v
	if _ghost:
		_ghost.visible = v


func cycle_selection(delta: int) -> void:
	var build := BuildSystem.instance
	if build == null or build.palette.is_empty():
		return
	selected_index = posmod(selected_index + delta, build.palette.size())
	_refresh_ghost_mesh()
	selection_changed.emit(selected_block())


func cycle_mode() -> void:
	mode = ((mode + 1) % 3) as Mode
	mode_changed.emit(mode)


func rotate_step(dir: int) -> void:
	yaw = fposmod(yaw + deg_to_rad(yaw_step_degrees) * float(dir), TAU)


func _refresh_ghost_mesh() -> void:
	var build := BuildSystem.instance
	if build == null or _ghost == null:
		return
	_ghost.mesh = build.mesh_for(selected_block())


func _physics_process(_delta: float) -> void:
	if not active or camera == null or not is_instance_valid(camera):
		return
	var build := BuildSystem.instance
	if build == null or build.palette.is_empty():
		return
	if _ghost.mesh == null:
		_refresh_ghost_mesh()

	var xform := _target_transform()
	_last_xform = xform
	_last_valid = build.can_place(selected_block(), xform)

	_ghost.top_level = true
	_ghost.global_transform = xform
	_ghost_material.albedo_color = ghost_valid_colour if _last_valid else ghost_invalid_colour


func _target_transform() -> Transform3D:
	var from := _aim_origin()
	var dir := _aim_direction()
	var hit := _raycast(from, from + dir * reach)

	var pos: Vector3
	var basis := Basis(Vector3.UP, yaw)

	match mode:
		Mode.GRID:
			var raw: Vector3 = hit.get("position", from + dir * reach)
			pos = Vector3(
				(round(raw.x / cell_size)) * cell_size,
				(round(raw.y / cell_size)) * cell_size,
				(round(raw.z / cell_size)) * cell_size)
		Mode.SURFACE:
			pos = hit.get("position", from + dir * reach)
			var n: Vector3 = hit.get("normal", Vector3.UP)
			if n.length_squared() > 0.001:
				basis = _basis_aligned_to(n, yaw)
			pos += n * 0.5 * cell_size
		Mode.FREE:
			pos = from + dir * reach
			basis = Basis(Vector3.UP, yaw)

	return Transform3D(basis, pos)


func _basis_aligned_to(normal: Vector3, spin: float) -> Basis:
	var up := normal.normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var right := ref.cross(up).normalized()
	var fwd := up.cross(right).normalized()
	return Basis(right, up, fwd).rotated(up, spin)


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Layers.SOLID_WORLD | Layers.PROP_DYNAMIC
	q.collide_with_areas = false
	return world.direct_space_state.intersect_ray(q)


func try_place() -> bool:
	if not active:
		return false
	var build := BuildSystem.instance
	if build == null:
		return false
	if not _last_valid:
		placement_rejected.emit("blocked")
		return false
	return build.place(selected_block(), _last_xform, player_id)


func try_remove() -> bool:
	# is_instance_valid, not `== null`: _rebuild_panes() queue_frees and
	# recreates every camera on every join/leave, so there is a window where
	# this reference is a freed instance.
	if not active or not is_instance_valid(camera):
		return false
	var build := BuildSystem.instance
	if build == null:
		return false
	var from := _aim_origin()
	var dir := _aim_direction()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	q.collision_mask = Layers.BUILD_PLACED
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	return build.remove_at(hit["position"], player_id)


func debug_state() -> Dictionary:
	return {
		"player": player_id,
		"active": active,
		"mode": mode,
		"block": String(selected_block()),
		"valid": _last_valid,
	}
