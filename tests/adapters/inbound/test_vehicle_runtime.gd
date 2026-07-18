## Vehicle runtime smoke test.
##
## Covers the scene-root type contract and the embedded-runtime path used by
## gameplay tests. A vehicle that cannot be typed as VehicleBase must never be
## allowed to emit a runtime error from the shared gameplay composition root.
extends SceneTree


const VEHICLE_SCENES := [
	"res://scenes/vehicles/tractor.tscn",
	"res://scenes/vehicles/bulldozer.tscn",
]

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_failures += 1


func _first_shape(node: Node) -> CollisionShape3D:
	for child in node.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


func _assert_vehicle_resources(vehicle: VehicleBase, scene_path: String) -> void:
	var chassis := vehicle.get_node_or_null("Chassis") as MeshInstance3D
	_assert(chassis != null and chassis.mesh != null,
		"%s has a non-null chassis mesh" % scene_path)
	if chassis != null and chassis.mesh != null:
		_assert(chassis.mesh.get_aabb().size.length() > 1.0,
			"%s chassis mesh has vehicle-scale dimensions" % scene_path)

	var body_shape := _first_shape(vehicle)
	_assert(body_shape != null and body_shape.shape != null,
		"%s has a non-null body collision resource" % scene_path)
	if body_shape != null and body_shape.shape is BoxShape3D:
		var body_size := (body_shape.shape as BoxShape3D).size
		_assert(body_size.x >= 1.5 and body_size.y >= 1.0 and body_size.z >= 2.5,
			"%s collision fits the authored vehicle assembly" % scene_path)

	for area_name in ["EntryPoint", "ExitPoint"]:
		var area := vehicle.get_node_or_null(area_name) as Area3D
		var area_shape := _first_shape(area) if area != null else null
		_assert(area != null and area_shape != null and area_shape.shape != null,
			"%s %s has a usable CollisionShape3D" % [scene_path, area_name])

	var visual_count := 0
	for visual in vehicle.find_children("*", "MeshInstance3D", true, false):
		if (visual as MeshInstance3D).mesh != null:
			visual_count += 1
	_assert(visual_count >= 10,
		"%s is a visible assembled model, not a null placeholder" % scene_path)

	var wheels := vehicle.find_children("*", "VehicleWheel3D", true, false)
	_assert(wheels.size() == 4, "%s creates four VehicleWheel3D wheels" % scene_path)
	var steering_wheels := 0
	for wheel_variant in wheels:
		var wheel := wheel_variant as VehicleWheel3D
		var tire := wheel.get_node_or_null("Tire") as MeshInstance3D
		_assert(wheel.wheel_radius > 0.4 and tire != null and tire.mesh != null,
			"%s wheel has physics dimensions and a visible tire" % scene_path)
		_assert(wheel.use_as_traction,
			"%s wheel receives bounded engine force" % scene_path)
		if wheel.use_as_steering:
			steering_wheels += 1
	_assert(steering_wheels == 2,
		"%s uses one steering axle" % scene_path)


