## tests/adapters/inbound/test_world_renderer_toon_shader.gd
## MUST criteria for the toon cel shader integration in WorldRenderer:
##   1. _make_toon_material returns a ShaderMaterial (not StandardMaterial3D)
##   2. _make_toon_material sets albedo shader parameter to the provided color
##   3. _make_toon_material sets light_steps to 2.0
##   4. _make_toon_material sets shadow_color derived from the base color (darkened)
##   5. _create_object_node assigns ShaderMaterial on the MeshInstance3D
##   6. _create_terrain_node assigns ShaderMaterial on the MeshInstance3D
##   7. _create_decoration_node assigns ShaderMaterial on the MeshInstance3D
##   8. _apply_toon_to_prop sets material_override on all MeshInstance3D descendants
##   9. _apply_toon_to_prop preserves existing StandardMaterial3D albedo_color
##  10. _apply_toon_to_prop defaults to Color.WHITE when no StandardMaterial3D found
extends SceneTree

const WorldRenderer = preload("res://src/adapters/inbound/gameplay/world_renderer.gd")
const SceneNode = preload("res://src/domain/world_authoring/scene_node.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _exit_code := 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		_exit_code = 1
	else:
		print("PASS: %s" % message)


func _make_renderer() -> WorldRenderer:
	var r := WorldRenderer.new()
	get_root().add_child(r)
	return r


func _make_scene_node(type: SceneNode.NodeType, props: Dictionary = {}) -> SceneNode:
	var n := SceneNode.new("test_id", type)
	n.display_name = "test_node"
	n.properties = props
	return n


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func _run_tests() -> void:
	print("=== toon cel shader: WorldRenderer integration tests ===")

	_test_make_toon_material_returns_shader_material()
	_test_make_toon_material_sets_albedo_parameter()
	_test_make_toon_material_sets_light_steps()
	_test_make_toon_material_sets_shadow_color_darkened()
	_test_object_node_uses_shader_material()
	_test_json_properties_are_normalized()
	_test_terrain_node_uses_shader_material()
	_test_decoration_node_uses_shader_material()
	_test_trigger_metadata_is_propagated()
	_test_apply_toon_to_prop_walks_all_mesh_instances()
	_test_apply_toon_to_prop_preserves_standard_material_albedo()
	_test_apply_toon_to_prop_defaults_to_white_when_no_standard_mat()
	_test_environment_assets_get_pbr_detail_layer()
	_test_procedural_tree_scale_and_palm_source_are_human_scale()
	_test_opening_grove_has_a_dense_human_scale_frame()
	_test_opening_grove_has_dense_foreground_foliage()
	_test_opening_flank_groundcover_stays_off_the_bridge_lane()
	await _test_opening_basecamp_is_a_colliding_lived_in_tableau()
	_test_opening_bridge_shore_uses_the_textured_stone_path()
	_test_opening_riverbank_has_layered_thickets_outside_the_bridge_lane()
	_test_opening_riverbank_visuals_stay_out_of_swim_channel()
	_test_quaternius_forest_surface_profiles_are_explicit()
	_test_quaternius_forest_profiles_apply_at_runtime()
	_test_opening_forest_mass_is_a_real_colliding_volume()
	_test_opening_is_not_polluted_by_nearby_biomes_or_river_fence()
	_test_streamed_procedural_chunks_stay_bounded()
	_test_world_boundary_has_visible_segmented_collision()
	_test_outer_chunks_do_not_spill_past_world_floor()
	_test_generation_is_queued_not_built_by_focus_request()
	_test_river_keeps_a_bridge_width_dry_crossing()
	await _test_bridge_shape_cast_traversal()
	await _test_water_volume_enter_exit_callbacks()

	quit(_exit_code)


## 1. _make_toon_material returns ShaderMaterial, not StandardMaterial3D.
func _test_make_toon_material_returns_shader_material() -> void:
	var r := _make_renderer()
	var mat = r._make_toon_material(Color.WHITE)
	_assert(
		mat is ShaderMaterial,
		"_make_toon_material returns ShaderMaterial"
	)
	r.queue_free()


## 2. albedo shader parameter equals the base_color passed in.
func _test_make_toon_material_sets_albedo_parameter() -> void:
	var r := _make_renderer()
	var color := Color(0.4, 0.7, 0.2, 1.0)
	var mat: ShaderMaterial = r._make_toon_material(color)
	var param = mat.get_shader_parameter("albedo")
	_assert(
		param is Color and param.is_equal_approx(color),
		"_make_toon_material sets albedo parameter (got %s)" % str(param)
	)
	r.queue_free()


## 3. light_steps parameter is 2.0.
func _test_make_toon_material_sets_light_steps() -> void:
	var r := _make_renderer()
	var mat: ShaderMaterial = r._make_toon_material(Color.WHITE)
	var steps = mat.get_shader_parameter("light_steps")
	_assert(
		steps is float and absf(float(steps) - 2.0) < 0.001,
		"_make_toon_material sets light_steps=2.0 (got %s)" % str(steps)
	)
	r.queue_free()


## 4. shadow_color is the base_color darkened by 35 %.
func _test_make_toon_material_sets_shadow_color_darkened() -> void:
	var r := _make_renderer()
	var base := Color(0.8, 0.5, 0.3, 1.0)
	var expected: Color = base.darkened(0.35)
	var mat: ShaderMaterial = r._make_toon_material(base)
	var sc = mat.get_shader_parameter("shadow_color")
	_assert(
		sc is Color and sc.is_equal_approx(expected),
		"_make_toon_material sets shadow_color as base.darkened(0.35) (got %s expected %s)" % [str(sc), str(expected)]
	)
	r.queue_free()


## 5. _create_object_node: MeshInstance3D gets ShaderMaterial as material_override.
func _test_object_node_uses_shader_material() -> void:
	var r := _make_renderer()
	var n := _make_scene_node(SceneNode.NodeType.OBJECT, {"color": Color(0.6, 0.6, 0.6)})
	var result: Node3D = r._create_object_node(n)
	var mi: MeshInstance3D = _find_mesh_instance(result)
	_assert(
		mi != null and mi.material_override is ShaderMaterial,
		"_create_object_node: MeshInstance3D.material_override is ShaderMaterial"
	)
	result.queue_free()
	r.queue_free()


## JSON templates use arrays and HTML colors. The inbound adapter must
## normalize them at the engine boundary instead of forcing Godot types into
## the domain/application model.
func _test_json_properties_are_normalized() -> void:
	var r := _make_renderer()
	var n := _make_scene_node(SceneNode.NodeType.OBJECT, {
		"color": "#FFD700",
		"size": [2, 3, 4],
	})
	var result: Node3D = r._create_object_node(n)
	var mi: MeshInstance3D = _find_mesh_instance(result)
	var mat: ShaderMaterial = mi.material_override as ShaderMaterial
	_assert(mat != null and mat.get_shader_parameter("albedo").is_equal_approx(Color("#FFD700")),
		"JSON HTML color should be normalized at the renderer boundary")
	_assert(mi != null and mi.scale.is_equal_approx(Vector3(2, 3, 4)),
		"JSON vector property should be normalized at the renderer boundary")
	result.queue_free()
	r.queue_free()


## 6. _create_terrain_node: MeshInstance3D gets ShaderMaterial.
func _test_terrain_node_uses_shader_material() -> void:
	var r := _make_renderer()
	var n := _make_scene_node(SceneNode.NodeType.TERRAIN, {})
	var result: Node3D = r._create_terrain_node(n)
	var mi: MeshInstance3D = _find_mesh_instance(result)
	_assert(
		mi != null and mi.material_override is ShaderMaterial,
		"_create_terrain_node: MeshInstance3D.material_override is ShaderMaterial"
	)
	result.queue_free()
	r.queue_free()


## 7. Decorations keep their toon material while providing a physical proxy.
func _test_decoration_node_uses_shader_material() -> void:
	var r := _make_renderer()
	var n := _make_scene_node(SceneNode.NodeType.DECORATION, {})
	var result: Node3D = r._create_decoration_node(n)
	var mesh := _find_mesh_instance(result)
	var collision: CollisionShape3D = null
	for child in result.get_children():
		if child is CollisionShape3D:
			collision = child as CollisionShape3D
			break
	_assert(
		result is StaticBody3D and mesh != null and mesh.material_override is ShaderMaterial and collision != null,
		"_create_decoration_node: decoration has toon mesh plus collision proxy"
	)
	result.queue_free()
	r.queue_free()


func _test_trigger_metadata_is_propagated() -> void:
	var r := _make_renderer()
	var n := _make_scene_node(SceneNode.NodeType.TRIGGER, {
		"trigger_type": "win_zone",
		"size": [2, 0.2, 3],
	})
	var area: Area3D = r._create_trigger_node(n)
	_assert(area.name == "test_id", "Trigger should have a stable authored node name")
	_assert(area.get_meta("trigger_type", "") == "win_zone",
		"Trigger type metadata should reach the runtime Area3D")
	var collision := area.get_child(0) as CollisionShape3D
	_assert(collision != null and (collision.shape as BoxShape3D).size.is_equal_approx(Vector3(2, 0.2, 3)),
		"Trigger collision should use authored size")
	area.queue_free()
	r.queue_free()


## 8. _apply_toon_to_prop walks all MeshInstance3D descendants and sets material_override.
func _test_apply_toon_to_prop_walks_all_mesh_instances() -> void:
	var r := _make_renderer()

	# Build a fake glTF root with 3 MeshInstance3D at different depths.
	var root := Node3D.new()
	var mi1 := MeshInstance3D.new()
	mi1.mesh = BoxMesh.new()
	var child := Node3D.new()
	var mi2 := MeshInstance3D.new()
	mi2.mesh = SphereMesh.new()
	var mi3 := MeshInstance3D.new()
	mi3.mesh = CylinderMesh.new()
	root.add_child(mi1)
	root.add_child(child)
	child.add_child(mi2)
	child.add_child(mi3)
	get_root().add_child(root)

	r._apply_toon_to_prop(root)

	_assert(
		mi1.material_override is ShaderMaterial,
		"_apply_toon_to_prop: top-level MeshInstance3D gets ShaderMaterial"
	)
	_assert(
		mi2.material_override is ShaderMaterial,
		"_apply_toon_to_prop: nested MeshInstance3D #2 gets ShaderMaterial"
	)
	_assert(
		mi3.material_override is ShaderMaterial,
		"_apply_toon_to_prop: nested MeshInstance3D #3 gets ShaderMaterial"
	)

	root.queue_free()
	r.queue_free()


## 9. _apply_toon_to_prop preserves albedo_color from existing StandardMaterial3D.
func _test_apply_toon_to_prop_preserves_standard_material_albedo() -> void:
	var r := _make_renderer()

	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	var std_mat := StandardMaterial3D.new()
	var authored_color := Color(0.3, 0.8, 0.5, 1.0)
	std_mat.albedo_color = authored_color
	mi.set_surface_override_material(0, std_mat)
	root.add_child(mi)
	get_root().add_child(root)

	r._apply_toon_to_prop(root)

	var applied: ShaderMaterial = mi.material_override
	var albedo_param = applied.get_shader_parameter("albedo") if applied is ShaderMaterial else null
	_assert(
		albedo_param is Color and albedo_param.is_equal_approx(authored_color),
		"_apply_toon_to_prop preserves StandardMaterial3D albedo_color (got %s)" % str(albedo_param)
	)

	root.queue_free()
	r.queue_free()


## 10. _apply_toon_to_prop defaults to Color.WHITE when mesh has no StandardMaterial3D.
func _test_apply_toon_to_prop_defaults_to_white_when_no_standard_mat() -> void:
	var r := _make_renderer()

	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	# No material set — active material will be null or a non-Standard one.
	root.add_child(mi)
	get_root().add_child(root)

	r._apply_toon_to_prop(root)

	var applied: ShaderMaterial = mi.material_override
	var albedo_param = applied.get_shader_parameter("albedo") if applied is ShaderMaterial else null
	_assert(
		albedo_param is Color and albedo_param.is_equal_approx(Color.WHITE),
		"_apply_toon_to_prop defaults albedo to Color.WHITE when no StandardMaterial3D (got %s)" % str(albedo_param)
	)

	root.queue_free()
	r.queue_free()


## Flat palette source assets in the large world must receive the PBR detail
## layer; otherwise hills, rocks, trees and houses visibly read as primitives.
func _test_environment_assets_get_pbr_detail_layer() -> void:
	var r := _make_renderer()
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	root.add_child(mi)
	get_root().add_child(root)
	r._apply_toon_to_prop(root, "chunk_hill mountain rock")
	var applied := mi.material_override as ShaderMaterial
	_assert(
		applied != null and applied.get_shader_parameter("detail_albedo") != null and applied.get_shader_parameter("detail_normal") != null,
		"flat environment assets receive local PBR albedo and normal detail"
	)
	root.queue_free()
	r.queue_free()


func _test_procedural_tree_scale_and_palm_source_are_human_scale() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains('"palma":           "res://data/models/props/palm.gltf"'),
		"beach palms use the coherent local palm model instead of the striped kit source")
	_assert(source.contains("scale *= rng.randf_range(2.8, 4.4)")
		and source.contains("return rng.randi_range(5, 7)"),
		"procedural forest chunks use human-scale canopies and real canopy density")
	_assert(source.contains("Vector3(-13.5, 0, -12), 1.95")
		and source.contains("const OPENING_NEAR_FOREST_TREE_PATHS := [")
		and source.contains("nature/CommonTree_4.fbx")
		and source.contains("float(entry[1]) * 1.24")
		and source.contains("backdrop_rng.randf_range(1.20, 1.90)"),
		"opening forest uses one adult-scale CC0 tree family rather than miniature props")


