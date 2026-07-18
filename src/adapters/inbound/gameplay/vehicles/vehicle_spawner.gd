## VehicleSpawner.gd - Spawns and manages vehicles in the world
##
## Part of VS-021: Add rare drivable vehicles and bounded bulldozer destruction sandbox
##
## Handles:
## - Vehicle instantiation from templates
## - Vehicle placement in discoverable locations
## - Vehicle activation/deactivation based on distance
##
class_name VehicleSpawner
extends Node


# Vehicle configurations
const VEHICLE_CONFIGS := {
	"simple": {
		"script": "res://src/adapters/inbound/gameplay/vehicles/simple_vehicle.gd",
		"scene": "res://scenes/vehicles/simple_vehicle.tscn",
		# A rare car is the long-distance tool for the 5.76km² sandbox.  It must
		# decisively outpace a 10m/s sprint while remaining controllable on hills.
		"max_speed": 28.0,
		"mass": 1000.0
	},
	"tractor": {
		"script": "res://src/adapters/inbound/gameplay/vehicles/simple_vehicle.gd",
		"scene": "res://scenes/vehicles/tractor.tscn",
		"max_speed": 16.0,
		"mass": 1500.0
	},
	"bulldozer": {
		"script": "res://src/adapters/inbound/gameplay/vehicles/bulldozer.gd",
		"scene": "res://scenes/vehicles/bulldozer.tscn",
		"max_speed": 8.0,
		"mass": 3000.0
	}
}

# Activation distance for performance
const ACTIVATION_RADIUS := 100.0
const DEACTIVATION_RADIUS := 150.0

# Reference to player
var player: Node3D = null
var runtime_root: Node = null
var destruction_tracker: Node = null
var _configured_vehicles_spawned: bool = false

# Spawned vehicles
var spawned_vehicles: Array[VehicleBase] = []


func _ready() -> void:
	if runtime_root == null:
		runtime_root = get_parent()
	# GameplayRuntime injects its player before adding this child. Keep a
	# parent-relative and group fallback for standalone sample scenes, never a
	# hard-coded scene-tree path.
	if player == null:
		if runtime_root != null:
			player = runtime_root.get_node_or_null("PlayerController") as Node3D
		if player == null:
			player = get_tree().get_first_node_in_group("player") as Node3D

	_spawn_configured_vehicles()


func configure(runtime: Node, player_node: Node3D, tracker_node: Node = null) -> void:
	runtime_root = runtime
	player = player_node
	destruction_tracker = tracker_node
	for vehicle in spawned_vehicles:
		_configure_vehicle_dependencies(vehicle)
	if is_inside_tree():
		_spawn_configured_vehicles()


func _process(_delta: float) -> void:
	# CharacterBody3D vehicles remain cheap while keeping their Terrain3D floor
	# snap live. Parking them by distance was coupled to the old wheel solver and
	# produced cars that accepted a rider but had no controllable motion.
	pass


func _spawn_configured_vehicles() -> void:
	if _configured_vehicles_spawned or player == null:
		return
	_configured_vehicles_spawned = true
	# Default vehicle spawns for VS-021
	# These should be moved to world configuration eventually

	var spawns := [
		{
			"type": "tractor",
			"position": Vector3(-100, 0, -50),
			"rotation": PI * 0.5,
			"discoverable": true
		},
		{
			"type": "bulldozer",
			"position": Vector3(80, 0, -120),
			"rotation": 0,
			"discoverable": true
		}
	]

	for spawn in spawns:
		_spawn_vehicle(spawn)


func _spawn_vehicle(spawn_data: Dictionary) -> VehicleBase:
	var vehicle_type: String = String(spawn_data.get("type", "simple"))
	var config: Dictionary = VEHICLE_CONFIGS.get(vehicle_type, {})

	if config.is_empty():
		push_error("Unknown vehicle type: %s" % vehicle_type)
		return null

	var vehicle_scene_path: String = String(config.get("scene", ""))
	var vehicle_script_path: String = String(config.get("script", ""))

	var vehicle_script: Script = load(vehicle_script_path) as Script
	if vehicle_script == null:
		push_warning("Vehicle script is unavailable; skipping %s" % vehicle_type)
		return null

	# Try to load the authored scene first. Some test/embedded scenes are saved
	# with a native VehicleBody3D root and lose their custom script during a
	# stale import. Re-attach the known vehicle script before deciding that the
	# vehicle is invalid, so a scene can retain its meshes/colliders without
	# poisoning the whole gameplay session.
	var vehicle_node: Node = null
	if ResourceLoader.exists(vehicle_scene_path):
		var scene: PackedScene = load(vehicle_scene_path) as PackedScene
		if scene != null:
			vehicle_node = scene.instantiate()
	else:
		# Create from script
		vehicle_node = vehicle_script.new()

	if vehicle_node == null:
		push_error("Failed to create vehicle of type: %s" % vehicle_type)
		return null

	if not (vehicle_node is VehicleBase):
		# Keep the scene root and its authored children, but repair a missing or
		# stale root script when Godot loaded the scene as plain VehicleBody3D.
		vehicle_node.set_script(vehicle_script)
	if not (vehicle_node is VehicleBase):
		push_warning("Vehicle scene is not a VehicleBase; skipping %s" % vehicle_type)
		vehicle_node.queue_free()
		return null
	var vehicle: VehicleBase = vehicle_node as VehicleBase

	# Attach before assigning global transforms so the terrain ground ray has a world.
	var vehicle_parent: Node = runtime_root if runtime_root != null else get_parent()
	if vehicle_parent != null:
		vehicle_parent.add_child(vehicle)
	elif get_tree().current_scene != null:
		get_tree().current_scene.add_child(vehicle)
	else:
		push_error("Cannot spawn vehicle without a runtime scene")
		vehicle.queue_free()
		return null
	var spawn_position: Variant = spawn_data.get("position", Vector3.ZERO)
	vehicle.global_position = spawn_position as Vector3 if spawn_position is Vector3 else Vector3.ZERO
	if spawn_data.has("rotation"):
		vehicle.rotation.y = float(spawn_data["rotation"])
	# The streamed world carries its own relief. Spawn data supplies x/z only,
	# so settle against the actual terrain once the body is inside the scene
	# instead of leaving a vehicle suspended at the global y=0 plane.
	vehicle.call_deferred("snap_to_surface")

	# Apply config overrides.
	if config.has("max_speed"):
		vehicle.max_speed = float(config["max_speed"])
	_configure_vehicle_dependencies(vehicle)

	spawned_vehicles.append(vehicle)
	return vehicle


func _configure_vehicle_dependencies(vehicle: VehicleBase) -> void:
	if vehicle == null or destruction_tracker == null:
		return
	if vehicle.has_method("setup_destruction_tracker"):
		vehicle.call("setup_destruction_tracker", destruction_tracker)


func _activate_vehicle(vehicle: VehicleBase) -> void:
	pass


func _deactivate_vehicle(vehicle: VehicleBase) -> void:
	pass


func get_nearest_vehicle(position: Vector3, radius: float = 5.0) -> VehicleBase:
	var nearest: VehicleBase = null
	var nearest_dist := float(INF)

	for vehicle in spawned_vehicles:
		if vehicle == null or not is_instance_valid(vehicle):
			continue

		var dist := vehicle.global_position.distance_to(position)
		if dist <= radius and dist < nearest_dist:
			nearest = vehicle
			nearest_dist = dist

	return nearest


func cleanup() -> void:
	for vehicle in spawned_vehicles:
		if vehicle != null and is_instance_valid(vehicle):
			vehicle.queue_free()

	spawned_vehicles.clear()
