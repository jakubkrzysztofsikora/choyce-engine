## Outbound port for parent-mode script storage and retrieval.
## Keeps script persistence behind an adapter boundary.
class_name ScriptRepositoryPort
extends RefCounted


func load_script(project_id: String, script_path: String) -> String:
	push_error("ScriptRepositoryPort.load_script() not implemented")
	return ""


func save_script(project_id: String, script_path: String, code: String) -> bool:
	push_error("ScriptRepositoryPort.save_script() not implemented")
	return false


func exists(project_id: String, script_path: String) -> bool:
	push_error("ScriptRepositoryPort.exists() not implemented")
	return false
