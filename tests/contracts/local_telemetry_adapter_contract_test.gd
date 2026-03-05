class_name LocalTelemetryAdapterContractTest
extends PortContractTest

const TEST_FILE := "user://contract_tests/task007_telemetry/events.jsonl"


func run() -> Dictionary:
	_reset()
	_cleanup_user_path("user://contract_tests/task007_telemetry")

	var telemetry := LocalTelemetry.new(TEST_FILE)
	_assert_has_method(telemetry, "emit_event")

	telemetry.emit_event("parental_controls_updated", {
		"safe_key": "ok",
		"ad_id": "123",
		"nested": {
			"tracking_id": "abc",
			"allowed": true,
		},
	})
	_note_check()

	var log_path := telemetry.get_log_file_path()
	_assert_true(FileAccess.file_exists(log_path), "Telemetry log file should be created")

	var file := FileAccess.open(log_path, FileAccess.READ)
	_assert_true(file != null, "Telemetry log should be readable")

	if file != null:
		var lines := file.get_as_text().split("\n", false)
		_assert_true(not lines.is_empty(), "Telemetry log should contain at least one line")
		if not lines.is_empty():
			var parsed = JSON.parse_string(lines[lines.size() - 1])
			_assert_true(parsed is Dictionary, "Telemetry log line should be valid JSON")
			if parsed is Dictionary:
				_assert_true(
					str(parsed.get("event_name", "")) == "parental_controls_updated",
					"Telemetry event_name should be preserved"
				)
				var properties = parsed.get("properties", {})
				_assert_true(properties is Dictionary, "Telemetry properties should be Dictionary")
				if properties is Dictionary:
					_assert_true(
						properties.has("safe_key"),
						"Non-blocked properties should be preserved"
					)
					_assert_true(
						not properties.has("ad_id"),
						"Blocked ad-tech key should be removed"
					)
					var nested = properties.get("nested", {})
					_assert_true(nested is Dictionary, "Nested properties should stay Dictionary")
					if nested is Dictionary:
						_assert_true(
							not nested.has("tracking_id"),
							"Nested blocked tracking key should be removed"
						)
						_assert_true(
							nested.has("allowed"),
							"Nested allowed key should be preserved"
						)

	_cleanup_user_path("user://contract_tests/task007_telemetry")
	return _build_result("LocalTelemetryAdapter")


func _cleanup_user_path(path: String) -> void:
	_remove_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _remove_dir_recursive_absolute(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue

		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_remove_dir_recursive_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()

	DirAccess.remove_absolute(path)
