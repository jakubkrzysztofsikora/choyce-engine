class_name WorldRenderer
extends Node3D

var _spawn_points: Array[Vector3] = []

func render_world(world: World) -> void:
	clear_world()
	_spawn_points.clear()
	for node_variant in world.scene_nodes:
		if not (node_variant is SceneNode):
			continue
		var node: SceneNode = node_variant
		_create_node(node)
		for child in node.children:
			if child is SceneNode:
				_create_node(child)

func clear_world() -> void:
	for child in get_children():
		child.queue_free()
	_spawn_points.clear()

func get_spawn_position(index: int = 0) -> Vector3:
	if _spawn_points.is_empty():
		return Vector3(0, 2, 0)
	if index < 0 or index >= _spawn_points.size():
		return _spawn_points[0]
	return _spawn_points[index]

func _create_node(node: SceneNode) -> void:
	var godot_node: Node3D = null

	match node.node_type:
		SceneNode.NodeType.OBJECT:
			godot_node = _create_object_node(node)
		SceneNode.NodeType.TERRAIN:
			godot_node = _create_terrain_node(node)
		SceneNode.NodeType.LIGHT:
			godot_node = _create_light_node(node)
		SceneNode.NodeType.SPAWN_POINT:
			godot_node = _create_spawn_point_node(node)
		SceneNode.NodeType.TRIGGER:
			godot_node = _create_trigger_node(node)
		SceneNode.NodeType.DECORATION:
			godot_node = _create_decoration_node(node)

	if godot_node != null:
		add_child(godot_node)
		godot_node.position = node.position
		godot_node.rotation = node.rotation
		godot_node.scale = node.scale

func _create_object_node(node: SceneNode) -> Node3D:
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	var mesh := _resolve_mesh(node.properties)
	mesh_instance.mesh = mesh

	var color_hint: Color = node.properties.get("color", Color.WHITE)
	mesh_instance.material_override = PlaceholderMaterials.get_material_for_node_type(SceneNode.NodeType.OBJECT, color_hint)

	var size: Variant = node.properties.get("size", Vector3.ONE)
	if size is Vector3:
		mesh_instance.scale = size

	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	collision.shape = shape

	static_body.add_child(mesh_instance)
	static_body.add_child(collision)
	return static_body

func _create_terrain_node(node: SceneNode) -> Node3D:
	var static_body := StaticBody3D.new()
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	var mesh := BoxMesh.new()
	mesh.size = Vector3(50, 0.5, 50)
	mesh_instance.mesh = mesh

	var color_hint: Color = node.properties.get("color", Color.WHITE)
	var mat := PlaceholderMaterials.get_material_for_node_type(SceneNode.NodeType.TERRAIN, color_hint)
	if mat is StandardMaterial3D:
		mat.roughness = 0.85
		mat.metallic = 0.1
	mesh_instance.material_override = mat

	var shape := BoxShape3D.new()
	shape.size = Vector3(50, 0.5, 50)
	collision.shape = shape

	static_body.add_child(mesh_instance)
	static_body.add_child(collision)
	return static_body

func _create_light_node(node: SceneNode) -> Node3D:
	var light_type: String = node.properties.get("light_type", "omni")
	if light_type == "directional":
		var light := DirectionalLight3D.new()
		light.shadow_enabled = true
		light.shadow_blur = 1.5
		return light
	else:
		var light := OmniLight3D.new()
		light.omni_range = node.properties.get("range", 10.0)
		light.light_energy = node.properties.get("energy", 1.0)
		light.light_color = Color(1.0, 0.95, 0.85)
		return light

func _create_spawn_point_node(node: SceneNode) -> Node3D:
	_spawn_points.append(node.position)
	var marker := Marker3D.new()
	marker.name = "SpawnPoint"
	
	# Add glow effect
	var glow := OmniLight3D.new()
	glow.name = "SpawnGlow"
	glow.omni_range = 3.0
	glow.light_energy = 0.8
	glow.light_color = Color(0.4, 0.8, 1.0)
	marker.add_child(glow)
	
	var particles := GPUParticles3D.new()
	particles.name = "SpawnParticles"
	particles.amount = 16
	particles.lifetime = 1.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	pm.color = Color(0.4, 0.8, 1.0, 0.6)
	particles.process_material = pm
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.04
	p_mesh.height = 0.08
	particles.draw_pass_1 = p_mesh
	marker.add_child(particles)
	
	return marker

func _create_trigger_node(node: SceneNode) -> Node3D:
	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	collision.shape = shape
	area.add_child(collision)
	
	# Add glow effect for collectible feel
	var glow := OmniLight3D.new()
	glow.name = "TriggerGlow"
	glow.omni_range = 2.5
	glow.light_energy = 0.6
	glow.light_color = Color(1.0, 0.85, 0.3)
	area.add_child(glow)
	
	var particles := GPUParticles3D.new()
	particles.name = "TriggerParticles"
	particles.amount = 12
	particles.lifetime = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.2
	pm.scale_max = 0.6
	pm.color = Color(1.0, 0.9, 0.4, 0.5)
	particles.process_material = pm
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.03
	p_mesh.height = 0.06
	particles.draw_pass_1 = p_mesh
	area.add_child(particles)
	
	return area

func _create_decoration_node(node: SceneNode) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := _resolve_mesh(node.properties)
	mesh_instance.mesh = mesh

	var color_hint: Color = node.properties.get("color", Color.WHITE)
	mesh_instance.material_override = PlaceholderMaterials.get_material_for_node_type(SceneNode.NodeType.DECORATION, color_hint)

	var size: Variant = node.properties.get("size", Vector3.ONE)
	if size is Vector3:
		mesh_instance.scale = size

	return mesh_instance

func _resolve_mesh(properties: Dictionary) -> PrimitiveMesh:
	var mesh_type: String = properties.get("mesh_type", "box")
	match mesh_type:
		"sphere":
			return SphereMesh.new()
		"cylinder":
			return CylinderMesh.new()
		"box", _:
			return BoxMesh.new()
