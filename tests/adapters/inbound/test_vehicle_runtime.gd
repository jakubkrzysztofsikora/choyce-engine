## Vehicle runtime smoke test.
##
## Covers the scene-root type contract and the embedded-runtime path used by
## gameplay tests. A vehicle that cannot be typed as VehicleBase must never be
## allowed to emit a runtime error from the shared gameplay composition root.
extends SceneTree

const GameplayRuntimeScript = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")

const VEHICLE_SCENES := [
	"res://scenes/vehicles/tractor.tscn",
	"res://scenes/vehicles/bulldozer.tscn",
]

var _failures: int = 0
var _fist_attack_received := false
var _tool_used_received := false


func _on_fist_attack(_damage: int, _hit_position: Vector3) -> void:
	_fist_attack_received = true


func _on_tool_used(_tool_id: String, _origin: Vector3, _forward: Vector3) -> void:
	_tool_used_received = true


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
	if scene_path.ends_with("tractor.tscn"):
		var authored_visual := vehicle.get_node_or_null("VehicleVisual") as Node3D
		_assert(authored_visual != null and authored_visual.get_child_count() > 0,
			"tractor spawn uses one supplied coherent vehicle visual")
		_assert(chassis != null and not chassis.visible,
			"tractor hides the old primitive chassis instead of layering it over the ready-made car")

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

	_assert(vehicle is CharacterBody3D,
		"%s uses grounded CharacterBody3D movement rather than streamed wheel contacts" % scene_path)
	var engine_loop := vehicle.get_node_or_null("VehicleEngineIdle") as AudioStreamPlayer3D
	var engine_one_shot := vehicle.get_node_or_null("VehicleEngineOneShot") as AudioStreamPlayer3D
	_assert(engine_loop != null and engine_loop.stream != null and engine_one_shot != null,
		"%s carries local engine loop/start-brake audio nodes" % scene_path)


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
	var engine_loop := vehicle.get_node_or_null("VehicleEngineIdle") as AudioStreamPlayer3D
	_assert(engine_loop != null and engine_loop.playing,
		"%s starts its local engine loop on entry" % scene_path)

	Input.action_press("accelerate")
	var drive_start := vehicle.global_position
	for _frame in 45:
		vehicle._physics_process(1.0 / 60.0)
		await physics_frame
	_assert(absf(vehicle.current_engine_force) > 0.01,
		"%s accepts acceleration without waiting for wheel contacts" % scene_path)
	Input.action_release("accelerate")
	vehicle._physics_process(1.0 / 60.0)
	var horizontal_travel := Vector2(
		vehicle.global_position.x - drive_start.x,
		vehicle.global_position.z - drive_start.z).length()
	_assert(horizontal_travel > 0.08,
		"%s moves with grounded arcade vehicle physics" % scene_path)
	var yaw_before_right := vehicle.rotation.y
	Input.action_press("steer_right")
	vehicle._physics_process(1.0 / 30.0)
	Input.action_release("steer_right")
	_assert(vehicle.rotation.y < yaw_before_right,
		"%s right steering produces rightward (-Y) yaw for a -Z-facing vehicle" % scene_path)
	var chassis_collision := _first_shape(vehicle)
	var collision_floor_y := vehicle.global_position.y
	if chassis_collision != null and chassis_collision.shape is BoxShape3D:
		collision_floor_y += chassis_collision.position.y - (chassis_collision.shape as BoxShape3D).size.y * 0.5
	_assert(collision_floor_y > -0.08,
		"%s collision footprint stays on the ground rather than falling or floating" % scene_path)
	# GameplayRuntime receives E before dynamically spawned vehicles. Exercise
	# that exact route so the generic interaction handler cannot trap a driver.
	var runtime := GameplayRuntimeScript.new()
	runtime._interaction_prompt_panel = PanelContainer.new()
	runtime._interaction_prompt_label = Label.new()
	runtime._interaction_prompt_panel.add_child(runtime._interaction_prompt_label)
	runtime._active_vehicle = vehicle
	runtime._interaction_feedback_until = 0.0
	runtime._tick_world_interactions()
	_assert(runtime._interaction_prompt_panel.visible \
		and runtime._interaction_prompt_label.text == "E / Esc  Wyjdź z pojazdu",
		"%s keeps an exit prompt visible after ordinary interaction feedback expires" % scene_path)
	var exit_event := InputEventAction.new()
	exit_event.action = "exit_vehicle"
	exit_event.pressed = true
	runtime._input(exit_event)
	_assert(not vehicle.is_active and player.visible,
		"%s exits through the runtime E/Escape routing and restores the player" % scene_path)
	_assert(player_camera.current,
		"%s restores the previous player camera on exit" % scene_path)
	# A streamed terrain collision gap must not create an infinite fall during a
	# long vehicle trip. The controller returns to the most recent real contact.
	var safe_position := vehicle.global_position
	vehicle.global_position.y = VehicleBase.VOID_RECOVERY_Y - 4.0
	vehicle._physics_process(1.0 / 60.0)
	_assert(vehicle.global_position.y > VehicleBase.VOID_RECOVERY_Y
		and Vector2(vehicle.global_position.x - safe_position.x, vehicle.global_position.z - safe_position.z).length() < 0.1,
		"%s recovers from a streamed-terrain void at its latest safe contact" % scene_path)
	runtime.free()
	player.queue_free()


