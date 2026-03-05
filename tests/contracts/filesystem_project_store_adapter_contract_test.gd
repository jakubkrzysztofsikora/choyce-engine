class_name FilesystemProjectStoreAdapterContractTest
extends PortContractTest

const TEST_ROOT := "user://contract_tests/task005_project_store"


func run() -> Dictionary:
	_reset()
	_cleanup_user_path(TEST_ROOT)

	var store := FilesystemProjectStore.new(TEST_ROOT)
	_assert_has_method(store, "save_project")
	_assert_has_method(store, "load_project")
	_assert_has_method(store, "list_projects")

	var project := _build_project()
	_assert_true(
		store.save_project(project),
		"FilesystemProjectStore.save_project(project) should return true"
	)

	var manifest_path := "%s/%s/manifest.json" % [TEST_ROOT, project.project_id]
	_assert_true(
		FileAccess.file_exists(manifest_path),
		"Manifest file should be created after save"
	)

	var manifest = _read_json(manifest_path)
	_assert_true(manifest is Dictionary, "Manifest should parse as Dictionary")
	if manifest is Dictionary:
		_assert_true(
			str(manifest.get("project_id", "")) == project.project_id,
			"Manifest should contain saved project_id"
		)
		_assert_true(manifest.has("world_ids"), "Manifest should include world_ids")
		_assert_true(
			manifest.has("asset_references"),
			"Manifest should include asset_references"
		)
		_assert_true(
			manifest.has("ai_provenance"),
			"Manifest should include ai_provenance metadata summary"
		)
		var provenance_rows: Variant = manifest.get("ai_provenance", [])
		_assert_true(
			provenance_rows is Array and (provenance_rows as Array).size() >= 1,
			"Manifest ai_provenance should contain at least one AI-tagged entry"
		)

	var loaded := store.load_project(project.project_id)
	_assert_project(loaded, "FilesystemProjectStore.load_project(project_id)")
	if loaded != null:
		_assert_true(loaded.title == "Projekt testowy", "Loaded project should preserve title")
		_assert_true(loaded.worlds.size() == 1, "Loaded project should include world data")
		var loaded_world := loaded.get_world("world_fs_1")
		_assert_true(loaded_world != null, "Loaded world should be retrievable by id")
		if loaded_world != null:
			_assert_true(
				loaded_world.scene_nodes.size() == 1,
				"Loaded world should preserve scene nodes"
			)
			_assert_true(
				loaded_world.game_rules.size() == 1,
				"Loaded world should preserve rules"
			)

	var listed := store.list_projects()
	_assert_array(listed, "FilesystemProjectStore.list_projects()")
	_assert_true(listed.size() >= 1, "list_projects() should include saved project")

	var missing := store.load_project("missing_project")
	_assert_null(missing, "FilesystemProjectStore.load_project(missing_project)")

	_cleanup_user_path(TEST_ROOT)
	return _build_result("FilesystemProjectStoreAdapter")


func _build_project() -> Project:
	var project := Project.new("project_fs_1", "Projekt testowy")
	project.description = "Projekt z adaptera FS"
	project.template_id = "farm"
	project.owner_profile_id = "parent-1"
	project.created_at = "2026-03-02T11:00:00Z"
	project.updated_at = "2026-03-02T11:00:00Z"

	var world := World.new("world_fs_1", "Swiat testowy")
	world.theme = "farm"
	world.is_playable = true

	var node := SceneNode.new("node_1", SceneNode.NodeType.OBJECT)
	node.display_name = "Drzewo"
	node.position = Vector3(1, 2, 3)
	node.properties = {"asset_id": "project_fs_1/tree.bin"}
	node.provenance = ProvenanceData.new(
		ProvenanceData.SourceType.AI_VISUAL,
		"qwen2.5:7b-instruct",
		"audit-manifest-1"
	)
	world.add_node(node)

	var rule := GameRule.new("rule_1", GameRule.RuleType.TIMER)
	rule.display_name = "Zarabianie"
	rule.source_blocks = [{"type": "TIMER", "interval": 10}]
	rule.compiled_logic = "coins += 1 every 10s"
	world.add_rule(rule)

	project.add_world(world)
	return project


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _cleanup_user_path(path: String) -> void:
	_remove_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _remove_dir_recursive_absolute(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue

		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_remove_dir_recursive_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()

	DirAccess.remove_absolute(path)
