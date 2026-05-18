class_name PlaceholderMaterials
extends RefCounted

static var _cache: Dictionary = {}

static func get_material_for_node_type(node_type: SceneNode.NodeType, color_hint: Color = Color.WHITE) -> StandardMaterial3D:
	var cache_key := "%d_%s" % [node_type, color_hint.to_html()]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var mat := StandardMaterial3D.new()
	match node_type:
		SceneNode.NodeType.OBJECT:
			mat.albedo_color = Color(0.6, 0.6, 0.6) * color_hint
			mat.roughness = 0.7
		SceneNode.NodeType.TERRAIN:
			mat.albedo_color = Color(0.25, 0.7, 0.25) * color_hint
			mat.roughness = 0.9
		SceneNode.NodeType.LIGHT:
			mat.albedo_color = Color(1.0, 0.95, 0.6) * color_hint
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.9, 0.4)
			mat.emission_energy_multiplier = 0.5
			mat.roughness = 0.3
		SceneNode.NodeType.SPAWN_POINT:
			mat.albedo_color = Color(0.2, 0.5, 1.0) * color_hint
			mat.roughness = 0.4
		SceneNode.NodeType.TRIGGER:
			mat.albedo_color = Color(1.0, 0.25, 0.25) * color_hint
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.4
			mat.roughness = 0.2
		SceneNode.NodeType.DECORATION:
			mat.albedo_color = Color(0.85, 0.55, 0.75) * color_hint
			mat.roughness = 0.5
		_:
			mat.albedo_color = color_hint
			mat.roughness = 0.5

	_cache[cache_key] = mat
	return mat