func _assert_vehicle_safety_and_fallbacks() -> void:
	var root := get_root()

	# Flat ground for the speed-cap baseline.
	var ground := StaticBody3D.new()
	ground.name = "SafetyGround"
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = BoxShape3D.new()
	(ground_shape.shape as BoxShape3D).size = Vector3(80.0, 1.0, 80.0)
	ground_shape.position.y = -0.5
	ground.add_child(ground_shape)
	root.add_child(ground)

	var vehicle_scene := load("res://scenes/vehicles/tractor.tscn") as PackedScene
	var vehicle := vehicle_scene.instantiate() as VehicleBase
	root.add_child(vehicle)
	vehicle.global_position = Vector3(1000.0, 0.5, 1000.0)

	var player := PlayerController.new()
	player.name = "SafetyPlayer"
	var player_camera := Camera3D.new()
	player_camera.name = "Camera3D"
	player.add_child(player_camera)
	root.add_child(player)
	player.global_position = vehicle.global_position
	await process_frame

	var original_layer := player.collision_layer
	var original_mask := player.collision_mask
	vehicle.enter(player)
	await process_frame

	# 1. Child-safe speed cap: sustained acceleration must never exceed max_speed.
	Input.action_press("accelerate")
	for i in range(120):
		vehicle._physics_process(1.0 / 60.0)
		if i % 6 == 0:
			await process_frame
	Input.action_release("accelerate")
	_assert(abs(vehicle._drive_speed) <= vehicle.max_speed + 0.05,
		"Vehicle speed cap keeps forward speed at or below max_speed")
	_assert(abs(vehicle._drive_speed) >= 0.1,
		"Vehicle actually accelerates before the cap is applied")

	# 2. Drive up a 12-degree ramp and remain grounded / collision-enabled.
	var ramp := StaticBody3D.new()
	ramp.name = "Ramp"
	ramp.position = Vector3(1015.0, 0.0, 1000.0)
	ramp.rotation.x = deg_to_rad(12.0)
	var ramp_shape := CollisionShape3D.new()
	ramp_shape.shape = BoxShape3D.new()
	(ramp_shape.shape as BoxShape3D).size = Vector3(3.0, 0.2, 24.0)
	ramp_shape.position.y = 0.1
	ramp.add_child(ramp_shape)
	root.add_child(ramp)

	vehicle.global_position = Vector3(1015.0, 0.2, 1000.0)
	vehicle.rotation = Vector3.ZERO
	vehicle._drive_speed = 0.0
	var grounded_frames := 0
	Input.action_press("accelerate")
	for i in range(80):
		vehicle._physics_process(1.0 / 60.0)
		if vehicle.is_on_floor():
			grounded_frames += 1
		if i % 6 == 0:
			await process_frame
	Input.action_release("accelerate")
	_assert(grounded_frames >= 30,
		"Vehicle stays grounded while driving up a streamed-terrain ramp")
	_assert(vehicle.global_position.y > 0.6,
		"Vehicle climbs the ramp instead of sliding beneath it")
	_assert(vehicle.get_node_or_null("Chassis") != null,
		"Vehicle chassis persists after ramp traversal")

	# 3. Safe egress fallback when the computed exit point is over a void.
	var safe_ground := vehicle.global_position
	vehicle._last_safe_ground_position = safe_ground
	player.global_position = vehicle.global_position
	# Move the vehicle high above the world so the side exit point is over a void.
	vehicle.global_position = Vector3(vehicle.global_position.x, 60.0, vehicle.global_position.z)
	var void_exit := vehicle.get_exit_position()
	var expected_fallback := vehicle._last_safe_ground_position + vehicle.global_transform.basis.x * 1.5 + Vector3.UP * 0.35
	_assert(void_exit.distance_to(expected_fallback) < 0.1,
		"Vehicle exit falls back to last safe ground position over a void")
	vehicle.global_position = safe_ground

	# 4. Player collision layer/mask are restored after exit.
	vehicle.exit_vehicle()
	await process_frame
	_assert(player.collision_layer == original_layer and player.collision_mask == original_mask,
		"Vehicle exit restores player collision layer and mask")

	# 5. Fist fallback remains usable after exit with no tool equipped.
	_fist_attack_received = false
	if not player.attacked.is_connected(_on_fist_attack):
		player.attacked.connect(_on_fist_attack)
	Input.action_press("attack")
	player._physics_process(1.0 / 60.0)
	Input.action_release("attack")
	await process_frame
	_assert(_fist_attack_received,
		"Unarmed player can still punch after leaving a vehicle")
	if player.attacked.is_connected(_on_fist_attack):
		player.attacked.disconnect(_on_fist_attack)

	# 6. Equipped tool is retained and usable after exit.
	player.equip_tool("tool_axe")
	vehicle.enter(player)
	await process_frame
	vehicle.exit_vehicle()
	await process_frame
	_assert(player.has_equipped_tool("tool_axe"),
		"Player keeps the equipped tool after vehicle exit")
	# Drain any attack cooldown inherited from the fist-fallback swing.
	for i in range(40):
		player._physics_process(1.0 / 60.0)
		if i % 6 == 0:
			await process_frame
	_tool_used_received = false
	if not player.tool_used.is_connected(_on_tool_used):
		player.tool_used.connect(_on_tool_used)
	Input.action_press("attack")
	player._physics_process(1.0 / 60.0)
	Input.action_release("attack")
	await process_frame
	_assert(_tool_used_received,
		"Equipped tool is still usable after vehicle exit")
	if player.tool_used.is_connected(_on_tool_used):
		player.tool_used.disconnect(_on_tool_used)

	vehicle.queue_free()
	player.queue_free()
	ground.queue_free()
	ramp.queue_free()
	await process_frame


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
	var car_config: Dictionary = VehicleSpawner.VEHICLE_CONFIGS["simple"]
	_assert(float(car_config["max_speed"]) >= PlayerController.SPRINT_SPEED * 2.5,
		"rare cars materially outpace sprinting for 5km² exploration")
	spawner.cleanup()
	embedded_runtime.queue_free()
	ground.queue_free()
	await _assert_vehicle_safety_and_fallbacks()
	quit(_failures)
