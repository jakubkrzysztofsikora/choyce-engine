## Asset-contract check for the modular bridge pieces used by the opening route.
## Run: godot --headless --path . -s res://tests/adapters/inbound/test_kenney_bridge_module_assets.gd
extends SceneTree

const MODULES := [
	"res://data/models/kenney/nature_kit/GLB/bridge_center_wood.glb",
	"res://data/models/kenney/nature_kit/GLB/bridge_side_wood.glb",
	"res://data/models/kenney/nature_kit/GLB/bridge_center_woodRound.glb",
	"res://data/models/kenney/nature_kit/GLB/bridge_side_woodRound.glb",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in MODULES:
		var scene := load(path) as PackedScene
		var instance := scene.instantiate() if scene != null else null
		var meshes := _mesh_count(instance)
		if instance == null or meshes == 0:
			_failures.append(path)
			printerr("FAIL: invalid bridge module ", path)
		else:
			print("PASS: bridge module has visible mesh: ", path)
			instance.queue_free()
	if _failures.is_empty():
		print("[test_kenney_bridge_module_assets] OK")
		quit(0)
	else:
		printerr("[test_kenney_bridge_module_assets] FAIL count=", _failures.size())
		quit(1)


func _mesh_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null else 0
	for child in node.get_children():
		count += _mesh_count(child)
	return count