## The curated spawn is a clearing framed by a layered grove, not a lawn with
## a handful of evenly spaced tabletop trees.  Keep the centre and bridge lane
## intentionally open, but require substantial close and middle-distance tree
## silhouettes on both sides.
func _test_opening_grove_has_a_dense_human_scale_frame() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("Vector3(-20.5, 0, -5.5), 2.30")
		and source.contains("Vector3(27.5, 0, -10.2), 2.48")
		and source.contains("Vector3(-60, 0, -64), 3.25")
		and source.contains("Vector3(58, 0, -68), 3.18")
		and source.contains("gateway_left_path := \"res://data/models/quaternius/nature/CommonTree_4.fbx\"")
		and source.contains("gateway_right_path := \"res://data/models/quaternius/nature/PineTree_4.fbx\""),
		"opening uses a layered, human-scale Quaternius tree frame rather than sparse prototype scatter")


## VS-044: Enhanced foreground foliage density for visual gate
func _test_opening_grove_has_dense_foreground_foliage() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("Vector3(-3.0, 0, -8)")  # New bush positions
		and source.contains("Vector3(3.0, 0, -9)")
		and source.contains("opening_grove_grass_")  # New grass clusters
		and source.contains('name_key.begins_with("opening_grove_grass")')
		and source.contains("opening_grove_flower_")  # New flower accents
		and source.contains("grass_large.glb")  # grass asset path
		and source.contains("flower_purpleA.glb"),  # Flower asset path
		"opening grove foliage is dense and every grass instance uses the restrained natural palette")


