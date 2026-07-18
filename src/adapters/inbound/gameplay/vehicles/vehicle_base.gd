## VehicleBase.gd - Base class for all drivable vehicles
## Uses Godot 4.6's VehicleBody3D for physics
##
## Part of VS-021: Add rare drivable vehicles and bounded bulldozer destruction sandbox
##
## Features:
## - Configurable wheel-based physics
## - Engine, brake, and steering control
## - Enter/exit functionality
## - Input handling
##
class_name VehicleBase
extends VehicleBody3D


signal entered(player: PlayerController)
signal exited(player: PlayerController, exit_position: Vector3)
signal destroyed(object: Node3D)


# Vehicle configuration
@export var max_engine_force: float = 200.0
@export var max_brake_force: float = 400.0
@export var max_steering_angle: float = 0.5  # Radians
@export var steering_speed: float = 2.0
@export var max_speed: float = 15.0
@export var wheel_friction: float = 5.0
@export var wheel_roll_influence: float = 0.08

# Camera configuration
@export var camera_follow_distance: float = 5.0
@export var camera_follow_height: float = 2.0
@export var camera_follow_smoothness: float = 10.0

# Current state
var current_engine_force: float = 0.0
var current_steering: float = 0.0
var is_braking: bool = false
var is_active: bool = false

# Player reference
var current_player: PlayerController = null

# Components (set in _ready or children)
var entry_points: Array[Area3D] = []
var exit_points: Array[Area3D] = []
var vehicle_camera: Camera3D = null
var _wheels: Array[VehicleWheel3D] = []
var _previous_camera: Camera3D = null
var _tire_material: StandardMaterial3D = null
var _hub_material: StandardMaterial3D = null


func _ready() -> void:
	entry_points.clear()
	exit_points.clear()

	# Find entry points
	for child in get_children():
		if child is Area3D and "entry" in child.name.to_lower():
			entry_points.append(child as Area3D)
			if not child.body_entered.is_connected(_on_entry_body_entered):
				child.body_entered.connect(_on_entry_body_entered)
		elif child is Area3D and "exit" in child.name.to_lower():
			exit_points.append(child as Area3D)
		# Find camera
		elif child is Camera3D:
			vehicle_camera = child as Camera3D
			# The follow camera writes global coordinates and must not inherit
			# the body's pitch/roll after the suspension starts moving.
			vehicle_camera.top_level = true

	# Configure wheels (override in subclasses)
	_configure_wheels()

	# Disable physics initially (will be enabled when entered)
	set_physics_process(false)
	set_process_input(false)


func _configure_wheels() -> void:
	## Override in subclasses for specific wheel configurations
	## Default: simple 4-wheel car
	set_wheel_count(4)
	set_wheel_position(0, Vector3(-0.5, 0.2, 0.5))
	set_wheel_position(1, Vector3(0.5, 0.2, 0.5))
	set_wheel_position(2, Vector3(-0.5, 0.2, -0.5))
	set_wheel_position(3, Vector3(0.5, 0.2, -0.5))

	# Suspension settings
	set_suspension_travel(0.2)
	set_suspension_stiffness(20.0)
	set_suspension_damping(2.0)


## Godot 4.6 exposes wheel physics through VehicleWheel3D child nodes rather
## than VehicleBody3D helper methods. Keep the small configuration API used by
## the vehicle variants, but implement it with real VehicleWheel3D nodes.
func set_wheel_count(count: int) -> void:
	for wheel in _wheels:
		if is_instance_valid(wheel):
			if wheel.get_parent() == self:
				remove_child(wheel)
			wheel.queue_free()
	_wheels.clear()
	for index in maxi(count, 0):
		var wheel := VehicleWheel3D.new()
		wheel.name = "Wheel%d" % index
		wheel.use_as_traction = true
		wheel.wheel_radius = 0.35
		wheel.wheel_friction_slip = wheel_friction
		wheel.wheel_rest_length = 0.15
		wheel.wheel_roll_influence = wheel_roll_influence
		wheel.suspension_max_force = 9000.0
		add_child(wheel)
		_add_wheel_visuals(wheel)
		_wheels.append(wheel)


func set_wheel_position(index: int, wheel_position: Vector3) -> void:
	if index < 0 or index >= _wheels.size():
		return
	var wheel := _wheels[index]
	wheel.position = wheel_position
	# The first axle is the steering axle for the simple vehicle variants.
	wheel.use_as_steering = index < 2


func set_wheel_dimensions(index: int, radius: float, width: float) -> void:
	if index < 0 or index >= _wheels.size():
		return
	var wheel := _wheels[index]
	wheel.wheel_radius = maxf(radius, 0.05)
	var tire := wheel.get_node_or_null("Tire") as MeshInstance3D
	if tire != null and tire.mesh is CylinderMesh:
		var tire_mesh := tire.mesh as CylinderMesh
		tire_mesh.top_radius = wheel.wheel_radius
		tire_mesh.bottom_radius = wheel.wheel_radius
		tire_mesh.height = maxf(width, 0.05)
	var hub := wheel.get_node_or_null("Hub") as MeshInstance3D
	if hub != null and hub.mesh is CylinderMesh:
		var hub_mesh := hub.mesh as CylinderMesh
		hub_mesh.top_radius = wheel.wheel_radius * 0.42
		hub_mesh.bottom_radius = wheel.wheel_radius * 0.42
		hub_mesh.height = maxf(width + 0.012, 0.06)


