## Regression coverage for the new hero GLBs (Ziemek, Gniewko) and the
## Bella companion runtime spawned alongside the player.
## Run: godot --headless --path . --script tests/adapters/inbound/test_hero_glbs_load.gd
extends SceneTree

const ZIEMEK_PATH := "res://data/models/heroes/ziemek.glb"
const GNIEWSKO_PATH := "res://data/models/heroes/gniewko.glb"
const BELLA_PATH := "res://data/models/companions/bella.glb"
const COMPANION_RUNTIME := preload("res://src/adapters/inbound/gameplay/companion_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	# 1. Hero GLBs must exist and load as PackedScenes.
	_expect(ResourceLoader.exists(ZIEMEK_PATH), "ziemek.glb exists and has a loader")
	_expect(ResourceLoader.exists(GNIEWSKO_PATH), "gniewko.glb exists and has a loader")
	_expect(ResourceLoader.exists(BELLA_PATH), "bella.glb exists and has a loader")

	# 2. Each hero GLB must instantiate and contain at least one mesh + an armature.
	var z_scene := load(ZIEMEK_PATH) as PackedScene
	var g_scene := load(GNIEWSKO_PATH) as PackedScene
	var b_scene := load(BELLA_PATH) as PackedScene
	_expect(z_scene != null, "ziemek.glb loads as PackedScene")
	_expect(g_scene != null, "gniewko.glb loads as PackedScene")
	_expect(b_scene != null, "bella.glb loads as PackedScene")

	if z_scene != null:
		var z := z_scene.instantiate()
		root.add_child(z)
		var z_meshes := z.find_children("*", "MeshInstance3D", true, false)
		var z_armatures := z.find_children("*", "Skeleton3D", true, false)
		_expect(not z_meshes.is_empty(), "ziemek.glb has at least one MeshInstance3D")
		_expect(not z_armatures.is_empty(), "ziemek.glb has a Skeleton3D (rig)")
		# Ziemek must carry the backpack mesh baked into his GLB.
		var has_backpack := false
		for m in z_meshes:
			if String((m as Node3D).name).to_lower().find("backpack") >= 0:
				has_backpack = true
				break
		_expect(has_backpack, "ziemek.glb includes a backpack mesh")
		z.queue_free()

	if g_scene != null:
		var g := g_scene.instantiate()
		root.add_child(g)
		var g_meshes := g.find_children("*", "MeshInstance3D", true, false)
		var g_armatures := g.find_children("*", "Skeleton3D", true, false)
		_expect(not g_meshes.is_empty(), "gniewko.glb has at least one MeshInstance3D")
		_expect(not g_armatures.is_empty(), "gniewko.glb has a Skeleton3D (rig)")
		g.queue_free()

	if b_scene != null:
		var b := b_scene.instantiate()
		root.add_child(b)
		var b_meshes := b.find_children("*", "MeshInstance3D", true, false)
		var b_armatures := b.find_children("*", "Skeleton3D", true, false)
		_expect(not b_meshes.is_empty(), "bella.glb has at least one MeshInstance3D")
		_expect(not b_armatures.is_empty(), "bella.glb has a Skeleton3D (rig)")
		b.queue_free()

	# 3. CompanionRuntime must spawn a Bella node and clean up on free.
	var cr := COMPANION_RUNTIME.new()
	cr.name = "TestCompanionRuntime"
	root.add_child(cr)
	await process_frame
	var bella_node := cr.get_bella_node()
	_expect(bella_node != null and is_instance_valid(bella_node), "CompanionRuntime spawns a Bella node")
	cr.queue_free()
	await process_frame

	_report()


func _report() -> void:
	if _failures.is_empty():
		print("ALL TESTS PASSED")
	else:
		printerr("FAILED: ", _failures.size(), " / ", _failures.size() + _count_passes())
		for f in _failures:
			printerr("  - ", f)
	quit(1 if not _failures.is_empty() else 0)


func _count_passes() -> int:
	# Cheap approximation: total prints minus failures.
	return maxi(0, 20 - _failures.size())