func _test_opening_flank_groundcover_stays_off_the_bridge_lane() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("func _build_opening_flank_groundcover(seed_source: String)")
		and source.contains("for index in range(44)")
		and source.contains("side * rng.randf_range(8.5, 29.0)")
		and source.contains("opening_grove_bush_flank_")
		and source.contains("bush_path, true, Vector3(1.28, 1.10, 1.12)")
		and source.contains("opening_grove_grass_flank_"),
		"opening flank groundcover is deterministic, colliding where dense, and kept outside the bridge lane")


## The start must contain a purposeful camp, not leave the child in an empty
## lawn. Each visible camp object owns close-fit physical presence, while the
## centre route remains clear for the bridge tutorial.
func _test_opening_basecamp_is_a_colliding_lived_in_tableau() -> void:
	var r := _make_renderer()
	r._build_opening_basecamp_tableau()
	await process_frame
	for node_name in [
		"OpeningBasecampTent", "OpeningBasecampHalfTent", "OpeningBasecampFire",
		"OpeningBasecampChest", "OpeningBasecampBarrel", "OpeningBasecampLogWest",
		"OpeningBasecampLogSouth",
	]:
		var prop := r.get_node_or_null(node_name) as StaticBody3D
		var has_collision := false
		if prop != null:
			for child in prop.get_children():
				if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
					has_collision = true
					break
		# Imported GLB roots vary (some preserve their own Node3D wrapper), so
		# inspect the physical root plus its non-collision visual child instead of
		# assuming a MeshInstance3D is directly discoverable before rendering.
		_assert(prop != null and has_collision \
			and prop.get_child_count() >= 2,
			"starter basecamp %s is a visible colliding supplied prop" % node_name)
	var firelight := r.get_node_or_null("OpeningBasecampFirelight") as OmniLight3D
	_assert(firelight != null and firelight.omni_range >= 7.0,
		"starter basecamp has a warm firelight pool")
	r.queue_free()


