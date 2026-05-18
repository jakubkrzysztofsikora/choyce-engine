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
	_test_terrain_node_uses_shader_material()
	_test_decoration_node_uses_shader_material()
	_test_apply_toon_to_prop_walks_all_mesh_instances()
	_test_apply_toon_to_prop_preserves_standard_material_albedo()
	_test_apply_toon_to_prop_defaults_to_white_when_no_standard_mat()

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


## 7. _create_decoration_node: MeshInstance3D gets ShaderMaterial.
func _test_decoration_node_uses_shader_material() -> void:
	var r := _make_renderer()
	var n := _make_scene_node(SceneNode.NodeType.DECORATION, {})
	var result: Node3D = r._create_decoration_node(n)
	_assert(
		result is MeshInstance3D and result.material_override is ShaderMaterial,
		"_create_decoration_node: MeshInstance3D.material_override is ShaderMaterial"
	)
	result.queue_free()
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
