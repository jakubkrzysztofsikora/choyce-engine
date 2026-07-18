## Application service coordinating the local sandbox save lifecycle.
## Keeps the actual I/O in FilesystemSandboxStore so the runtime can inject
## or stub it like other outbound adapters.
class_name SandboxPersistenceService
extends RefCounted

var _store: FilesystemSandboxStore
var _clock: ClockPort


func setup(store: FilesystemSandboxStore, clock: ClockPort = null) -> SandboxPersistenceService:
	_store = store
	_clock = clock
	return self


func save_sandbox(state: SandboxState) -> bool:
	if _store == null or state == null:
		return false
	if _clock != null:
		state.saved_at_unix = _clock.now_msec()
	return _store.save_state(state)


func load_sandbox() -> SandboxState:
	if _store == null:
		return SandboxState.new()
	return _store.load_state()


func has_saved_sandbox() -> bool:
	if _store == null:
		return false
	return _store.has_save()


func clear_sandbox() -> bool:
	if _store == null:
		return false
	return _store.clear_save()
