## Regression: imported characters must meet the controller's floor contact
## plane. A floating visible model makes the otherwise-grounded player look
## broken in every Adventure location.
extends SceneTree

const GameplayRuntimeScene = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run() -> void:
	var runtime := GameplayRuntimeScene.instantiate() as GameplayRuntime
	get_root().add_child(runtime)
	await process_frame
	var player := runtime.get_node_or_null("PlayerController") as PlayerController
	_assert(player != null, "gameplay runtime provides a player controller")
	if player != null:
		var visual := player.get_node_or_null("CharacterMesh") as Node3D
		_assert(visual != null, "player has a visible character model")
		if visual != null:
			var lowest_y := INF
			for mesh_variant in visual.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := mesh_variant as MeshInstance3D
				if mesh_instance == null or mesh_instance.mesh == null:
					continue
				var mesh_aabb := mesh_instance.get_aabb()
				for corner_index in range(8):
					var local_corner := mesh_aabb.get_endpoint(corner_index)
					var visual_local_corner := visual.to_local(mesh_instance.to_global(local_corner))
					lowest_y = minf(lowest_y, visual_local_corner.y)
			_assert(is_finite(lowest_y) and absf(lowest_y) <= 0.025,
				"character feet are grounded at the controller contact plane")
	runtime.queue_free()
	quit(_exit_code)