func _add_wheel_visuals(wheel: VehicleWheel3D) -> void:
	if _tire_material == null:
		_tire_material = StandardMaterial3D.new()
		_tire_material.albedo_color = Color(0.035, 0.045, 0.05, 1.0)
		_tire_material.roughness = 0.92
	if _hub_material == null:
		_hub_material = StandardMaterial3D.new()
		_hub_material.albedo_color = Color(0.88, 0.62, 0.12, 1.0)
		_hub_material.metallic = 0.35
		_hub_material.roughness = 0.42

	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = wheel.wheel_radius
	tire_mesh.bottom_radius = wheel.wheel_radius
	tire_mesh.height = 0.28
	tire_mesh.radial_segments = 20
	tire_mesh.rings = 3
	tire_mesh.material = _tire_material
	var tire := MeshInstance3D.new()
	tire.name = "Tire"
	tire.rotation_degrees.z = 90.0
	tire.mesh = tire_mesh
	wheel.add_child(tire)

	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = wheel.wheel_radius * 0.42
	hub_mesh.bottom_radius = wheel.wheel_radius * 0.42
	hub_mesh.height = 0.292
	hub_mesh.radial_segments = 20
	hub_mesh.material = _hub_material
	var hub := MeshInstance3D.new()
	hub.name = "Hub"
	hub.rotation_degrees.z = 90.0
	hub.mesh = hub_mesh
	wheel.add_child(hub)


func get_wheel_count() -> int:
	return _wheels.size()


func set_suspension_travel(value: float) -> void:
	for wheel in _wheels:
		wheel.suspension_travel = maxf(value, 0.01)


func set_suspension_stiffness(value: float) -> void:
	for wheel in _wheels:
		wheel.suspension_stiffness = maxf(value, 0.01)


func set_suspension_damping(value: float) -> void:
	for wheel in _wheels:
		wheel.damping_compression = maxf(value, 0.01)
		wheel.damping_relaxation = maxf(value, 0.01)


func _input(event: InputEvent) -> void:
	if not is_active:
		return

	# Handle vehicle-specific input
	if event.is_action_just_pressed("exit_vehicle"):
		exit_vehicle()


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Get input
	var throttle := Input.get_action_strength("accelerate") - Input.get_action_strength("reverse")
	var steering_input := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	is_braking = Input.is_action_pressed("brake")

	# Apply steering (gradual for smoothness)
	current_steering = move_toward(current_steering, steering_input * max_steering_angle, steering_speed * delta)

	# Limit speed
	var current_speed := Vector2(linear_velocity.x, linear_velocity.z).length()
	var speed_factor := 1.0
	if current_speed > max_speed:
		speed_factor = 0.0

	# VehicleWheel3D owns engine, steering, and brake forces in Godot 4.6.
	current_engine_force = throttle * max_engine_force * speed_factor
	for wheel in _wheels:
		wheel.engine_force = current_engine_force if wheel.use_as_traction else 0.0
		wheel.steering = current_steering if wheel.use_as_steering else 0.0
		wheel.brake = max_brake_force if is_braking else 0.0


func _on_entry_body_entered(body: Node3D) -> void:
	if body is PlayerController and current_player == null:
		enter(body)


func enter(player: PlayerController) -> void:
	if current_player != null:
		return  # Already have a player

	current_player = player
	is_active = true

	# Store player state and hide
	player.set_physics_process(false)
	player.set_process_input(false)
	player.visible = false

	# Position player at entry point
	if entry_points.size() > 0:
		player.global_position = entry_points[0].global_position
		player.global_transform = entry_points[0].global_transform
	else:
		player.global_position = global_position
		player.global_transform = global_transform

	# Enable vehicle
	set_physics_process(true)
	set_process_input(true)

	# Switch camera if available
	if vehicle_camera != null:
		var viewport := get_viewport()
		_previous_camera = viewport.get_camera_3d() if viewport != null else null
		if _previous_camera == vehicle_camera:
			_previous_camera = null
		vehicle_camera.make_current()

	emit_signal("entered", player)


func exit_vehicle() -> void:
	if current_player == null:
		return

	is_active = false

	# Disable vehicle control
	set_physics_process(false)
	set_process_input(false)

	# Position player at exit point or current vehicle position
	var exit_position := global_position + global_transform.basis.z * -1.0
	if exit_points.size() > 0:
		exit_position = exit_points[0].global_position

	current_player.global_position = exit_position
	current_player.visible = true

	# Restore player control
	current_player.set_physics_process(true)
	current_player.set_process_input(true)

	# Switch camera back
	if vehicle_camera != null:
		vehicle_camera.clear_current()
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	_previous_camera = null

	# Clear reference
	var player_ref := current_player
	current_player = null

	emit_signal("exited", player_ref, exit_position)


func get_exit_position() -> Vector3:
	if exit_points.size() > 0:
		return exit_points[0].global_position
	return global_position + global_transform.basis.z * -1.0


func _process(delta: float) -> void:
	# Update camera if active
	if is_active and vehicle_camera != null and current_player != null:
		var target_pos := global_position
		target_pos += global_transform.basis.z.normalized() * camera_follow_distance
		target_pos.y += camera_follow_height

		# Smoothly move camera to target
		var follow_weight := 1.0 - exp(-camera_follow_smoothness * delta)
		vehicle_camera.global_position = vehicle_camera.global_position.lerp(target_pos, follow_weight)
		vehicle_camera.look_at(global_position + Vector3.UP, Vector3.UP)
