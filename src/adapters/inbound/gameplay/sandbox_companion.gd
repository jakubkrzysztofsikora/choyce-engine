class_name SandboxCompanion
extends CharacterBody3D
## Small deterministic guide villager for the opening slice.
##
## The companion deliberately owns only presentation-level movement. Dialogue,
## progression, and safety remain in GameplayRuntime and its ports.

@export var target_position := Vector3(6.0, 0.0, -23.0)
@export var move_speed := 1.35
@export var stop_radius := 1.7

var navigation_agent: NavigationAgent3D
var _player_target: Node3D
var _animator: AnimationPlayer
var _moving := false

func _ready() -> void:
	collision_mask = Layers.SOLID_WORLD | Layers.PLAYER_BODY
	_animator = find_child("AnimationPlayer", true, false) as AnimationPlayer
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if navigation_agent == null or not is_instance_valid(navigation_agent):
		return
	if _player_target == null or not is_instance_valid(_player_target):
		_player_target = _find_player()
	var destination := target_position
	if _player_target != null:
		# Guide villagers travel to a point just ahead of the player, then wait.
		destination = _player_target.global_position
	navigation_agent.target_position = destination
	var distance := global_position.distance_to(destination)
	if distance <= stop_radius:
		velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
		_moving = false
		if _player_target != null:
			_face_target(_player_target.global_position, delta)
	else:
		# This is the important runtime contract: movement follows the baked
		# navigation surface rather than teleporting or ignoring the agent.
		var next_point := navigation_agent.get_next_path_position()
		var direction := global_position.direction_to(next_point)
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			direction = direction.normalized()
			velocity.x = move_toward(velocity.x, direction.x * move_speed, 5.0 * delta)
			velocity.z = move_toward(velocity.z, direction.z * move_speed, 5.0 * delta)
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 6.0 * delta)
			_moving = true
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_play_animation("walk" if _moving else "idle")

func _find_player() -> Node3D:
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate is Node3D:
			return candidate as Node3D
	return null

func _face_target(point: Vector3, delta: float) -> void:
	var direction := global_position.direction_to(point)
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 5.0 * delta)

func _play_animation(animation_name: String) -> void:
	if _animator == null or not _animator.has_animation(animation_name):
		return
	if _animator.current_animation != animation_name:
		_animator.play(animation_name)
