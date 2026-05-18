## Filesystem-backed persistent consent adapter for IdentityConsentPort.
## Writes JSON to user://choyce_consent/consents.json with atomic-write
## (tmp file + rename) and fsync after every debounced flush.
## Safety default: any IO failure returns false (consent-deny).
##
## Writes debounced with 250ms trailing-edge timer; call flush() on shutdown.
## In-memory _profiles dict is the source of truth for reads; disk updated lazily.
##
## Integration:
##   - Call flush_if_due(delta_ms) each frame from the main loop to drive the
##     debounce window (e.g. pass Engine.get_process_frames() delta in ms).
##   - Call flush() before shutdown / _exit_tree() to ensure durability.
class_name FilesystemConsentStore
extends IdentityConsentPort

const DEFAULT_DIR := "user://choyce_consent"
const DEFAULT_FILE := "user://choyce_consent/consents.json"
const DEBOUNCE_MS := 250

var _consent_file: String = DEFAULT_FILE
var _profiles: Dictionary = {}
## True when _profiles has unsaved changes.
var _dirty: bool = false
## Accumulated milliseconds since the last write call (for debounce tracking).
var _pending_msec: int = 0


func setup(base_dir: String = DEFAULT_DIR) -> FilesystemConsentStore:
	var dir := base_dir.strip_edges()
	if dir.is_empty():
		dir = DEFAULT_DIR
	_consent_file = dir.rstrip("/") + "/consents.json"
	_ensure_dir(dir)
	_load()
	return self


func has_consent(profile_id: String, consent_type: String) -> bool:
	if profile_id.is_empty() or consent_type.is_empty():
		return false
	var profile_data_variant = _profiles.get(profile_id, {})
	if not (profile_data_variant is Dictionary):
		return false
	var profile_data: Dictionary = profile_data_variant
	return bool(profile_data.get(consent_type, false))


## Grant consent for profile_id + consent_type.
## Updates in-memory state immediately and marks the store dirty.
## Returns true on success; false on invalid input or IO failure at flush time.
func request_consent(profile_id: String, consent_type: String) -> bool:
	if profile_id.is_empty() or consent_type.is_empty():
		return false
	var profile_data_variant = _profiles.get(profile_id, {})
	var profile_data: Dictionary = (
		profile_data_variant.duplicate(true)
		if profile_data_variant is Dictionary
		else {}
	)
	profile_data[consent_type] = true
	_profiles[profile_id] = profile_data
	_mark_dirty()
	return true


func get_storage_path() -> String:
	return _consent_file


## Drive the debounce timer. Pass the milliseconds elapsed since the last call
## (e.g. from _process delta converted to ms, or from a fixed-tick loop).
## Flushes to disk when accumulated time >= DEBOUNCE_MS and the store is dirty.
##
## Example (main.gd _process):
##   _consent_store.flush_if_due(delta * 1000.0)
func flush_if_due(elapsed_msec: int) -> void:
	if not _dirty:
		_pending_msec = 0
		return
	_pending_msec += elapsed_msec
	if _pending_msec >= DEBOUNCE_MS:
		_flush_to_disk()


## Flush dirty in-memory state to disk immediately, regardless of timer.
## Call this before shutdown or whenever durability is required immediately.
func flush() -> void:
	if _dirty:
		_flush_to_disk()


# ── Private ────────────────────────────────────────────────────────────────────

func _mark_dirty() -> void:
	_dirty = true
	_pending_msec = 0


func _load() -> void:
	_profiles = {}
	if not FileAccess.file_exists(_consent_file):
		return

	var file := FileAccess.open(_consent_file, FileAccess.READ)
	if file == null:
		# IO failure → safety default: empty (all deny)
		return

	var json_text := file.get_as_text()
	if json_text.is_empty():
		return

	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return

	if parsed.has("profiles") and parsed["profiles"] is Dictionary:
		_profiles = parsed["profiles"].duplicate(true)
	else:
		_profiles = parsed.duplicate(true)


## Atomically write all in-memory consent profiles to disk.
func _flush_to_disk() -> bool:
	var payload := {
		"profiles": _profiles,
		"updated_at": Time.get_datetime_string_from_system(true, false),
	}
	var json_text := JSON.stringify(payload, "\t")

	# Atomic write: write to .tmp then rename
	var tmp_path := _consent_file + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		# IO failure → report failure; dirty flag stays set so next flush retries
		return false

	file.store_string(json_text)
	file.flush()  # fsync equivalent
	file = null   # close

	# Rename .tmp → final path (atomic on POSIX; best-effort on Windows)
	var dir := DirAccess.open(_consent_file.get_base_dir())
	if dir == null:
		return false

	var err := dir.rename(tmp_path, _consent_file)
	if err == OK:
		_dirty = false
		_pending_msec = 0
		return true
	return false


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)
