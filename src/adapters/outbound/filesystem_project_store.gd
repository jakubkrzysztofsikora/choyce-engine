## Filesystem adapter for ProjectStorePort.
## Persists each project under:
##   projects/{project_id}/manifest.json
##   projects/{project_id}/worlds/{world_id}.json
##   projects/{project_id}/assets/
class_name FilesystemProjectStore
extends ProjectStorePort

const MANIFEST_FILE := "manifest.json"
const WORLDS_DIR := "worlds"
const ASSETS_DIR := "assets"
const FORMAT_VERSION := 1

var _projects_root: String = "user://projects"


func _init(root_path: String = "user://projects") -> void:
	setup(root_path)


func setup(root_path: String = "user://projects") -> FilesystemProjectStore:
	_projects_root = root_path.strip_edges()
	if _projects_root.is_empty():
		_projects_root = "user://projects"
	_ensure_dir(_projects_root)
	return self


func save_project(project: Project) -> bool:
	if project == null or project.project_id.is_empty():
		return false

	var project_dir := _project_dir(project.project_id)
	var worlds_dir := _worlds_dir(project.project_id)
	var assets_dir := _assets_dir(project.project_id)

	if not _ensure_dir(project_dir):
		return false
	if not _ensure_dir(worlds_dir):
		return false
	if not _ensure_dir(assets_dir):
		return false

	var world_ids: Array[String] = []
	for world in project.worlds:
		if not (world is World):
			continue
		world_ids.append(world.world_id)
		if not _write_json(
			"%s/%s.json" % [worlds_dir, world.world_id],
			_serialize_world(world)
		):
			return false

	var manifest := _serialize_manifest(project, world_ids)
	return _write_json("%s/%s" % [project_dir, MANIFEST_FILE], manifest)


func load_project(project_id: String) -> Project:
	if project_id.is_empty():
		return null

	var manifest_path := "%s/%s" % [_project_dir(project_id), MANIFEST_FILE]
	if not FileAccess.file_exists(manifest_path):
		return null

	var manifest_variant = _read_json(manifest_path)
	if not (manifest_variant is Dictionary):
		return null
	var manifest: Dictionary = manifest_variant

	var project := Project.new(
		str(manifest.get("project_id", project_id)),
		str(manifest.get("title", ""))
	)
	project.description = str(manifest.get("description", ""))
	project.template_id = str(manifest.get("template_id", ""))
	project.owner_profile_id = str(manifest.get("owner_profile_id", ""))
	project.created_at = str(manifest.get("created_at", ""))
	project.updated_at = str(manifest.get("updated_at", ""))

	var world_ids_variant: Variant = manifest.get("world_ids", [])
	var world_ids: Array = world_ids_variant if world_ids_variant is Array else []
	for world_id_variant in world_ids:
		var world_id := str(world_id_variant)
		var world_path := "%s/%s.json" % [_worlds_dir(project_id), world_id]
		var world_data = _read_json(world_path)
		if world_data is Dictionary:
			var world := _deserialize_world(world_data)
			if world != null:
				project.add_world(world)

	return project


func list_projects() -> Array:
	var projects: Array = []
	_ensure_dir(_projects_root)

	var root_dir := DirAccess.open(_projects_root)
	if root_dir == null:
		return projects

	root_dir.list_dir_begin()
	var entry := root_dir.get_next()
	while not entry.is_empty():
		if root_dir.current_is_dir() and not entry.begins_with("."):
			var loaded := load_project(entry)
			if loaded != null:
				projects.append(loaded)
		entry = root_dir.get_next()
	root_dir.list_dir_end()

	return projects


func _serialize_manifest(project: Project, world_ids: Array[String]) -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"project_id": project.project_id,
		"title": project.title,
		"description": project.description,
		"template_id": project.template_id,
		"owner_profile_id": project.owner_profile_id,
		"created_at": project.created_at,
		"updated_at": project.updated_at,
		"world_ids": world_ids,
		"asset_references": _collect_asset_references(project),
		"ai_provenance": _collect_ai_provenance_manifest(project),
	}


func _serialize_world(world: World) -> Dictionary:
	var nodes: Array = []
	for node in world.scene_nodes:
		if node is SceneNode:
			nodes.append(_serialize_scene_node(node))

	var rules: Array = []
	for rule in world.game_rules:
		if rule is GameRule:
			rules.append(_serialize_game_rule(rule))

	return {
		"world_id": world.world_id,
		"name": world.name,
		"theme": world.theme,
		"is_playable": world.is_playable,
		"scene_nodes": nodes,
		"game_rules": rules,
	}


func _serialize_scene_node(node: SceneNode) -> Dictionary:
	var children: Array = []
	for child in node.children:
		if child is SceneNode:
			children.append(_serialize_scene_node(child))

	var data: Dictionary = {
		"node_id": node.node_id,
		"node_type": int(node.node_type),
		"display_name": node.display_name,
		"position": _vector_to_array(node.position),
		"rotation": _vector_to_array(node.rotation),
		"scale": _vector_to_array(node.scale),
		"properties": node.properties.duplicate(true),
		"children": children,
		"parent_id": node.parent_id,
	}

	if node.provenance != null:
		data["provenance"] = {
			"source": int(node.provenance.source),
			"generator_model": node.provenance.generator_model,
			"audit_id": node.provenance.audit_id,
			"timestamp": node.provenance.timestamp
		}

	return data


func _serialize_game_rule(rule: GameRule) -> Dictionary:
	return {
		"rule_id": rule.rule_id,
		"rule_type": int(rule.rule_type),
		"display_name": rule.display_name,
		"source_blocks": rule.source_blocks.duplicate(true),
		"compiled_logic": rule.compiled_logic,
		"is_active": rule.is_active,
	}