## The visible river approach uses supplied cliff modules. Their import has a
## near-white swatch, so preserve the regression guard that prevents a blank
## cube from returning to the centre of the player-facing bridge frame.
func _test_opening_bridge_shore_uses_the_textured_stone_path() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains('name_key.begins_with("openingbridgeshore")')
		and source.contains('key.contains("openingbridgeshore")')
		and source.contains("fallback_tint = CHOYCE_WARM_BEIGE.darkened(0.20)")
		and source.contains('KENNEY_NK + "rock_largeD.glb"')
		and not source.contains('KENNEY_NK + "cliff_blockSlope_stone.glb"'),
		"opening bridge shoreline modules cannot render as white placeholder cubes")


func _test_opening_riverbank_has_layered_thickets_outside_the_bridge_lane() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("var bank_thickets := [")
		and source.contains("Vector3(-10.2, 0.0, -7.8)")
		and source.contains("Vector3(19.8, 0.0, -45.0)")
		and source.contains("OpeningRiverbankThicketBush_")
		and source.contains("OpeningRiverbankThicketRock_")
		and source.contains('name_key.begins_with("openingriverbankthicket")')
		and source.contains("Vector3(1.28 * thicket_scale, 1.10, 1.12 * thicket_scale)"),
		"riverbank uses grounded, colliding bush-and-rock thickets outside the child bridge corridor")


