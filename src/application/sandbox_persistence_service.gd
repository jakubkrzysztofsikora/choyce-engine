## Application service that coordinates sandbox persistence.
## Stamps each snapshot with the current wall-clock time and delegates
## the actual I/O to a FilesystemSandboxStore adapter.  The gameplay
## layer calls save_sandbox / load_sandbox without knowing where or
## how the data is stored.
class_name SandboxPersistenceService
extends RefCounted

var _store: FilesystemSandboxStore
var _clock: ClockPort


func setup(
	store: FilesystemSandboxStore,
	clock: ClockPort
) -> SandboxPersistenceService:
	_store = store
	_clock = clock
	return self


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Persist a sandbox snapshot.  Automatically sets saved_at_iso from
## the injected clock.  Returns true on success.
func save_sandbox(snapshot: SandboxSnapshot) -> bool:
	if _store == null or _clock == null:
		return false
	if snapshot == null:
		return false

	snapshot.saved_at_iso = _clock.now_iso()
	return _store.save_snapshot(snapshot)


## Load the latest valid snapshot for a profile+project pair.
## Returns null when no save exists, the file is corrupt, or
## validation fails – the caller should treat null as "start a
## fresh sandbox".
func load_sandbox(profile_id: String, project_id: String) -> SandboxSnapshot:
	if _store == null:
		return null
	return _store.load_snapshot(profile_id, project_id)


## Quick check whether a saved sandbox exists on disk.
func has_saved_sandbox(profile_id: String, project_id: String) -> bool:
	if _store == null:
		return false
	return _store.has_snapshot(profile_id, project_id)


## Remove a saved sandbox (e.g. after "Nowa gra" confirmation).
## Returns true when the save was cleared or didn't exist.
func clear_sandbox(profile_id: String, project_id: String) -> bool:
	if _store == null:
		return false
	return _store.clear_snapshot(profile_id, project_id)
