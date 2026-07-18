## Filesystem adapter for sandbox snapshot persistence.
## Persists each snapshot under:
##   {root}/{profile_id}/{project_id}.json
## Uses atomic writes (write to .tmp, then rename) to avoid partial-
## write corruption.  On load, invalid or corrupt files are treated
## as missing so the gameplay layer can fall back to a fresh sandbox.
class_name FilesystemSandboxStore
extends RefCounted

var _root_path: String = "user://sandbox_saves"


func _init(root_path: String = "user://sandbox_saves") -> void:
	setup(root_path)


func setup(root_path: String = "user://sandbox_saves") -> FilesystemSandboxStore:
	_root_path = root_path.strip_edges()
	if _root_path.is_empty():
		_root_path = "user://sandbox_saves"
	_ensure_dir(_root_path)
	return self


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Persist a snapshot to disk.  Returns true on success.
func save_snapshot(snapshot: SandboxSnapshot) -> bool:
	if snapshot == null or not snapshot.is_valid():
		return false

	var dir_path := _profile_dir(snapshot.profile_id)
	if not _ensure_dir(dir_path):
		return false

	var final_path := _snapshot_path(snapshot.profile_id, snapshot.project_id)
	var tmp_path := final_path + ".tmp"

	# Write to a temporary file first.
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("FilesystemSandboxStore: cannot open tmp file – %s" % tmp_path)
		return false
	file.store_string(JSON.stringify(snapshot.to_dict(), "\t"))
	file.close()

	# Atomic rename.
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("FilesystemSandboxStore: cannot open dir – %s" % dir_path)
		return false

	if FileAccess.file_exists(final_path):
		dir.remove(final_path.get_file())

	var err := dir.rename(tmp_path.get_file(), final_path.get_file())
	if err != OK:
		push_warning("FilesystemSandboxStore: rename failed (%d) – %s" % [err, final_path])
		return false

	return true


## Load a previously-saved snapshot.  Returns null when the file is
## missing, corrupt, or fails validation.
func load_snapshot(profile_id: String, project_id: String) -> SandboxSnapshot:
	var path := _snapshot_path(profile_id, project_id)
	if not FileAccess.file_exists(path):
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("FilesystemSandboxStore: cannot read – %s" % path)
		return null

	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("FilesystemSandboxStore: corrupt JSON – %s" % path)
		return null

	var snap := SandboxSnapshot.from_dict(parsed as Dictionary)
	if snap == null or not snap.is_valid():
		push_warning("FilesystemSandboxStore: invalid snapshot – %s" % path)
		return null

	return snap


## Check whether a snapshot exists on disk for this profile+project pair.
func has_snapshot(profile_id: String, project_id: String) -> bool:
	return FileAccess.file_exists(_snapshot_path(profile_id, project_id))


## Delete the snapshot file.  Returns true when the file was removed or
## did not exist in the first place.
func clear_snapshot(profile_id: String, project_id: String) -> bool:
	var path := _snapshot_path(profile_id, project_id)
	if not FileAccess.file_exists(path):
		return true

	var dir_path := _profile_dir(profile_id)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("FilesystemSandboxStore: cannot open dir for clear – %s" % dir_path)
		return false

	var err := dir.remove(path.get_file())
	return err == OK


## List all valid snapshots stored under a profile directory.
func list_snapshots(profile_id: String) -> Array:
	var results: Array = []
	var dir_path := _profile_dir(profile_id)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		return results

	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".json") and not entry.ends_with(".tmp"):
			var project_id := entry.get_basename()
			var snap := load_snapshot(profile_id, project_id)
			if snap != null:
				results.append(snap)
		entry = dir.get_next()
	dir.list_dir_end()

	return results


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

func _snapshot_path(profile_id: String, project_id: String) -> String:
	return "%s/%s/%s.json" % [_root_path, profile_id, project_id]


func _profile_dir(profile_id: String) -> String:
	return "%s/%s" % [_root_path, profile_id]


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)