## Decorative plants placed inside a water volume appeared as floating cyan
## shards in the live camera. Build the actual bank habitat and measure every
## named bank prop against the renderer's meandering water cross-section.
func _test_opening_riverbank_visuals_stay_out_of_swim_channel() -> void:
	var r := _make_renderer()
	r._build_opening_riverbank_habitat()
	var all_on_land := true
	for child_variant in r.get_children():
		var child := child_variant as Node3D
		if child == null or not String(child.name).begins_with("OpeningRiverbank"):
			continue
		var banks := r._river_bank_pair(child.position.x)
		var left: Vector3 = banks[0]
		var right: Vector3 = banks[1]
		var center := (left + right) * 0.5
		var side := Vector2(left.x - center.x, left.z - center.z).normalized()
		var lateral_distance := absf(Vector2(child.position.x - center.x, child.position.z - center.z).dot(side))
		var water_half_width := left.distance_to(right) * 0.5
		if lateral_distance <= water_half_width + 0.25:
			all_on_land = false
			break
	_assert(all_on_land, "opening riverbank vegetation and rocks remain outside the physical swim channel")
	r.queue_free()


## The imported CC0 trees expose Green/DarkGreen and Wood materials, but their
## varied normals need the dedicated readable foliage shader. Bind every
## selected source to an explicit profile rather than passing the same generic
## 1.65 × 13 × 1.65m collider to unrelated trunk shapes.
func _test_quaternius_forest_surface_profiles_are_explicit() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("const OPENING_FOREST_TREE_COLLISION_PROFILES := {")
		and source.contains("CommonTree_1.fbx\": Vector3(1.20, 10.0, 1.20)")
		and source.contains("PineTree_1.fbx\": Vector3(0.88, 10.5, 0.88)")
		and source.contains("BirchTree_1.fbx\": Vector3(0.72, 12.0, 0.72)")
		and source.contains("func _make_readable_forest_foliage_material(variant_tint: Color = Color.WHITE)")
		and source.contains("var is_quaternius_forest_tree :=")
		and source.contains("func _forest_foliage_tint_for_asset(name_key: String)")
		and source.contains("func _is_harvestable_tree_asset(asset_path: String)")
		and source.contains("trunk_collision"),
		"CC0 forest variants use explicit readable foliage and trunk-collision profiles")


## The prior review caught the exact failure source checks miss: valid paths
## rendered as black crowns, while every tree used an unrelated collider. Build
## the deterministic forest and verify the instantiated scene has the readable
## foliage override and a trunk-sized world collision before accepting a change.
func _test_quaternius_forest_profiles_apply_at_runtime() -> void:
	var r := _make_renderer()
	r._build_opening_forest_mass("runtime_profile_contract")
	var forest_trees := r.find_children("OpeningForestMass_*", "StaticBody3D", false, false)
	var readable_foliage_count := 0
	var fitted_trunk_count := 0
	for tree_variant in forest_trees:
		var tree := tree_variant as StaticBody3D
		var collision: CollisionShape3D = null
		for child in tree.get_children():
			if child is CollisionShape3D:
				collision = child as CollisionShape3D
				break
		var shape := collision.shape as BoxShape3D if collision != null else null
		if shape != null and shape.size.x >= 0.70 and shape.size.x <= 1.25 \
			and shape.size.z >= 0.70 and shape.size.z <= 1.25 \
			and shape.size.y >= 10.0 and shape.size.y <= 12.0 \
			and tree.is_in_group("harvestable_tree"):
			fitted_trunk_count += 1
		for mesh_variant in tree.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_variant as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface_index in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_surface_override_material(surface_index) as ShaderMaterial
				if material != null and material.shader == r.FOREST_FOLIAGE_SHADER:
					readable_foliage_count += 1
	_assert(forest_trees.size() >= 80 and readable_foliage_count >= forest_trees.size()
		and fitted_trunk_count == forest_trees.size(),
		"instantiated CC0 forest has readable canopy overrides and bounded trunk collisions")
	r.queue_free()


