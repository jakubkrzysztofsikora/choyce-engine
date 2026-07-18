## Filesystem-backed SandboxState store. Wraps the static
## SandboxState persistence helpers behind a small instance class so the
## gameplay runtime can inject / stub it the same way it injects
## SessionProgressStorePort and friends.
class_name FilesystemSandboxStore
extends RefCounted

var _state_path: String = "user://sandbox_saves/current.json"


func setup(root_dir: String = "user://sandbox_saves") -> FilesystemSandboxStore:
	_state_path = "%s/current.json" % root_dir
	return self


func load_state() -> SandboxState:
	return SandboxState.load_from_disk(_state_path)


func save_state(state: SandboxState) -> bool:
	if state == null:
		return false
	return state.save_to_disk(_state_path)


func has_save() -> bool:
	return SandboxState.disk_exists(_state_path)


func clear_save() -> bool:
	return SandboxState.clear_disk(_state_path)