func _deserialize_world(world_data: Dictionary) -> World:
	var world := World.new(
		str(world_data.get("world_id", "")),
		str(world_data.get("name", ""))
	)
	world.theme = str(world_data.get("theme", ""))
	world.is_playable = bool(world_data.get("is_playable", false))

	var nodes_variant = world_data.get("scene_nodes", [])
	if nodes_variant is Array:
		for node_data in nodes_variant:
			if node_data is Dictionary:
				var node := _deserialize_scene_node(node_data)
				if node != null:
					world.add_node(node)

	var rules_variant = world_data.get("game_rules", [])
	if rules_variant is Array:
		for rule_data in rules_variant:
			if rule_data is Dictionary:
				var rule := _deserialize_game_rule(rule_data)
				if rule != null:
					world.add_rule(rule)

	return world


func _deserialize_scene_node(node_data: Dictionary) -> SceneNode:
	var node_type := int(node_data.get("node_type", int(SceneNode.NodeType.OBJECT)))
	var node := SceneNode.new(str(node_data.get("node_id", "")), node_type)
	node.display_name = str(node_data.get("display_name", ""))
	node.position = _array_to_vector(node_data.get("position", []))
	node.rotation = _array_to_vector(node_data.get("rotation", []))
	node.scale = _array_to_vector(node_data.get("scale", [1.0, 1.0, 1.0]))
	var properties = node_data.get("properties", {})
	node.properties = properties.duplicate(true) if properties is Dictionary else {}
	node.parent_id = str(node_data.get("parent_id", ""))

	if node_data.has("provenance"):
		var prov_data: Dictionary = node_data["provenance"]
		var source = int(prov_data.get("source", 0))
		var model = str(prov_data.get("generator_model", ""))
		var audit = str(prov_data.get("audit_id", ""))
		node.provenance = ProvenanceData.new(source, model, audit)
		node.provenance.timestamp = int(prov_data.get("timestamp", 0))

	var children_data = node_data.get("children", [])
	if children_data is Array:
		for child_data in children_data:
			if child_data is Dictionary:
				var child := _deserialize_scene_node(child_data)
				if child != null:
					node.add_child_node(child)

	return node


func _deserialize_game_rule(rule_data: Dictionary) -> GameRule:
	var rule_type := int(rule_data.get("rule_type", int(GameRule.RuleType.EVENT_TRIGGER)))
	var rule := GameRule.new(str(rule_data.get("rule_id", "")), rule_type)
	rule.display_name = str(rule_data.get("display_name", ""))
	var source_blocks = rule_data.get("source_blocks", [])
	rule.source_blocks = source_blocks.duplicate(true) if source_blocks is Array else []
	rule.compiled_logic = str(rule_data.get("compiled_logic", ""))
	rule.is_active = bool(rule_data.get("is_active", true))
	return rule


func _collect_asset_references(project: Project) -> Array[String]:
	var seen: Dictionary = {}
	for world in project.worlds:
		if not (world is World):
			continue
		for node in world.scene_nodes:
			if node is SceneNode:
				_collect_asset_refs_from_node(node, seen)

	var refs: Array[String] = []
	for key in seen.keys():
		refs.append(str(key))
	refs.sort()
	return refs


func _collect_asset_refs_from_node(node: SceneNode, seen: Dictionary) -> void:
	for key in ["asset_id", "asset_ref"]:
		var value = node.properties.get(key, "")
		if value is String and not value.is_empty():
			seen[value] = true

	var ids_variant = node.properties.get("asset_ids", [])
	if ids_variant is Array:
		for asset_id in ids_variant:
			if asset_id is String and not asset_id.is_empty():
				seen[asset_id] = true

	for child in node.children:
		if child is SceneNode:
			_collect_asset_refs_from_node(child, seen)


func _collect_ai_provenance_manifest(project: Project) -> Array:
	var rows: Array = []
	for world in project.worlds:
		if not (world is World):
			continue
		for node in world.scene_nodes:
			if node is SceneNode:
				_collect_provenance_from_node(node, world.world_id, rows)

	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var a_key := "%s|%s|%s" % [
				str(a.get("audit_id", "")),
				str(a.get("world_id", "")),
				str(a.get("node_id", "")),
			]
			var b_key := "%s|%s|%s" % [
				str(b.get("audit_id", "")),
				str(b.get("world_id", "")),
				str(b.get("node_id", "")),
			]
			return a_key < b_key
	)
	return rows


func _collect_provenance_from_node(node: SceneNode, world_id: String, rows: Array) -> void:
	if node.provenance != null and node.provenance.source != ProvenanceData.SourceType.HUMAN:
		rows.append(
			{
				"world_id": world_id,
				"node_id": node.node_id,
				"source": int(node.provenance.source),
				"generator_model": node.provenance.generator_model,
				"audit_id": node.provenance.audit_id,
				"timestamp": node.provenance.timestamp,
			}
		)

	for child in node.children:
		if child is SceneNode:
			_collect_provenance_from_node(child, world_id, rows)


func _write_json(path: String, data: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed


func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _array_to_vector(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2])
		)
	return Vector3.ZERO


func _project_dir(project_id: String) -> String:
	return "%s/%s" % [_projects_root, project_id]


func _worlds_dir(project_id: String) -> String:
	return "%s/%s" % [_project_dir(project_id), WORLDS_DIR]


func _assets_dir(project_id: String) -> String:
	return "%s/%s" % [_project_dir(project_id), ASSETS_DIR]


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)
