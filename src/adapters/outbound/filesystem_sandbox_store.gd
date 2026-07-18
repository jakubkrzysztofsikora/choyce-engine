## Filesystem-backed SandboxState store. Handles JSON serialisation, directory
## management, and local file I/O for the sandbox state.
class_name FilesystemSandboxStore
extends RefCounted

var _state_path: String = "user://sandbox_saves/current.json"


func setup(root_dir: String = "user://sandbox_saves") -> FilesystemSandboxStore:
	_state_path = "%s/current.json" % root_dir
	return self


func load_state() -> SandboxState:
	if not FileAccess.file_exists(_state_path):
		return SandboxState.new()
	var file := FileAccess.open(_state_path, FileAccess.READ)
	if file == null:
		return SandboxState.new()
	var raw := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		return SandboxState.new()
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return SandboxState.new()
	var s := SandboxState.from_dict(parsed as Dictionary)
	if s.is_empty():
		return SandboxState.new()
	return s


func save_state(state: SandboxState) -> bool:
	if state == null or state.world_id.is_empty():
		return false
	if state.saved_at_unix == 0:
		state.saved_at_unix = int(Time.get_unix_time_from_system())
	if not _ensure_parent_dir(_state_path):
		return false
	var file := FileAccess.open(_state_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state.to_dict(), "  "))
	file.close()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(_state_path)


func clear_save() -> bool:
	if not FileAccess.file_exists(_state_path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(_state_path)) == OK


func _ensure_parent_dir(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if dir_path.is_empty():
		return true
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	if DirAccess.dir_exists_absolute(absolute_dir):
		return true
	return DirAccess.make_dir_recursive_absolute(absolute_dir) == OK
