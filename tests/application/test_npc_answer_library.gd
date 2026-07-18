## Headless unit tests for NPC answer library and dynamic sentence growth.
## Run: godot --headless --path . --script tests/application/test_npc_answer_library.gd
extends SceneTree

const LIBRARY_SERVICE := preload("res://src/application/npc_answer_library_service.gd")

var _failures: Array[String] = []
var _service: NPCAnswerLibraryService = null
var _test_npc := "npc_unit_test_char_unique"


func _init() -> void:
	_service = LIBRARY_SERVICE.new()
	_cleanup()

	_test_loads_static_lines_initially()
	_test_dynamic_reply_addition()
	_test_deduplication_integrity()
	_test_empty_static_lines()
	_test_empty_answer_handling()
	_test_corruption_recovery()

	_cleanup()

	if _failures.is_empty():
		print("[test_npc_answer_library] ALL UNIT TESTS PASSED")
		quit(0)
	else:
		printerr("[test_npc_answer_library] FAIL: ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("  [FAIL] ", message)
	else:
		print("  [PASS] ", message)


func _cleanup() -> void:
	var path := "user://npc_library/%s.json" % _test_npc
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _test_loads_static_lines_initially() -> void:
	print("Running: _test_loads_static_lines_initially...")
	var static_lines := {
		"greeting": "Witaj przyjacielu!",
		"hint": "Poszukaj skarbu za drzewem.",
		"complex_fart": {
			"line_pl": "Ojej, co to za zapach!",
			"emotion": "funny"
		}
	}
	var initial := _service.load_library(_test_npc, static_lines)
	_expect(initial.size() == 3, "should load exactly 3 static lines")
	_expect(initial[0]["text"] == "Witaj przyjacielu!", "first should be greeting")
	_expect(initial[0]["source"] == "static", "first should have static source")
	_expect(initial[2]["text"] == "Ojej, co to za zapach!", "should resolve complex nested structures")


func _test_dynamic_reply_addition() -> void:
	print("Running: _test_dynamic_reply_addition...")
	_cleanup()
	
	var static_lines := {"greeting": "Hej"}
	_service.save_new_answer(_test_npc, "To był ciekawy dzień.", "Jak mija dzień?", "happy")

	var updated := _service.load_library(_test_npc, static_lines)
	_expect(updated.size() == 2, "should load 1 static + 1 dynamic line")
	_expect(updated[1]["text"] == "To był ciekawy dzień.", "second line should be dynamic text")
	_expect(updated[1]["source"] == "dynamic", "second line should have dynamic source")
	_expect(updated[1]["player_prompt"] == "Jak mija dzień?", "should persist player prompt metadata")


func _test_deduplication_integrity() -> void:
	print("Running: _test_deduplication_integrity...")
	_cleanup()

	var static_lines := {"greeting": "Hej"}
	_service.save_new_answer(_test_npc, "Unikalna odpowiedź", "Prompt 1", "happy")
	_service.save_new_answer(_test_npc, "Unikalna odpowiedź", "Prompt 2", "angry")

	var check := _service.load_library(_test_npc, static_lines)
	_expect(check.size() == 2, "should deduplicate identical text and keep only the first entry")
	_expect(check[1]["player_prompt"] == "Prompt 1", "should keep metadata of the first entry")


func _test_empty_static_lines() -> void:
	print("Running: _test_empty_static_lines...")
	_cleanup()

	var empty_static := {}
	var loaded := _service.load_library(_test_npc, empty_static)
	_expect(loaded.is_empty(), "should load empty array if no static lines and no dynamic file exist")


func _test_empty_answer_handling() -> void:
	print("Running: _test_empty_answer_handling...")
	_cleanup()

	var static_lines := {"greeting": "Hej"}
	# Attempt to save empty or whitespace-only answers
	_service.save_new_answer(_test_npc, "", "Prompt", "happy")
	_service.save_new_answer(_test_npc, "   ", "Prompt", "happy")

	var loaded := _service.load_library(_test_npc, static_lines)
	_expect(loaded.size() == 1, "should ignore empty or whitespace-only dynamic answers")


func _test_corruption_recovery() -> void:
	print("Running: _test_corruption_recovery...")
	_cleanup()

	var static_lines := {"greeting": "Hej"}
	var path := "user://npc_library/%s.json" % _test_npc

	# Ensure folder exists
	_service.save_new_answer(_test_npc, "Temp line", "Prompt", "neutral")

	# Write corrupt data to the json file
	var corrupt_file := FileAccess.open(path, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{ INVALID JSON CORRUPT BODY {]}")
		corrupt_file.close()

	var recovered := _service.load_library(_test_npc, static_lines)
	_expect(recovered.size() == 1, "should fallback gracefully to static lines on corrupted JSON file")
