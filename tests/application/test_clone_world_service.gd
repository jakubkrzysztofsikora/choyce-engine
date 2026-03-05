## Application test: CloneWorldService
## Validates world cloning preserves structure and generates unique IDs.
class_name TestCloneWorldService
extends ApplicationTest


var _service: CloneWorldService


func _init() -> void:
	_service = CloneWorldService.new()


func run() -> Dictionary:
	test_clone_world_basic()
	test_clone_world_preserves_nodes()
	test_clone_world_preserves_rules()
	test_clone_world_with_hierarchy()
	return _build_result("CloneWorldService")


func test_clone_world_basic() -> void:
	var project = Project.new("proj-1", "Test Project")
	var source_world = World.new("world-1", "Original World")
	project.add_world(source_world)

	var cloned = _service.clone_world(source_world, project, "Cloned World")

	_assert_not_null(cloned, "Cloned world should not be null")
	_assert_ne(cloned.world_id, source_world.world_id, "Cloned world should have unique ID")
	_assert_eq(cloned.name, "Cloned World", "Cloned world should use provided name")
	_assert_eq(project.worlds.size(), 2, "Project should contain original and cloned world")


func test_clone_world_preserves_nodes() -> void:
	var project = Project.new("proj-1", "Test Project")
	var source_world = World.new("world-1", "Original")
	var node1 = SceneNode.new("node-1", SceneNode.NodeType.OBJECT)
	node1.display_name = "Cube"
	source_world.add_node(node1)
	project.add_world(source_world)

	var cloned = _service.clone_world(source_world, project)

	_assert_eq(cloned.scene_nodes.size(), 1, "Cloned world should have same number of nodes")
	var cloned_node = cloned.scene_nodes[0]
	_assert_ne(cloned_node.node_id, node1.node_id, "Cloned node should have unique ID")
	_assert_eq(cloned_node.display_name, node1.display_name, "Cloned node should preserve display name")
	_assert_eq(cloned_node.node_type, node1.node_type, "Cloned node should preserve type")


func test_clone_world_preserves_rules() -> void:
	var project = Project.new("proj-1", "Test Project")
	var source_world = World.new("world-1", "Original")
	var rule1 = GameRule.new("rule-1", GameRule.RuleType.SCORING)
	rule1.display_name = "Score on Collect"
	source_world.add_rule(rule1)
	project.add_world(source_world)

	var cloned = _service.clone_world(source_world, project)

	_assert_eq(cloned.game_rules.size(), 1, "Cloned world should have same number of rules")
	var cloned_rule = cloned.game_rules[0]
	_assert_ne(cloned_rule.rule_id, rule1.rule_id, "Cloned rule should have unique ID")
	_assert_eq(cloned_rule.display_name, rule1.display_name, "Cloned rule should preserve display name")
	_assert_eq(cloned_rule.rule_type, rule1.rule_type, "Cloned rule should preserve type")


func test_clone_world_with_hierarchy() -> void:
	var project = Project.new("proj-1", "Test Project")
	var source_world = World.new("world-1", "Original")

	var parent_node = SceneNode.new("node-1", SceneNode.NodeType.OBJECT)
	parent_node.display_name = "Parent"
	var child_node = SceneNode.new("node-2", SceneNode.NodeType.OBJECT)
	child_node.display_name = "Child"

	parent_node.add_child_node(child_node)
	source_world.add_node(parent_node)
	project.add_world(source_world)

	var cloned = _service.clone_world(source_world, project)

	_assert_eq(cloned.scene_nodes.size(), 1, "Cloned world should have parent node at root")
	var cloned_parent = cloned.scene_nodes[0]
	_assert_eq(cloned_parent.children.size(), 1, "Cloned parent should have child")
	var cloned_child = cloned_parent.children[0]
	_assert_eq(cloned_child.display_name, "Child", "Cloned child should preserve display name")
	_assert_eq(cloned_child.parent_id, cloned_parent.node_id, "Cloned child should reference cloned parent")
