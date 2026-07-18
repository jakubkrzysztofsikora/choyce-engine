## Headless test for NPC answer library and dynamic sentence growth.
## Run: godot --headless --path . --script tests/application/test_npc_answer_library.gd
extends SceneTree

const LIBRARY_SERVICE := preload("res://src/application/npc_answer_library_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_dynamic_growth()
	if _failures.is_empty():
		print("[test_npc_answer_library] PASS")
		quit(0)
	else:
		printerr("[test_npc_answer_library] FAIL: ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_dynamic_growth() -> void:
	# Clear out any previous test data
	var dir := DirAccess.open("user://")
	var lib_dir: DirAccess = null
	if dir != null and dir.dir_exists("npc_library"):
		lib_dir = DirAccess.open("user://npc_library")
		if lib_dir != null:
			lib_dir.remove("npc_test_char.json")

	var service := LIBRARY_SERVICE.new()
	var static_lines := {
		"greeting": "Witaj przyjacielu!",
		"hint": "Poszukaj skarbu za drzewem.",
		"complex_fart": {
			"line_pl": "Ojej, co to za zapach!",
			"emotion": "funny"
		}
	}

	# Load library initially (only static lines should be returned)
	var initial := service.load_library("npc_test_char", static_lines)
	_expect(initial.size() == 3, "should load 3 static lines")
	_expect(initial[0]["text"] == "Witaj przyjacielu!", "first should be greeting")
	_expect(initial[0]["source"] == "static", "first should have static source")
	_expect(initial[2]["text"] == "Ojej, co to za zapach!", "should resolve complex nested structures")

	# Save a new dynamic reply
	service.save_new_answer("npc_test_char", "To był ciekawy dzień.", "Jak mija dzień?", "happy")

	# Load library again (should contain the dynamic reply)
	var updated := service.load_library("npc_test_char", static_lines)
	_expect(updated.size() == 4, "should load 3 static + 1 dynamic line")
	_expect(updated[3]["text"] == "To był ciekawy dzień.", "fourth line should be dynamic text")
	_expect(updated[3]["source"] == "dynamic", "fourth line should have dynamic source")
	_expect(updated[3]["player_prompt"] == "Jak mija dzień?", "should persist player prompt metadata")

	# Save the same reply again (should be ignored/deduplicated)
	service.save_new_answer("npc_test_char", "To był ciekawy dzień.", "Inny prompt", "neutral")
	var dup_check := service.load_library("npc_test_char", static_lines)
	_expect(dup_check.size() == 4, "should deduplicate identical text")

	# Clean up after ourselves
	if lib_dir != null:
		lib_dir.remove("npc_test_char.json")
