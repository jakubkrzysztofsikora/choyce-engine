class_name ApplyWorldEditServiceProvenanceContractTest
extends PortContractTest


class InMemoryProjectStore:
	extends ProjectStorePort

	var _projects: Dictionary = {}

	func save_project(project: Project) -> bool:
		if project == null or project.project_id.strip_edges().is_empty():
			return false
		_projects[project.project_id] = project
		return true

	func load_project(project_id: String) -> Project:
		if not _projects.has(project_id):
			return null
		var value: Variant = _projects.get(project_id, null)
		return value as Project

	func list_projects() -> Array:
		var output: Array = []
		for value in _projects.values():
			if value is Project:
				output.append(value)
		return output


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T18:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767434400000 + _tick


func run() -> Dictionary:
	_reset()

	var store := InMemoryProjectStore.new()
	var project := _build_project()
	_assert_true(store.save_project(project), "In-memory store should save baseline project")

	var service := ApplyWorldEditService.new().setup(store, MockClock.new())
	var actor := PlayerProfile.new("kid-provenance", PlayerProfile.Role.KID)

	var add_ai_node := WorldEditCommand.new()
	add_ai_node.action = WorldEditCommand.Action.ADD_NODE
	add_ai_node.target_node_id = "ai-tree-1"
	add_ai_node.node_data = {
		"type": SceneNode.NodeType.OBJECT,
		"display_name": "AI Tree",
		"position": Vector3.ZERO,
		"ai_generated": true,
		"generator_model": "qwen2.5:7b-instruct",
		"audit_id": "audit-visual-1",
		"content_kind": "visual",
	}
	_assert_true(
		service.execute("world-provenance-1", add_ai_node, actor),
		"ADD_NODE should execute with AI provenance metadata"
	)

	var loaded_after_add := store.load_project("project-provenance-1")
	var world_after_add := loaded_after_add.get_world("world-provenance-1")
	var added_node := world_after_add.find_node("ai-tree-1")
	_assert_true(added_node != null, "Added node should exist in world")
	if added_node != null:
		_assert_true(added_node.provenance != null, "Added AI node should get runtime provenance")
		if added_node.provenance != null:
			_assert_true(
				added_node.provenance.source == ProvenanceData.SourceType.AI_VISUAL,
				"AI visual add-node command should map to AI_VISUAL provenance"
			)
			_assert_true(
				added_node.provenance.audit_id == "audit-visual-1",
				"Add-node provenance should preserve provided audit id"
			)

	var paint_ai := WorldEditCommand.new()
	paint_ai.action = WorldEditCommand.Action.PAINT
	paint_ai.target_node_id = "human-node-1"
	paint_ai.new_state = {
		"paint": "turquoise",
		"ai_generated": true,
		"generator_model": "qwen2.5:7b-instruct",
		"audit_id": "audit-paint-1",
		"content_kind": "text",
	}
	_assert_true(
		service.execute("world-provenance-1", paint_ai, actor),
		"PAINT should execute with AI metadata patch"
	)

	var loaded_after_paint := store.load_project("project-provenance-1")
	var world_after_paint := loaded_after_paint.get_world("world-provenance-1")
	var human_node := world_after_paint.find_node("human-node-1")
	_assert_true(human_node != null, "Human node should remain available after paint")
	if human_node != null:
		_assert_true(
			human_node.provenance != null,
			"AI-assisted paint should stamp provenance on edited node"
		)
		if human_node.provenance != null:
			_assert_true(
				human_node.provenance.source == ProvenanceData.SourceType.HYBRID,
				"AI-assisted edit of human node should become HYBRID provenance"
			)
			_assert_true(
				human_node.provenance.audit_id == "audit-paint-1",
				"Edited node should carry audit id from AI patch metadata"
			)

	return _build_result("ApplyWorldEditServiceProvenance")


func _build_project() -> Project:
	var project := Project.new("project-provenance-1", "Projekt Provenance")
	project.owner_profile_id = "kid-provenance"
	project.created_at = "2026-03-02T18:00:00Z"
	project.updated_at = "2026-03-02T18:00:00Z"

	var world := World.new("world-provenance-1", "Swiat Provenance")
	var human_node := SceneNode.new("human-node-1", SceneNode.NodeType.OBJECT)
	human_node.display_name = "Human Build"
	human_node.provenance = ProvenanceData.new(ProvenanceData.SourceType.HUMAN)
	world.add_node(human_node)

	project.add_world(world)
	return project
