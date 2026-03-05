## Application service for cloning worlds within a project.
## Creates a deep copy of world structure (nodes, rules) for remix workflows.
## Cloned world preserves authoring history but resets progression state.
class_name CloneWorldService
extends RefCounted


## Deep-copy a world and add it to the project with new world_id and optional name.
## Preserves all scene nodes and game rules, generates new IDs for the clone.
func clone_world(source_world: World, project: Project, new_world_name: String = "") -> World:
	if source_world == null or project == null:
		return null

	var cloned_world = World.new(
		_generate_world_id(),
		new_world_name if new_world_name != "" else source_world.name + " (Clone)"
	)
	cloned_world.theme = source_world.theme
	cloned_world.is_playable = source_world.is_playable

	# Deep-copy scene nodes (preserve hierarchy)
	var node_id_map = {}  # old_id -> new_id
	_clone_scene_nodes(source_world.scene_nodes, cloned_world, node_id_map)

	# Deep-copy game rules
	for rule in source_world.game_rules:
		var cloned_rule = _clone_game_rule(rule)
		cloned_world.add_rule(cloned_rule)

	project.add_world(cloned_world)
	return cloned_world


## Private: Recursively clone scene nodes preserving parent-child relationships.
func _clone_scene_nodes(source_nodes: Array, target_world: World, id_map: Dictionary) -> void:
	for source_node in source_nodes:
		var cloned_node = _clone_scene_node(source_node)
		id_map[source_node.node_id] = cloned_node.node_id
		target_world.add_node(cloned_node)

		# Recursively clone children
		if source_node.children.size() > 0:
			_clone_scene_nodes_with_parent(source_node.children, cloned_node, id_map)


## Private: Clone child nodes and maintain parent relationship.
func _clone_scene_nodes_with_parent(source_children: Array, cloned_parent: SceneNode, id_map: Dictionary) -> void:
	for source_child in source_children:
		var cloned_child = _clone_scene_node(source_child)
		id_map[source_child.node_id] = cloned_child.node_id
		cloned_parent.add_child_node(cloned_child)

		if source_child.children.size() > 0:
			_clone_scene_nodes_with_parent(source_child.children, cloned_child, id_map)


## Private: Create a deep copy of a single scene node (without children).
func _clone_scene_node(source_node: SceneNode) -> SceneNode:
	var cloned = SceneNode.new(
		_generate_node_id(),
		source_node.node_type
	)
	cloned.display_name = source_node.display_name
	cloned.position = Vector3(source_node.position.x, source_node.position.y, source_node.position.z)
	cloned.rotation = Vector3(source_node.rotation.x, source_node.rotation.y, source_node.rotation.z)
	cloned.scale = Vector3(source_node.scale.x, source_node.scale.y, source_node.scale.z)
	cloned.properties = source_node.properties.duplicate(true)
	return cloned


## Private: Create a deep copy of a game rule.
func _clone_game_rule(source_rule: GameRule) -> GameRule:
	var cloned = GameRule.new(
		_generate_rule_id(),
		source_rule.rule_type
	)
	cloned.display_name = source_rule.display_name
	cloned.source_blocks = source_rule.source_blocks.duplicate(true)
	cloned.compiled_logic = source_rule.compiled_logic
	cloned.is_active = source_rule.is_active
	return cloned


## Private: Generate unique world ID.
func _generate_world_id() -> String:
	return "world_%s_%d" % [Time.get_ticks_msec(), randi()]


## Private: Generate unique node ID.
func _generate_node_id() -> String:
	return "node_%s_%d" % [Time.get_ticks_msec(), randi()]


## Private: Generate unique rule ID.
func _generate_rule_id() -> String:
	return "rule_%s_%d" % [Time.get_ticks_msec(), randi()]
