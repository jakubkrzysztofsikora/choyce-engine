## Template loader service.
## Loads template definitions from JSON and instantiates domain entities.
class_name TemplateLoader
extends RefCounted

var _project_store: ProjectStorePort
var _clock: ClockPort

func setup(project_store: ProjectStorePort, clock: ClockPort) -> TemplateLoader:
	_project_store = project_store
	_clock = clock
	return self

func load_template(template_id: String) -> Dictionary:
	var template_path := "res://data/templates/%s.json" % template_id
	var file := FileAccess.open(template_path, FileAccess.READ)
	if file == null:
		push_error("Template not found: %s" % template_id)
		return {}
	
	var content := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_error := json.parse(content)
	if parse_error != OK:
		push_error("Failed to parse template JSON: %s" % [parse_error])
		return {}
	
	return json.data

func create_project_from_template(template_id: String, owner: PlayerProfile) -> Project:
	var template_data := load_template(template_id)
	if template_data.is_empty():
		return null
	
	var now := _clock.now_iso()
	
	var project := Project.new()
	project.project_id = "%s_%s" % [owner.profile_id, template_id]
	project.title = template_data.get("name_pl", template_id)
	project.template_id = template_id
	project.owner_profile_id = owner.profile_id
	project.created_at = now
	project.updated_at = now

	# Create default world from template
	var default_world_data := template_data.get("default_world", {}) as Dictionary
	if not default_world_data.is_empty():
		var default_world := World.new()
		default_world.world_id = "%s_world_1" % project.project_id
		default_world.name = default_world_data.get("name_pl", template_id)
		
		# Add scene nodes from template
		var nodes_data := default_world_data.get("nodes", []) as Array
		for i in range(nodes_data.size()):
			var node_data_variant: Variant = nodes_data[i]
			if not (node_data_variant is Dictionary):
				continue
			var node_data: Dictionary = node_data_variant
			var scene_node := SceneNode.new()
			scene_node.node_id = "%s_node_%d" % [default_world.world_id, i]
			scene_node.node_type = _parse_node_type(node_data.get("type", "OBJECT"))
			scene_node.display_name = node_data.get("display_name_pl", "Node")
			var position := node_data.get("position", [0, 0, 0]) as Array
			scene_node.position = Vector3(position[0], position[1], position[2])
			default_world.add_node(scene_node)
		
		# Add game rules from template
		var rules_data := default_world_data.get("rules", []) as Array
		for i in range(rules_data.size()):
			var rule_data_variant: Variant = rules_data[i]
			if not (rule_data_variant is Dictionary):
				continue
			var rule_data: Dictionary = rule_data_variant
			var game_rule := GameRule.new()
			game_rule.rule_id = "%s_rule_%d" % [default_world.world_id, i]
			game_rule.rule_type = _parse_rule_type(rule_data.get("type", "TIMER"))
			game_rule.display_name = rule_data.get("display_name_pl", "Rule")
			game_rule.compiled_logic = rule_data.get("compiled_logic", "")
			default_world.add_rule(game_rule)
		
		project.add_world(default_world)
	
	_project_store.save_project(project)
	return project


func _parse_node_type(raw_type: Variant) -> SceneNode.NodeType:
	if raw_type is int:
		var raw_int: int = raw_type
		if raw_int >= int(SceneNode.NodeType.OBJECT) and raw_int <= int(SceneNode.NodeType.DECORATION):
			return raw_int as SceneNode.NodeType

	match str(raw_type).strip_edges().to_upper():
		"OBJECT":
			return SceneNode.NodeType.OBJECT
		"TERRAIN":
			return SceneNode.NodeType.TERRAIN
		"LIGHT":
			return SceneNode.NodeType.LIGHT
		"SPAWN", "SPAWN_POINT":
			return SceneNode.NodeType.SPAWN_POINT
		"TRIGGER":
			return SceneNode.NodeType.TRIGGER
		"DECORATION", "DECOR":
			return SceneNode.NodeType.DECORATION
		_:
			return SceneNode.NodeType.OBJECT


func _parse_rule_type(raw_type: Variant) -> GameRule.RuleType:
	if raw_type is int:
		var raw_int: int = raw_type
		if raw_int >= int(GameRule.RuleType.EVENT_TRIGGER) and raw_int <= int(GameRule.RuleType.ITEM_SPAWN):
			return raw_int as GameRule.RuleType

	match str(raw_type).strip_edges().to_upper():
		"EVENT_TRIGGER", "EVENT", "CHECKPOINT", "PUZZLE":
			return GameRule.RuleType.EVENT_TRIGGER
		"TIMER", "GROWTH", "RESOURCE":
			return GameRule.RuleType.TIMER
		"SCORING", "SCORE", "COLLECT":
			return GameRule.RuleType.SCORING
		"WIN_CONDITION", "WIN":
			return GameRule.RuleType.WIN_CONDITION
		"ITEM_SPAWN", "SPAWN":
			return GameRule.RuleType.ITEM_SPAWN
		_:
			return GameRule.RuleType.TIMER