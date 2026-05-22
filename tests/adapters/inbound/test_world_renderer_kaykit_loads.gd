## tests/adapters/inbound/test_world_renderer_kaykit_loads.gd
##
## Asserts that the KayKit / Quaternius CC0 GLBs imported per
## thoughts/shared/research/free-assets-2026-05-21.md are referenced by
## WorldRenderer.PROP_GLTF_MAP / CHARACTER_GLTF and resolve on disk.
##
## At minimum 3 new asset paths (dungeon props + character rigs) must exist.
extends SceneTree

const WorldRenderer = preload("res://src/adapters/inbound/gameplay/world_renderer.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var checked := 0
	var missing: Array[String] = []

	# Dungeon props — must be registered in PROP_GLTF_MAP under Polish keys.
	var prop_keys := [
		"mur",
		"kolumna",
		"kamienna_płyta",
		"pochodnia",
		"beczka",
		"pajęczyna",
		"skrzynia_skarbów",
	]
	for k in prop_keys:
		if not WorldRenderer.PROP_GLTF_MAP.has(k):
			missing.append("PROP_GLTF_MAP missing key: %s" % k)
			continue
		var p: String = WorldRenderer.PROP_GLTF_MAP[k]
		if not _resource_present(p):
			missing.append("PROP missing on disk: %s -> %s" % [k, p])
		else:
			checked += 1

	# Character rigs — must be registered in CHARACTER_GLTF.
	var char_keys := ["ninja", "wojownik", "szkielet", "mag"]
	for k in char_keys:
		if not WorldRenderer.CHARACTER_GLTF.has(k):
			missing.append("CHARACTER_GLTF missing key: %s" % k)
			continue
		var p: String = WorldRenderer.CHARACTER_GLTF[k]
		if not _resource_present(p):
			missing.append("CHAR missing on disk: %s -> %s" % [k, p])
		else:
			checked += 1

	if not missing.is_empty():
		print("FAIL: %d issues" % missing.size())
		for m in missing:
			print("  - %s" % m)
		quit(1)
		return

	if checked < 3:
		print("FAIL: only %d new paths resolved, need >= 3" % checked)
		quit(1)
		return

	print("WORLD_RENDERER_KAYKIT_LOADS_TEST: PASS (%d paths verified)" % checked)
	quit(0)


# Godot's ResourceLoader.exists() returns false for raw .glb files until they
# are imported by the editor. Fall back to FileAccess.file_exists() to assert
# the asset is on disk — that is what the task spec requires.
func _resource_present(p: String) -> bool:
	if ResourceLoader.exists(p):
		return true
	return FileAccess.file_exists(p)
