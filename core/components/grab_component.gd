class_name GrabComponent
extends SandboxComponent
## Makes a RigidBody3D pick-up-able.
##
## The hold is PHYSICS-BASED (velocity steered toward a hold point), never
## reparenting. Reparenting a RigidBody3D mid-simulation is the classic way to
## get an object that explodes across the map on release.

enum MassClass { LIGHT, HEAVY, TWO_HANDED }

signal grabbed(player_id: int)
signal released(player_id: int, throw_impulse: Vector3)

@export var mass_class: MassClass = MassClass.LIGHT
@export var hold_stiffness: float = 22.0
@export var hold_damping: float = 0.85
@export var max_hold_speed: float = 18.0
@export var throw_impulse_max: float = 14.0
@export var breaks_at_distance: float = 5.0

var held_by: int = -1
var _hold_point: Node3D
var _body: RigidBody3D
var _saved_layer: int
var _saved_mask: int
var _saved_gravity: float = 1.0
var _saved_can_sleep: bool = true
var _holder_body: PhysicsBody3D


func _component_key() -> StringName:
	return Components.GRAB


func _on_registered() -> void:
	_body = entity as RigidBody3D
	if _body == null:
		push_error("GrabComponent requires a RigidBody3D parent, got %s" % entity.get_class())
		return
	_body.collision_layer |= Layers.GRAB_TARGET


func is_held() -> bool:
	return held_by >= 0


func grab(player_id: int, hold_point: Node3D) -> bool:
	if _body == null or is_held() or hold_point == null:
		return false
	held_by = player_id
	_hold_point = hold_point
	_saved_layer = _body.collision_layer
	_saved_mask = _body.collision_mask
	# Save the ORIGINAL values. Hardcoding gravity_scale = 1.0 on release
	# permanently clobbered any prop authored floaty (0.4), heavy (2.0) or
	# hovering (0.0) the first time anyone picked it up.
	_saved_gravity = _body.gravity_scale
	_saved_can_sleep = _body.can_sleep

	# Clearing PLAYER_BODY from the prop's MASK does NOT stop the collision:
	# Godot's broadphase is symmetric, and the holder's own mask still contains
	# PROP_DYNAMIC which is still on the prop's LAYER. It also disabled the prop
	# against all four players instead of just the holder.
	# add_collision_exception_with is the only genuinely pairwise mechanism.
	_holder_body = _find_holder_body(hold_point)
	if _holder_body:
		_body.add_collision_exception_with(_holder_body)

	_body.gravity_scale = 0.0
	# A held body whose velocity settles can fall asleep and stop tracking the
	# hold point. sleeping = false once is not enough.
	_body.can_sleep = false
	_body.sleeping = false
	grabbed.emit(player_id)
	return true


func _find_holder_body(hold_point: Node3D) -> PhysicsBody3D:
	var n: Node = hold_point
	while n != null:
		if n is PhysicsBody3D:
			return n as PhysicsBody3D
		n = n.get_parent()
	return null


func release(throw_strength: float = 0.0) -> void:
	if _body == null or not is_held():
		return
	var pid := held_by
	_body.collision_layer = _saved_layer
	_body.collision_mask = _saved_mask
	_body.gravity_scale = _saved_gravity
	_body.can_sleep = _saved_can_sleep
	if is_instance_valid(_holder_body):
		_body.remove_collision_exception_with(_holder_body)
	_holder_body = null

	var impulse := Vector3.ZERO
	if throw_strength > 0.0 and is_instance_valid(_hold_point):
		var dir := -_hold_point.global_transform.basis.z
		impulse = dir * throw_impulse_max * clampf(throw_strength, 0.0, 1.0) * _body.mass
		_body.apply_central_impulse(impulse)

	held_by = -1
	_hold_point = null
	released.emit(pid, impulse)


func _physics_process(delta: float) -> void:
	if _body == null or not is_held():
		return
	if not is_instance_valid(_hold_point):
		release()
		return

	var target := _hold_point.global_position
	var to_target := target - _body.global_position

	if to_target.length() > breaks_at_distance:
		release()   # walked through a wall; drop it rather than tunnelling
		return

	var desired := to_target * hold_stiffness
	if desired.length() > max_hold_speed:
		desired = desired.normalized() * max_hold_speed
	_body.linear_velocity = _body.linear_velocity.lerp(desired, clampf(hold_damping, 0.0, 1.0))
	_body.angular_velocity = _body.angular_velocity.lerp(Vector3.ZERO, 6.0 * delta)