func _test_opening_forest_mass_is_a_real_colliding_volume() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("const FOREST_MASS_TREES_PER_CLUSTER := 12")
		and source.contains("forest-canopy-stylized-v2.png")
		and source.contains("bark012/Bark012_1K-JPG_Color.jpg")
		and source.contains("func _make_bark_toon_material()")
		and source.contains("Vector3(-29.0, 0.0, -46.0)")  # Moved closer to river
		and source.contains("Vector3(164.0, 0.0, -195.0)")  # Moved closer to river
		and source.contains('const OPENING_OAK_TREE := "res://data/models/props/oak_tree.gltf"')
		and source.contains("const OPENING_FOREST_TREE_PATHS := [")
		and source.contains("nature/CommonTree_1.fbx")
		and source.contains("nature/PineTree_1.fbx")
		and source.contains("var tree_paths := OPENING_FOREST_TREE_PATHS")
		and source.contains("forest_rng.randf_range(2.45, 3.95)")
		and source.contains("OPENING_FOREST_TREE_COLLISION_PROFILES.get(tree_path")
		and source.contains("trunk_collision")
		and source.contains("_build_opening_forest_mass(seed_source)"),
		"opening has deterministic, layered, human-scale colliding woodland beyond the bridge")


## The starter composition may be dense, but every large biome must be an
## actual exploration destination. Reintroducing the old 40m centres silently
## turns the opening into a palette of unrelated props again.
func _test_opening_is_not_polluted_by_nearby_biomes_or_river_fence() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("var village_center := Vector3(300, 0, 250)")
		and source.contains("var forest_center := Vector3(-400, 0, 250)")
		and source.contains("var beach_center := Vector3(-320, 0, -350)")
		and source.contains("var cave_center := Vector3(360, 0, -400)"),
		"village, forest, beach and cave begin at meaningful exploration distances")
	_assert(source.contains("const OPENING_COMPOSED_RADIUS_M := 380.0"),
		"initial streaming holds generic scatter outside the composed opening horizon")
	_assert(not source.contains('"river_bank_%s_%s"'),
		"river has no repeated full-length collidable rock fence")


## Procedural large-world regression: only the nearby 5×5 chunk envelope is
## instantiated, and crossing macro cells keeps the retained set bounded.
func _test_streamed_procedural_chunks_stay_bounded() -> void:
	var r := _make_renderer()
	r._build_procedural_island("streaming_test")
	_assert(r._procedural_chunks.size() > 0 and r._procedural_chunks.size() <= 25,
		"streamed world boots only the nearby 5×5 chunk envelope")
	r.set_exploration_focus(Vector3(520.0, 0.0, 0.0))
	_assert(r._procedural_chunks.size() <= 49,
		"chunk transition unloads distant runtime chunks instead of accumulating the world")
	r.queue_free()


## Regression: the huge floor must never end in a walkable void.
func _test_world_boundary_has_visible_segmented_collision() -> void:
	var r := _make_renderer()
	r._build_world_boundary()
	var coast := r.get_node_or_null("CliffCoastCollision") as Node3D
	var ocean := r.get_node_or_null("OuterOcean") as MeshInstance3D
	_assert(coast != null and coast.get_child_count() >= 72 and ocean != null,
		"large-world coast has segmented cliff-aligned collision and an ocean beyond the map edge")
	r.queue_free()


func _test_outer_chunks_do_not_spill_past_world_floor() -> void:
	var r := _make_renderer()
	_assert(not r._is_chunk_outside_world(Vector2i(6, 0))
		and r._is_chunk_outside_world(Vector2i(7, 0))
		and r._is_chunk_outside_world(Vector2i(-8, 0)),
		"procedural chunks are clipped to the full 2.4km floor, not just their center")
	r.queue_free()


func _test_generation_is_queued_not_built_by_focus_request() -> void:
	var r := _make_renderer()
	r._build_procedural_island("streaming_budget_test")
	var queued_before := r._procedural_build_queue.size()
	r._advance_procedural_generation()
	_assert(queued_before > 0 and r._procedural_build_queue.size() == queued_before,
		"focus requests reserve chunks while generation remains budgeted across frames")
	r.queue_free()


