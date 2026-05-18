## Filesystem-backed persistent consent adapter for IdentityConsentPort.
## Writes JSON to user://choyce_consent/consents.json with atomic-write
## (tmp file + rename) and fsync after every write.
## Safety default: any IO failure returns false (consent-deny).
class_name FilesystemConsentStore
extends IdentityConsentPort

const DEFAULT_DIR := "user://choyce_consent"
const DEFAULT_FILE := "user://choyce_consent/consents.json"

var _consent_file: String = DEFAULT_FILE
var _profiles: Dictionary = {}


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
	return _save()


func get_storage_path() -> String:
	return _consent_file


# ── Private ────────────────────────────────────────────────────────────────────

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


func _save() -> bool:
	var payload := {
		"profiles": _profiles,
		"updated_at": Time.get_datetime_string_from_system(true, false),
	}
	var json_text := JSON.stringify(payload, "\t")

	# Atomic write: write to .tmp then rename
	var tmp_path := _consent_file + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		# IO failure → safety default: report failure (caller treats as deny)
		return false

	file.store_string(json_text)
	file.flush()  # fsync equivalent
	file = null   # close

	# Rename .tmp → final path (atomic on POSIX; best-effort on Windows)
	var dir := DirAccess.open(_consent_file.get_base_dir())
	if dir == null:
		return false

	var err := dir.rename(tmp_path, _consent_file)
	return err == OK


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)
