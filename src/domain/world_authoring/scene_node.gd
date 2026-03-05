## Entity representing a single element in a world's scene graph.
## SceneNodes form a tree hierarchy. Each node has a type, spatial
## position, and arbitrary properties. Framework-agnostic: uses
## Vector3 as a basic math type, not a Godot Node dependency.
class_name SceneNode
extends RefCounted

enum NodeType {
	OBJECT,
	TERRAIN,
	LIGHT,
	SPAWN_POINT,
	TRIGGER,
	DECORATION,
}

var node_id: String
var node_type: NodeType
var display_name: String
var position: Vector3
var rotation: Vector3
var scale: Vector3
var properties: Dictionary
var children: Array  # of SceneNode
var parent_id: String
var provenance: ProvenanceData = null


func _init(p_id: String = "", p_type: NodeType = NodeType.OBJECT) -> void:
	node_id = p_id
	node_type = p_type
	display_name = ""
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	properties = {}
	children = []
	parent_id = ""


func add_child_node(child: SceneNode) -> void:
	child.parent_id = node_id
	children.append(child)


func is_interactive() -> bool:
	return node_type in [NodeType.TRIGGER, NodeType.SPAWN_POINT]