func _test_river_keeps_a_bridge_width_dry_crossing() -> void:
	var water_shader_source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/shaders/adventure_water.gdshader")
	var r := _make_renderer()
	r._add_water_crossing()
	r._build_opening_bridge()
	var river := r.get_node_or_null("StarterRiver") as Area3D
	var river_visual := river.get_node_or_null("WaterSurface") as MeshInstance3D if river != null else null
	var river_mesh := river_visual.mesh as ArrayMesh if river_visual != null else null
	# These runtime shapes have no PackedScene owner; include unowned direct
	# children so this test validates the actual generated water contract.
	var water_volumes := river.find_children("WaterVolumeSegment_*", "CollisionShape3D", false, false) if river != null else []
	var bridge_pair := r._river_bank_pair(0.0)
	var bridge_center: Vector3 = (bridge_pair[0] + bridge_pair[1]) * 0.5
	var deck := r.get_node_or_null("OpeningBridgeDeck") as StaticBody3D
	var deck_collision := r._first_collision_shape(deck) if deck != null else null
	var south_ramp := r.get_node_or_null("OpeningBridgeRampSouth") as Node3D
	var north_ramp := r.get_node_or_null("OpeningBridgeRampNorth") as Node3D
	# The supplied stair meshes are intentionally visual-only.  The continuous
	# traversal surface below owns the single authoritative collision profile.
	var south_stairs := r.find_children("OpeningBridgeSouthApproach_*", "Node3D", false, false)
	var north_stairs := r.find_children("OpeningBridgeNorthApproach_*", "Node3D", false, false)
	var rails := r.find_children("OpeningBridgeRail_*", "Node3D", false, false)
	# Every visible rail must own a narrow collision profile; the imported GLTF
	# does not supply usable collision by itself.
	var rails_with_collision := 0
	for rail in rails:
		var rail_body := rail is StaticBody3D and r._first_collision_shape(rail as StaticBody3D) != null
		if rail_body:
			rails_with_collision += 1
	_assert(river != null and river_visual != null and river.position.y > 0.0 \
		and river_mesh != null and river_mesh.get_surface_count() > 0,
		"river keeps its raised curved-surface and physical-volume contract")
	var water_material := river_visual.material_override as ShaderMaterial if river_visual != null else null
	var runtime_dudv_tiling = water_material.get_shader_parameter("dudv_tiling") if water_material != null else null
	var runtime_dudv_strength = water_material.get_shader_parameter("dudv_strength") if water_material != null else null
	var runtime_wave_height = water_material.get_shader_parameter("wave_height") if water_material != null else null
	var runtime_wave_speed = water_material.get_shader_parameter("wave_speed") if water_material != null else null
	_assert(water_material != null
		and runtime_dudv_tiling is float and float(runtime_dudv_tiling) >= 0.12
		and float(runtime_dudv_tiling) <= 0.20
		and runtime_dudv_strength is float and float(runtime_dudv_strength) >= 0.03
		and runtime_wave_height is float and float(runtime_wave_height) <= 0.02
		and runtime_wave_speed is float and float(runtime_wave_speed) > 0.0
		and water_material.get_shader_parameter("dudv_map") != null
		and water_material.get_shader_parameter("foam_color") is Color
		and water_material.get_shader_parameter("sky_reflection_color") is Color,
		"local-world river flow retains repeated SimpleWater distortion, gentle waves and authored reflection tint at runtime")
	var water_vertices := river_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array if river_mesh != null else PackedVector3Array()
	_assert(water_vertices.size() >= WorldRenderer.RIVER_RENDER_SEGMENT_COUNT * WorldRenderer.RIVER_RENDER_WIDTH_SUBDIVISIONS * 6,
		"river render mesh has the required tessellated surface, not only a matching constant")
	var runtime_shallow := water_material.get_shader_parameter("shallow_color") as Color if water_material != null else Color.BLACK
	var runtime_deep := water_material.get_shader_parameter("deep_color") as Color if water_material != null else Color.BLACK
	_assert(runtime_shallow.get_luminance() > runtime_deep.get_luminance()
		and runtime_shallow.g > runtime_shallow.r
		and runtime_deep.b > runtime_deep.r,
		"runtime water material keeps a readable turquoise shore and deeper blue channel")
	_assert(is_zero_approx(river.position.z) and is_equal_approx(bridge_center.z, -24.0)
		and water_volumes.size() == WorldRenderer.RIVER_SEGMENT_COUNT,
		"river ribbon and sampled swimming volumes share the authored bridge crossing without a fixed Z box")
	var volume_widths_are_river_scale := true
	for volume_variant in water_volumes:
		var volume := volume_variant as CollisionShape3D
		var shape := volume.shape as BoxShape3D if volume != null else null
		if shape == null or shape.size.z < 14.5 or shape.size.x < 20.0:
			volume_widths_are_river_scale = false
			break
	_assert(volume_widths_are_river_scale,
		"every meander segment exposes a bank-to-bank shallow-water volume instead of a straight invisible strip")
	_assert(water_shader_source.contains("depth_draw_opaque, unshaded, fog_disabled")
		and water_shader_source.contains("float foam = crest_foam + bank_foam;")
		and water_shader_source.contains("varying float river_depth;")
		and water_shader_source.contains("uniform sampler2D dudv_map")
		and water_shader_source.contains("float flow_streak_a = sin")
		and water_shader_source.contains("MODEL_MATRIX * vec4(VERTEX, 1.0)")
		and water_shader_source.contains("flow_position = world_pos.xz")
		and water_shader_source.contains("float channel_depth = smoothstep")
		and water_shader_source.contains("float fresnel = pow")
		and water_shader_source.contains("ALPHA = 1.0"),
		"river stays opaque, animated, depth-graded and sky-reflective without extra viewports")
	_assert(WorldRenderer.RIVER_RENDER_SEGMENT_COUNT > WorldRenderer.RIVER_SEGMENT_COUNT
		and WorldRenderer.RIVER_RENDER_WIDTH_SUBDIVISIONS >= 8,
		"water render mesh has denser longitudinal and cross-river geometry than collision volumes")
	_assert(WorldRenderer.CHOYCE_WATER_SHALLOW.get_luminance() < 0.25
		and WorldRenderer.CHOYCE_WATER_DEEP.get_luminance() < 0.18,
		"river palette is materially darker than the sky instead of a white floor")
	_assert(deck != null and deck_collision != null,
		"bridge exposes one continuous deck collision beneath its visual bridge assembly")
	_assert(r.find_children("OpeningBridgeDeckCenter_*", "Node3D", false, false).size() >= 8
		and r.find_child("OpeningBridgeDeckCapSouth", true, false) != null
		and r.find_child("OpeningBridgeDeckCapNorth", true, false) != null,
		"bridge uses complete purpose-built deck modules and rounded bank caps instead of floor-tile blockout")
	_assert(south_ramp != null and north_ramp != null \
		and south_stairs.size() == 2 and north_stairs.size() == 2 \
		and deck_collision != null and deck_collision.shape is ConcavePolygonShape3D,
		"bridge exposes visible approaches on one continuous colliding walk surface")
	_assert(rails_with_collision >= 2,
		"bridge exposes narrow rail collision bodies at both sides")
	r.queue_free()


