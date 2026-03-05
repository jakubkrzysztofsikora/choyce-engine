## Entity representing a single playable world within a Project.
## Contains a scene graph (SceneNodes) and game rules that define
## the world's behavior. Worlds can be cloned for remix/reset.
class_name World
extends RefCounted

var world_id: String
var name: String
var scene_nodes: Array  # of SceneNode
var game_rules: Array  # of GameRule
var theme: String
var is_playable: bool


func _init(p_id: String = "", p_name: String = "") -> void:
	world_id = p_id
	name = p_name
	scene_nodes = []
	game_rules = []
	theme = ""
	is_playable = false


func add_node(node: SceneNode) -> void:
	scene_nodes.append(node)


func remove_node(node_id: String) -> bool:
	for i in range(scene_nodes.size()):
		if scene_nodes[i].node_id == node_id:
			scene_nodes.remove_at(i)
			return true
	return false


func add_rule(rule: GameRule) -> void:
	game_rules.append(rule)


func get_active_rules() -> Array:
	return game_rules.filter(func(r): return r.is_active)


func find_node(node_id: String) -> SceneNode:
	for node in scene_nodes:
		if node.node_id == node_id:
			return node
		var found = _find_in_children(node, node_id)
		if found != null:
			return found
	return null


func _find_in_children(parent: SceneNode, target_id: String) -> SceneNode:
	for child in parent.children:
		if child.node_id == target_id:
			return child
		var found = _find_in_children(child, target_id)
		if found != null:
			return found
	return null

