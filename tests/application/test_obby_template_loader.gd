class_name ObbyTemplateLoaderTest
extends ApplicationTest

## VS-010: Test that Obby template uses shared authored-runtime contracts
## This test verifies that the obby.json template:
## 1. Loads correctly via TemplateLoader
## 2. Creates proper domain entities (World, SceneNode, GameRule)
## 3. Preserves trigger_type metadata for checkpoints and win_zone
## 4. Has all required trigger semantics

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

	test_obby_template_loads_successfully()
	test_obby_template_structure()
	test_obby_template_has_checkpoint_triggers()
	test_obby_template_has_win_zone_trigger()
	test_obby_template_has_respawn_logic()
	test_obby_template_has_win_condition()
	test_create_project_from_obby_template()

	return _build_result("ObbyTemplateLoader")


func test_obby_template_loads_successfully() -> void:
	## Test that obby.json can be loaded without errors
	var result := _template_loader.load_template("obby")
	_assert_not_null(result, "obby template should load successfully")
	_assert_false(result.is_empty(), "obby template should not be empty")
	_assert_true(result.has("template_id"), "obby template should have template_id")
	_assert_eq(result.get("template_id"), "obby", "template_id should be 'obby'")


func test_obby_template_structure() -> void:
	## Test that obby.json has the expected structure
	var template := _template_loader.load_template("obby")
	
	## Check basic template fields
	_assert_true(template.has("name"), "obby template should have name")
	_assert_true(template.has("name_pl"), "obby template should have Polish name")
	_assert_true(template.has("description_pl"), "obby template should have Polish description")
	_assert_true(template.has("default_world"), "obby template should have default_world")
	
	## Check default_world structure
	var default_world := template.get("default_world", {}) as Dictionary
	_assert_false(default_world.is_empty(), "default_world should not be empty")
	_assert_true(default_world.has("nodes"), "default_world should have nodes")
	_assert_true(default_world.has("rules"), "default_world should have rules")
	
	## Check nodes array
	var nodes := default_world.get("nodes", []) as Array
	_assert_true(nodes.size() > 0, "obby template should have nodes")


func test_obby_template_has_checkpoint_triggers() -> void:
	## Test that obby.json defines checkpoint triggers
	var template := _template_loader.load_template("obby")
	var default_world := template.get("default_world", {}) as Dictionary
	var nodes := default_world.get("nodes", []) as Array
	
	var checkpoint_count := 0
	for node_variant in nodes:
		if node_variant is Dictionary:
			var node := node_variant as Dictionary
			if node.get("type") == "TRIGGER":
				var trigger_type := node.get("properties", {}).get("trigger_type", "") as String
				if trigger_type == "checkpoint":
					checkpoint_count += 1
	
	_assert_true(checkpoint_count >= 2, "obby template should have at least 2 checkpoint triggers, found %d" % checkpoint_count)


func test_obby_template_has_win_zone_trigger() -> void:
	## Test that obby.json defines a win_zone trigger
	var template := _template_loader.load_template("obby")
	var default_world := template.get("default_world", {}) as Dictionary
	var nodes := default_world.get("nodes", []) as Array
	
	var has_win_zone := false
	for node_variant in nodes:
		if node_variant is Dictionary:
			var node := node_variant as Dictionary
			if node.get("type") == "TRIGGER":
				var trigger_type := node.get("properties", {}).get("trigger_type", "") as String
				if trigger_type == "win_zone":
					has_win_zone = true
					break
	
	_assert_true(has_win_zone, "obby template should have a win_zone trigger")


func test_obby_template_has_respawn_logic() -> void:
	## Test that obby.json has rules for respawn behavior
	var template := _template_loader.load_template("obby")
	var default_world := template.get("default_world", {}) as Dictionary
	var rules := default_world.get("rules", []) as Array
	
	var has_respawn_rule := false
	for rule_variant in rules:
		if rule_variant is Dictionary:
			var rule := rule_variant as Dictionary
			var compiled_logic := rule.get("compiled_logic", "") as String
			if "set_respawn_point" in compiled_logic:
				has_respawn_rule = true
				break
	
	_assert_true(has_respawn_rule, "obby template should have set_respawn_point rule")


func test_obby_template_has_win_condition() -> void:
	## Test that obby.json has rules for win condition
	var template := _template_loader.load_template("obby")
	var default_world := template.get("default_world", {}) as Dictionary
	var rules := default_world.get("rules", []) as Array
	
	var has_win_rule := false
	for rule_variant in rules:
		if rule_variant is Dictionary:
			var rule := rule_variant as Dictionary
			var rule_type := rule.get("type", "") as String
			if rule_type == "WIN_CONDITION":
				has_win_rule = true
				break
	
	_assert_true(has_win_rule, "obby template should have a WIN_CONDITION rule")


func test_create_project_from_obby_template() -> void:
	## Test that a project can be created from the obby template
	var owner := PlayerProfile.new("obby_test_profile", PlayerProfile.Role.KID)
	var project := _template_loader.create_project_from_template("obby", owner)
	
	_assert_not_null(project, "Project should be created from obby template")
	if project == null:
		return
	
	## Verify project properties
	_assert_eq(project.template_id, "obby", "Project template_id should be 'obby'")
	_assert_eq(project.owner_profile_id, "obby_test_profile", "Project should have correct owner")
	
	## Verify world is created
	_assert_eq(project.worlds.size(), 1, "Project should have one default world")
	
	if project.worlds.size() > 0:
		var world := project.worlds[0]
		_assert_not_null(world, "World should exist")
		_assert_true(world.scene_nodes.size() > 0, "World should have scene nodes from template")
		
		## Count trigger nodes
		var trigger_count := 0
		var checkpoint_count := 0
		var win_zone_count := 0
		
		for node in world.scene_nodes:
			if node.node_type == NodeType.TRIGGER:
				trigger_count += 1
				var props := node.properties as Dictionary
				if props.has("trigger_type"):
					var trigger_type := props.get("trigger_type") as String
					if trigger_type == "checkpoint":
						checkpoint_count += 1
					elif trigger_type == "win_zone":
						win_zone_count += 1
			
		_assert_true(trigger_count >= 3, "World should have at least 3 trigger nodes (2 checkpoints + 1 win_zone), found %d" % trigger_count)
		_assert_true(checkpoint_count >= 2, "World should have at least 2 checkpoint triggers, found %d" % checkpoint_count)
		_assert_true(win_zone_count >= 1, "World should have at least 1 win_zone trigger, found %d" % win_zone_count)
		
		## Verify rules are created
		_assert_true(world.game_rules.size() > 0, "World should have game rules from template")
		
		var has_respawn_rule := false
		var has_win_rule := false
		
		for rule in world.game_rules:
			if "set_respawn_point" in rule.compiled_logic:
				has_respawn_rule = true
			if "win_level" in rule.compiled_logic:
				has_win_rule = true
		
		_assert_true(has_respawn_rule, "World should have respawn rule from template")
		_assert_true(has_win_rule, "World should have win rule from template")


# --- Helper Classes ---

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