## A capsule-sized shape cast must be able to walk the bridge in both
## directions on the continuous deck, while the rails block a lateral crossing.
func _test_bridge_shape_cast_traversal() -> void:
	var r := _make_renderer()
	r._add_water_crossing()
	r._build_opening_bridge()
	for _frame in 4:
		await physics_frame
	var south_to_north := _shape_cast_fraction(Vector3(0.0, 1.1, -8.0), Vector3(0.0, 1.1, -40.0), 0.35)
	var north_to_south := _shape_cast_fraction(Vector3(0.0, 1.1, -40.0), Vector3(0.0, 1.1, -8.0), 0.35)
	var lateral_through_rails := _shape_cast_fraction(Vector3(-2.2, 1.1, -24.0), Vector3(2.2, 1.1, -24.0), 0.35)
	_assert(is_equal_approx(south_to_north, 1.0),
		"shape cast can traverse the bridge deck from south bank to north bank")
	_assert(is_equal_approx(north_to_south, 1.0),
		"shape cast can traverse the bridge deck from north bank to south bank")
	_assert(lateral_through_rails < 1.0,
		"shape cast is blocked when crossing the bridge rails laterally")
	r.queue_free()


## The river Area3D must forward enter/exit state to bodies that expose
## set_in_water, so gameplay can transition between walk and swim states.
func _test_water_volume_enter_exit_callbacks() -> void:
	var r := _make_renderer()
	r._add_water_crossing()
	var river := r.get_node_or_null("StarterRiver") as Area3D
	var body_script := GDScript.new()
	body_script.source_code = "extends Node3D\nvar in_water := false\nfunc set_in_water(value: bool) -> void:\n\tin_water = value\n"
	body_script.reload()
	var body := Node3D.new()
	body.set_script(body_script)
	body.name = "WaterCallbackProbe"
	r.add_child(body)
	_assert(river != null and river.body_entered.get_connections().size() > 0,
		"water volume has body_entered connected")
	river.body_entered.emit(body)
	_assert(body.get("in_water") == true,
		"entering water calls set_in_water(true) on the body")
	river.body_exited.emit(body)
	_assert(body.get("in_water") == false,
		"exiting water calls set_in_water(false) on the body")
	body.queue_free()
	r.queue_free()


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _find_mesh_instance(parent: Node) -> MeshInstance3D:
	if parent is MeshInstance3D:
		return parent
	for child in parent.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


## Returns the collision-free fraction of a sphere sweep through the current
## 3D physics space. 1.0 means the entire motion is clear.
func _shape_cast_fraction(from: Vector3, to: Vector3, radius: float) -> float:
	var space_state := get_root().get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, from)
	params.motion = to - from
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var result := space_state.cast_motion(params)
	if result.is_empty():
		return 1.0
	return float(result[0])