func _assert_vehicle_controls(vehicle: VehicleBase, scene_path: String) -> void:
	var player := PlayerController.new()
	player.name = "TestPlayer"
	var player_camera := Camera3D.new()
	player_camera.name = "Camera3D"
	player.add_child(player_camera)
	get_root().add_child(player)
	player_camera.make_current()
	vehicle.enter(player)
	_assert(vehicle.is_active and vehicle.current_player == player,
		"%s can be entered" % scene_path)
	_assert(vehicle.vehicle_camera != null and vehicle.vehicle_camera.current,
		"%s hands camera control to the vehicle" % scene_path)

	Input.action_press("accelerate")
	var drive_start := vehicle.global_position
	for _frame in 45:
		vehicle._physics_process(1.0 / 60.0)
		await physics_frame
	var driven_wheels := 0
	for wheel in vehicle.find_children("*", "VehicleWheel3D", true, false):
		if absf((wheel as VehicleWheel3D).engine_force) > 0.01:
			driven_wheels += 1
	_assert(driven_wheels == 4,
		"%s acceleration reaches real VehicleWheel3D children" % scene_path)
	Input.action_release("accelerate")
	vehicle._physics_process(1.0 / 60.0)
	var horizontal_travel := Vector2(
		vehicle.global_position.x - drive_start.x,
		vehicle.global_position.z - drive_start.z).length()
	_assert(horizontal_travel > 0.08,
		"%s moves through VehicleWheel3D physics" % scene_path)
	_assert(vehicle.global_position.y > -0.25,
		"%s collision and suspension hold the body above the ground" % scene_path)

	vehicle.exit_vehicle()
	_assert(not vehicle.is_active and player.visible,
		"%s can be exited and restores the player" % scene_path)
	_assert(player_camera.current,
		"%s restores the previous player camera on exit" % scene_path)
	player.queue_free()


func _run() -> void:
	var ground := StaticBody3D.new()
	ground.name = "VehicleTestGround"
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(40, 0.5, 40)
	ground_shape.shape = ground_box
	ground_shape.position.y = -0.25
	ground.add_child(ground_shape)
	get_root().add_child(ground)

	for scene_path in VEHICLE_SCENES:
		var packed := load(scene_path) as PackedScene
		var instance := packed.instantiate() as Node if packed != null else null
		_assert(instance != null, "%s instantiates" % scene_path)
		_assert(instance is VehicleBase, "%s root extends VehicleBase" % scene_path)
		if instance is VehicleBase:
			var vehicle := instance as VehicleBase
			get_root().add_child(vehicle)
			await process_frame
			_assert_vehicle_resources(vehicle, scene_path)
			await _assert_vehicle_controls(vehicle, scene_path)
			vehicle.queue_free()
			await process_frame
		elif instance != null:
			instance.free()

	var bulldozer_scene := load("res://scenes/vehicles/bulldozer.tscn") as PackedScene
	var bulldozer := bulldozer_scene.instantiate() as Bulldozer
	var untagged := Node3D.new()
	var temporary := Node3D.new()
	temporary.set_meta("destruction_category", "temporary_scenery")
	var protected_build := Node3D.new()
	protected_build.set_meta("destruction_category", "build_block")
	protected_build.add_to_group("homestead")
	_assert(not bulldozer._can_destroy(untagged),
		"bulldozer destruction denies untagged world objects")
	_assert(bulldozer._can_destroy(temporary),
		"bulldozer destruction allows explicit temporary scenery")
	_assert(not bulldozer._can_destroy(protected_build),
		"protected tags override destructible categories")
	untagged.free()
	temporary.free()
	protected_build.free()
	bulldozer.free()

	var embedded_runtime := Node3D.new()
	embedded_runtime.name = "EmbeddedRuntime"
	get_root().add_child(embedded_runtime)
	var player := Node3D.new()
	player.name = "PlayerController"
	embedded_runtime.add_child(player)

	var spawner := VehicleSpawner.new()
	spawner.name = "VehicleSpawner"
	embedded_runtime.add_child(spawner)
	spawner.configure(embedded_runtime, player)
	await process_frame
	_assert(spawner.spawned_vehicles.size() == 2,
		"embedded runtime spawns only valid VehicleBase vehicles")
	for vehicle in spawner.spawned_vehicles:
		_assert(is_instance_valid(vehicle) and vehicle.is_inside_tree(),
			"spawned vehicle is attached before its global transform is assigned")
		_assert(not vehicle.is_active,
			"proximity does not activate controls before entry")
		_assert(_first_shape(vehicle) != null and _first_shape(vehicle).shape != null,
			"spawned vehicle retains its authored collision resource")
	spawner.cleanup()
	embedded_runtime.queue_free()
	ground.queue_free()
	await process_frame
	await process_frame
	quit(_failures)
