extends GutTest

# Verifies VoxelTextureRegistry resolves at least 5 ambientCG materials and at
# least 5 glitch overlays. Uses load() so it doesn't depend on Godot's editor
# import step (RegistryLoader.exists() checks the .png on disk).

const VoxelTextureRegistry := preload("res://src/adapters/inbound/gameplay/voxel_texture_registry.gd")

var _reg: VoxelTextureRegistry


func before_each() -> void:
	_reg = VoxelTextureRegistry.new()


func test_at_least_five_materials_registered() -> void:
	var keys := _reg.list_material_keys()
	assert_true(keys.size() >= 5,
		"VoxelTextureRegistry must declare ≥5 material keys; got %d" % keys.size())


func test_at_least_five_overlays_registered() -> void:
	var keys := _reg.list_overlay_keys()
	assert_true(keys.size() >= 5,
		"VoxelTextureRegistry must declare ≥5 overlay keys; got %d" % keys.size())


func test_at_least_five_materials_load_from_disk() -> void:
	var loaded := 0
	for key in _reg.list_material_keys():
		var mat := _reg.get_material(key)
		if mat != null and mat is StandardMaterial3D and mat.albedo_texture != null:
			loaded += 1
	assert_true(loaded >= 5,
		"At least 5 voxel materials must load real textures from disk; got %d" % loaded)


func test_unknown_key_returns_null() -> void:
	assert_null(_reg.get_material("nieistniejacy_klucz"),
		"Unknown material keys must return null, not crash")
	assert_null(_reg.get_overlay("nieistniejacy_overlay"),
		"Unknown overlay keys must return null, not crash")


func test_material_cache_returns_same_instance() -> void:
	var keys := _reg.list_material_keys()
	if keys.is_empty():
		return
	var first_key: String = keys[0]
	var m1 := _reg.get_material(first_key)
	var m2 := _reg.get_material(first_key)
	# If first load failed (no texture on disk), both are null; that's still
	# consistent — only assert when m1 actually resolved.
	if m1 != null:
		assert_same(m1, m2, "Repeated lookups must return the cached material")
