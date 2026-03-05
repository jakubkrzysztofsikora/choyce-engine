## Local file-backed consent adapter for IdentityConsentPort.
## Persists profile consent decisions in JSON under user://.
## Optionally encrypts data at rest when an EncryptedStoragePort is provided.
class_name LocalConsentStore
extends IdentityConsentPort

var _consent_file: String = "user://consent/consents.json"
var _profiles: Dictionary = {}
var _encrypted_storage: EncryptedStoragePort
var _encryption_key: PackedByteArray


func _init(consent_file: String = "user://consent/consents.json") -> void:
	setup(consent_file)


func setup(
	consent_file: String = "user://consent/consents.json",
	encrypted_storage: EncryptedStoragePort = null,
	encryption_key: PackedByteArray = PackedByteArray()
) -> LocalConsentStore:
	_consent_file = consent_file.strip_edges()
	if _consent_file.is_empty():
		_consent_file = "user://consent/consents.json"
	_encrypted_storage = encrypted_storage
	_encryption_key = encryption_key
	_ensure_dir(_consent_file.get_base_dir())
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


func _is_encrypted() -> bool:
	return _encrypted_storage != null and not _encryption_key.is_empty()


func _load() -> void:
	_profiles = {}

	var json_text: String = ""
	if _is_encrypted():
		var encrypted_path := _consent_file + ".enc"
		if not _encrypted_storage.has_encrypted(encrypted_path):
			# Try loading unencrypted fallback for migration
			if FileAccess.file_exists(_consent_file):
				json_text = _load_plaintext()
			else:
				return
		else:
			var decrypted := _encrypted_storage.read_encrypted(
				encrypted_path, _encryption_key
			)
			if decrypted.is_empty():
				return
			json_text = decrypted.get_string_from_utf8()
	else:
		if not FileAccess.file_exists(_consent_file):
			return
		json_text = _load_plaintext()

	if json_text.is_empty():
		return

	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return

	if parsed.has("profiles") and parsed["profiles"] is Dictionary:
		_profiles = parsed["profiles"].duplicate(true)
	else:
		_profiles = parsed.duplicate(true)


func _load_plaintext() -> String:
	var file := FileAccess.open(_consent_file, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _save() -> bool:
	var payload := {
		"profiles": _profiles,
		"updated_at": Time.get_datetime_string_from_system(true, false),
	}

	var json_text := JSON.stringify(payload, "\t")

	if _is_encrypted():
		var encrypted_path := _consent_file + ".enc"
		return _encrypted_storage.write_encrypted(
			encrypted_path,
			json_text.to_utf8_buffer(),
			_encryption_key
		)

	var file := FileAccess.open(_consent_file, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_text)
	return true


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)
