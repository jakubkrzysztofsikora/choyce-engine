class_name TemplateLoaderTest
extends ApplicationTest

const TEMPLATE_DIR := "res://data/templates"

var _template_loader: TemplateLoader
var _mock_project_store: MockProjectStore
var _mock_clock: MockClock


func _reset() -> void:
	_checks_run = 0
	_failures = []


func run() -> Dictionary:
	_reset()
	_mock_project_store = MockProjectStore.new()
	_mock_clock = MockClock.new()
	_template_loader = TemplateLoader.new().setup(_mock_project_store, _mock_clock)

	test_load_nonexistent_template()
	test_create_project_from_valid_template()
	test_template_with_missing_fields()

	return _build_result("TemplateLoader")


func test_load_nonexistent_template() -> void:
	var result := _template_loader.load_template("nonexistent")
	_assert_true(result.is_empty(), "Nonexistent template should return empty dictionary")


func test_create_project_from_valid_template() -> void:
	var test_template := {
		"template_id": "test",
		"name_pl": "Test Template",
		"default_world": {
			"name_pl": "Test World",
			"nodes": [
				{"type": "TERRAIN", "display_name_pl": "Ground", "position": [0, 0, 0]},
				{"type": "OBJECT", "display_name_pl": "Shop", "position": [5, 0, 0]},
			],
			"rules": [
				{"type": "TIMER", "display_name_pl": "Earn every 10s", "compiled_logic": "score += 1"},
			],
		},
	}
	_write_template("test", test_template)

	var owner := PlayerProfile.new("test_profile", PlayerProfile.Role.KID)
	var project := _template_loader.create_project_from_template("test", owner)

	_assert_not_null(project, "Project should be created from a valid template")
	if project == null:
		_remove_template("test")
		return

	_assert_eq(project.template_id, "test", "Template ID should match")
	_assert_eq(project.title, "Test Template", "Project title should come from localized template name")
	_assert_eq(project.owner_profile_id, "test_profile", "Owner profile should be assigned")
	_assert_eq(project.created_at, "2026-03-02T00:00:00Z", "Project should use injected clock timestamp")
	_assert_eq(project.worlds.size(), 1, "Project should include one default world")

	if project.worlds.size() > 0 and project.worlds[0] is World:
		var world: World = project.worlds[0]
		_assert_eq(world.name, "Test World", "World name should match template")
		_assert_eq(world.scene_nodes.size(), 2, "World should include template scene nodes")
		_assert_eq(world.game_rules.size(), 1, "World should include template game rules")

	_remove_template("test")


func test_template_with_missing_fields() -> void:
	var minimal_template := {
		"template_id": "minimal",
		"name_pl": "Minimal",
		"default_world": {
			"name_pl": "Minimal World",
		},
	}
	_write_template("minimal", minimal_template)

	var owner := PlayerProfile.new("minimal_owner", PlayerProfile.Role.KID)
	var project := _template_loader.create_project_from_template("minimal", owner)

	_assert_not_null(project, "Minimal template should still produce a project")
	if project != null and project.worlds.size() > 0 and project.worlds[0] is World:
		var world: World = project.worlds[0]
		_assert_eq(world.scene_nodes.size(), 0, "Missing nodes should default to empty array")
		_assert_eq(world.game_rules.size(), 0, "Missing rules should default to empty array")

	_remove_template("minimal")


func _write_template(template_id: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMPLATE_DIR))
	var path := "%s/%s.json" % [TEMPLATE_DIR, template_id]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _remove_template(template_id: String) -> void:
	var path := "%s/%s.json" % [TEMPLATE_DIR, template_id]
	DirAccess.remove_absolute(path)


class MockProjectStore:
	extends ProjectStorePort

	var saved_projects: Array = []

	func save_project(project: Project) -> bool:
		saved_projects.append(project)
		return true

	func load_project(_project_id: String) -> Project:
		return null

	func list_projects() -> Array:
		return saved_projects.duplicate()


class MockClock:
	extends ClockPort

	func now_iso() -> String:
		return "2026-03-02T00:00:00Z"

	func now_msec() -> int:
		return 1767379200000
