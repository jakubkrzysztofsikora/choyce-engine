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
	_test_opening_forest_mass_is_a_real_colliding_volume()
	_test_opening_is_not_polluted_by_nearby_biomes_or_river_fence()
	_test_streamed_procedural_chunks_stay_bounded()
	_test_world_boundary_has_visible_segmented_collision()
	_test_outer_chunks_do_not_spill_past_world_floor()
	_test_generation_is_queued_not_built_by_focus_request()
	_test_river_keeps_a_bridge_width_dry_crossing()

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
		and source.contains("float(entry[1]) * 0.56")
		and source.contains("backdrop_rng.randf_range(1.20, 1.90)"),
		"opening forest uses adult-scale tree silhouettes rather than miniature props")


## The curated spawn is a clearing framed by a layered grove, not a lawn with
## a handful of evenly spaced tabletop trees.  Keep the centre and bridge lane
## intentionally open, but require substantial close and middle-distance tree
## silhouettes on both sides.
func _test_opening_grove_has_a_dense_human_scale_frame() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("Vector3(-20.5, 0, -5.5), 2.30")
		and source.contains("Vector3(27.5, 0, -10.2), 2.48")
		and source.contains("Vector3(-60, 0, -64), 3.25")
		and source.contains("Vector3(58, 0, -68), 3.18"),
		"opening uses a layered, human-scale tree frame rather than sparse prototype scatter")


func _test_opening_forest_mass_is_a_real_colliding_volume() -> void:
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/world_renderer.gd")
	_assert(source.contains("const FOREST_MASS_CLUSTER_COUNT := 8")
		and source.contains("const FOREST_MASS_TREES_PER_CLUSTER := 12")
		and source.contains("Vector3(-46.0, 0.0, -90.0)")
		and source.contains("Vector3(166.0, 0.0, -200.0)")
		and source.contains('const OPENING_OAK_TREE := "res://data/models/props/oak_tree.gltf"')
		and source.contains('var tree_paths := [OPENING_OAK_TREE]')
		and source.contains("forest_rng.randf_range(1.45, 2.35)")
		and source.contains("Vector3(1.65, 13.0, 1.65)")
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
	var river_collision := river.get_node_or_null("WaterVolumeShape") as CollisionShape3D if river != null else null
	var river_mesh := river_visual.mesh as ArrayMesh if river_visual != null else null
	var deck := r.get_node_or_null("OpeningBridgeDeck") as StaticBody3D
	var deck_collision := r._first_collision_shape(deck) if deck != null else null
	var south_ramp := r.get_node_or_null("OpeningBridgeRampSouth") as StaticBody3D
	var north_ramp := r.get_node_or_null("OpeningBridgeRampNorth") as StaticBody3D
	var left_rail := r.get_node_or_null("OpeningBridgeRail_L") as StaticBody3D
	var right_rail := r.get_node_or_null("OpeningBridgeRail_R") as StaticBody3D
	_assert(river != null and river_visual != null and river.position.y > 0.0 \
		and river_collision != null and river_mesh != null and river_mesh.get_surface_count() > 0,
		"river keeps its raised curved-surface and physical-volume contract")
	_assert(is_zero_approx(river.position.z) and is_equal_approx(river_collision.position.z, -24.0),
		"river ribbon and swimming volume share the authored bridge crossing instead of applying the Z offset twice")
	_assert(water_shader_source.contains("depth_draw_opaque, unshaded, fog_disabled")
		and water_shader_source.contains("float foam = crest_foam + bank_foam;")
		and water_shader_source.contains("varying float river_depth;")
		and water_shader_source.contains("uniform sampler2D dudv_map")
		and water_shader_source.contains("float channel_depth = smoothstep")
		and water_shader_source.contains("float fresnel = pow")
		and water_shader_source.contains("ALPHA = 1.0"),
		"river stays opaque, animated, depth-graded and sky-reflective without extra viewports")
	_assert(WorldRenderer.CHOYCE_WATER_SHALLOW.get_luminance() < 0.25
		and WorldRenderer.CHOYCE_WATER_DEEP.get_luminance() < 0.18,
		"river palette is materially darker than the sky instead of a white floor")
	_assert(deck != null and deck_collision != null,
		"bridge exposes one continuous deck collision beneath its visual tile assembly")
	_assert(south_ramp != null and north_ramp != null,
		"bridge exposes explicit collision approaches at both banks")
	_assert(left_rail != null and right_rail != null,
		"bridge exposes narrow rail collision bodies at both sides")
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
