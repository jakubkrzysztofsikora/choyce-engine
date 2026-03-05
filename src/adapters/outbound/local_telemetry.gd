## Local telemetry adapter for TelemetryPort.
## Emits JSONL audit events and strips ad-tech identifiers.
class_name LocalTelemetry
extends TelemetryPort

const BLOCKED_KEYS := {
	"ad_id": true,
	"adid": true,
	"advertising_id": true,
	"idfa": true,
	"gaid": true,
	"tracking_id": true,
	"fingerprint": true,
	"device_fingerprint": true,
}

var _log_file: String = "user://telemetry/events.jsonl"


func _init(log_file: String = "user://telemetry/events.jsonl") -> void:
	setup(log_file)


func setup(log_file: String = "user://telemetry/events.jsonl") -> LocalTelemetry:
	_log_file = log_file.strip_edges()
	if _log_file.is_empty():
		_log_file = "user://telemetry/events.jsonl"
	_ensure_dir(_log_file.get_base_dir())
	return self


func emit_event(event_name: String, properties: Dictionary) -> void:
	var clean_name := event_name.strip_edges()
	if clean_name.is_empty():
		return

	var event_record := {
		"event_name": clean_name,
		"timestamp": Time.get_datetime_string_from_system(true, false),
		"properties": _sanitize_properties(properties),
	}

	_write_event(event_record)


func get_log_file_path() -> String:
	return _log_file


func _write_event(event_record: Dictionary) -> void:
	var file: FileAccess = null
	if FileAccess.file_exists(_log_file):
		file = FileAccess.open(_log_file, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(_log_file, FileAccess.WRITE)

	if file == null:
		return

	file.store_line(JSON.stringify(event_record))


func _sanitize_properties(properties: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for key_variant in properties.keys():
		var key := str(key_variant)
		if _is_blocked_key(key):
			continue
		clean[key] = _sanitize_value(properties[key_variant])
	return clean


func _sanitize_value(value: Variant) -> Variant:
	if value is Dictionary:
		return _sanitize_properties(value)
	if value is Array:
		var clean_array: Array = []
		for item in value:
			clean_array.append(_sanitize_value(item))
		return clean_array
	return value


func _is_blocked_key(key: String) -> bool:
	var normalized := key.strip_edges().to_lower()
	if BLOCKED_KEYS.has(normalized):
		return true

	for marker in [
		"advert",
		"tracking",
		"fingerprint",
		"idfa",
		"gaid",
		"adid",
	]:
		if normalized.contains(marker):
			return true

	return false


func _ensure_dir(path: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var result := DirAccess.make_dir_recursive_absolute(absolute)
	return result == OK or DirAccess.dir_exists_absolute(absolute)
