## End-to-end sandbox regression: a real authored resource feeds a simple craft.
extends SceneTree

const GAMEPLAY_SCENE = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")
const RULES_RUNTIME = preload("res://src/adapters/inbound/gameplay/godot_rules_runtime_adapter.gd")
const RULE_COMPILER = preload("res://src/application/rule_compiler_service.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_failures += 1


func _run() -> void:
	var runtime := GAMEPLAY_SCENE.instantiate() as GameplayRuntime
	get_root().add_child(runtime)
	await process_frame
	var rules := RULES_RUNTIME.new()
	runtime.setup_rules(rules, RULE_COMPILER.new())
	var world := World.new("sandbox_loop", "Sandbox loop")
	world.theme = "adventure"
	runtime.start_session(world, Session.new("sandbox_loop_session", world.world_id))
	for _frame in 90:
		await physics_frame
	var player := runtime.get_node_or_null("PlayerController") as PlayerController
	_assert(player != null and player.is_physics_processing(),
		"Adventure session always re-enables player physics after a reused runtime")
	_assert(player != null and player.is_on_floor(),
		"Adventure spawn settles the playable character on the active terrain")
	if player != null:
		var visual_floor_y := player.global_position.y + player._character_visual_ground_y + _lowest_visual_mesh_y(player._character_mesh)
		_assert(absf(visual_floor_y) < 0.06,
			"Adventure hero's rendered feet meet the legacy safety floor rather than hovering")
		print("INFO: adventure_player_root_y=%.3f visual_floor_y=%.3f" % [player.global_position.y, visual_floor_y])

	var wood_anchor: Node3D = null
	for candidate in get_nodes_in_group("world_interactable"):
		if candidate is Node3D and String(candidate.get_meta("interaction_action", "")) == "gather_wood":
			wood_anchor = candidate as Node3D
			break
	_assert(wood_anchor != null, "opening exposes a real wood-gathering interaction anchor")
	if wood_anchor != null:
		runtime._gather_world_resource(wood_anchor)
		var inventory := rules.get_context_value("inventory") as Dictionary
		_assert(int(inventory.get("wood_oak", 0)) == 1,
			"gathering the authored wood resource updates the rules-runtime inventory")
		runtime._craft_home_meal()
		inventory = rules.get_context_value("inventory") as Dictionary
		_assert(int(inventory.get("wood_oak", 0)) == 0 and int(inventory.get("meal", 0)) == 1,
			"the starter kitchen converts gathered wood into one child-friendly meal")
		runtime._craft_home_meal()
		inventory = rules.get_context_value("inventory") as Dictionary
		_assert(int(inventory.get("meal", 0)) == 2,
			"the first sandbox meal stays forgiving and never depends on a timer or grind gate")

	runtime.end_session()
	runtime.queue_free()
	await process_frame
	quit(_failures)


func _lowest_visual_mesh_y(character_root: Node3D) -> float:
	if character_root == null:
		return INF
	var lowest_y := INF
	for mesh_variant in character_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_variant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_aabb := mesh_instance.mesh.get_aabb()
		for corner_index in range(8):
			var local_corner := mesh_aabb.get_endpoint(corner_index)
			var character_local_corner := character_root.to_local(mesh_instance.to_global(local_corner))
			lowest_y = minf(lowest_y, character_local_corner.y)
	return lowest_y
