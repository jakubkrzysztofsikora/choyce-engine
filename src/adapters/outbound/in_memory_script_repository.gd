## In-memory script repository adapter for parent-mode editor workflows.
class_name InMemoryScriptRepository
extends ScriptRepositoryPort

var _scripts: Dictionary = {}


func load_script(project_id: String, script_path: String) -> String:
	var key := _key(project_id, script_path)
	if key.is_empty():
		return ""
	return str(_scripts.get(key, ""))


func save_script(project_id: String, script_path: String, code: String) -> bool:
	var key := _key(project_id, script_path)
	if key.is_empty():
		return false
	_scripts[key] = code
	return true


func exists(project_id: String, script_path: String) -> bool:
	var key := _key(project_id, script_path)
	if key.is_empty():
		return false
	return _scripts.has(key)


func _key(project_id: String, script_path: String) -> String:
	var clean_project := project_id.strip_edges()
	var clean_path := script_path.strip_edges()
	if clean_project.is_empty() or clean_path.is_empty():
		return ""
	return "%s::%s" % [clean_project, clean_path]
