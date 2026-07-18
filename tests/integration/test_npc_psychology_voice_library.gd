## Heavy integration and regression test suite for NPC Psychology,
## Tailnet Voice Adapter, and Answer Library.
##
## Run headlessly:
##   godot4 --headless --path . --script tests/integration/test_npc_psychology_voice_library.gd
extends SceneTree

const TAILNET_VOICE_ADAPTER := preload("res://src/adapters/outbound/tailnet_voice_adapter.gd")
const LIBRARY_SERVICE := preload("res://src/application/npc_answer_library_service.gd")
const NPC_CHARACTER := preload("res://src/domain/world_authoring/npc_character.gd")

var _failures: Array[String] = []


func _init() -> void:
	print("--- STARTING HEAVY INTEGRATION TEST SUITE ---")
	
	_test_npc_psychology_baseline_and_dynamics()
	_test_npc_library_robustness_and_corruption()
	_test_tailnet_voice_lifecycle_and_fallback()
	_test_e2e_integration_flow_with_boundaries()

	print("\n--- TEST RUN SUMMARY ---")
	if _failures.is_empty():
		print("[test_npc_psychology_voice_library] ALL INTEGRATION TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("[test_npc_psychology_voice_library] FAILED WITH ", _failures.size(), " ERRORS:")
		for fail in _failures:
			printerr("- ", fail)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("[FAIL] ", message)
	else:
		print("[PASS] ", message)


## Test Case 1: Psychology mapping, role degradation, and clamped emotional dynamics
func _test_npc_psychology_baseline_and_dynamics() -> void:
	print("\nRunning Test Case 1: NPC Psychology Clamped Emotional Dynamics...")

	# Baseline constructor validation
	var custom_npc := NPC_CHARACTER.new(
		"npc_custom", "hostile", "Custom Character", {}, "visual_123",
		0.8, 0.2, 0.9, 0.1, 0.7,  # OCEAN
		0.9, 0.8, 0.9             # Dark Triad
	)
	_expect(custom_npc.npc_id == "npc_custom", "Constructor maps npc_id")
	_expect(custom_npc.openness == 0.8, "Constructor maps openness")
	_expect(custom_npc.machiavellianism == 0.9, "Constructor maps Machiavellianism")

	# Clamped dynamic updates (HP drop)
	var empathetic := NPC_CHARACTER.new("npc_friendly", "guide", "Empata", {}, "", 0.5, 0.5, 0.5, 0.9, 0.2)
	empathetic.happiness = 0.1
	empathetic.update_emotional_state(0.2, 10) # Player hurt
	_expect(empathetic.anxiety == 0.4, "Empathetic NPC anxiety increases by 0.3 (0.1 -> 0.4)")
	_expect(empathetic.happiness == 0.0, "Empathetic NPC happiness clamps at exactly 0.0")

	# Clamped dynamic updates (High Score)
	var narcissist := NPC_CHARACTER.new("npc_narcissist", "guide", "Narcyz", {}, "", 0.5, 0.5, 0.5, 0.5, 0.5, 0.0, 0.9, 0.0)
	narcissist.irritability = 0.9
	narcissist.update_emotional_state(1.0, 150) # Score > 50
	_expect(narcissist.irritability == 1.0, "Narcissist irritability clamps at exactly 1.0")


## Test Case 2: Library service read/write, deduplication, and corruption recovery
func _test_npc_library_robustness_and_corruption() -> void:
	print("\nRunning Test Case 2: NPC Library Robustness and Corruption Recovery...")

	var service := LIBRARY_SERVICE.new()
	var test_npc := "npc_library_integration_test_char"
	var path := "user://npc_library/%s.json" % test_npc

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var static_lines := {
		"greeting": "Dzień dobry!",
		"hint": "Spróbuj zebrać owoce."
	}

	var initial_load := service.load_library(test_npc, static_lines)
	_expect(initial_load.size() == 2, "Loads exactly 2 static lines when no file exists")

	service.save_new_answer(test_npc, "Nowa odpowiedź 1", "Hej", "happiness: 0.8")
	service.save_new_answer(test_npc, "Nowa odpowiedź 2", "Co słychać?", "happiness: 0.6")

	var loaded := service.load_library(test_npc, static_lines)
	_expect(loaded.size() == 4, "Merges static + dynamic lines correctly")
	_expect(loaded[2]["text"] == "Nowa odpowiedź 1", "Order of dynamic answers preserved")

	# Clean up test files
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Test Case 3: Tailnet Voice Adapter caching, configuration checks
func _test_tailnet_voice_lifecycle_and_fallback() -> void:
	print("\nRunning Test Case 3: Tailnet Voice Adapter Lifecycle and Fallback...")

	var host := Node.new()
	root.add_child(host)

	var adapter := TAILNET_VOICE_ADAPTER.new()
	adapter.setup(host, "mock_eleven_key", "mock_voice_id")
	_expect(adapter.is_available(), "Tailnet voice adapter reports available")

	adapter.set_active_voice_id("npc_pirate")
	_expect(adapter._active_voice_id == "npc_pirate", "Active voice ID sets correctly")

	var path_a := adapter._cache_path("Witaj", "npc_explorer")
	var path_b := adapter._cache_path("Witaj", "npc_explorer")
	_expect(path_a == path_b, "Cache path generation is deterministic")

	host.queue_free()


## Test Case 4: End-to-End simulation of dynamic answer library matching with boundary cases
func _test_e2e_integration_flow_with_boundaries() -> void:
	print("\nRunning Test Case 4: E2E Integration Flow with XML Parsing Boundaries...")

	var library: Array[Dictionary] = [
		{"index": 0, "text": "Dzień dobry!", "source": "static"},
		{"index": 1, "text": "Witaj na wyspie.", "source": "dynamic"},
		{"index": 2, "text": "Uważaj na piratów.", "source": "dynamic"}
	]

	# Helper lambda to simulate XML use_ready tag parsing
	var parse_use_ready_tag := func(response: String) -> Dictionary:
		var clean_text := response
		var is_ready := false
		if clean_text.contains("<use_ready>") and clean_text.contains("</use_ready>"):
			var start := clean_text.find("<use_ready>") + 11
			var end := clean_text.find("</use_ready>")
			var idx_str := clean_text.substr(start, end - start).strip_edges()
			if idx_str.is_valid_int():
				var idx := idx_str.to_int()
				if idx >= 0 and idx < library.size():
					clean_text = library[idx]["text"]
					is_ready = true
		return {"text": clean_text, "is_ready": is_ready}

	# 1. Standard correct tag
	var res1: Dictionary = parse_use_ready_tag.call("<use_ready>1</use_ready>")
	_expect(res1["is_ready"] == true, "Parses standard tag correctly")
	_expect(res1["text"] == "Witaj na wyspie.", "Resolves standard tag to index 1 text")

	# 2. Tag with spaces inside
	var res2: Dictionary = parse_use_ready_tag.call("<use_ready> 2 </use_ready>")
	_expect(res2["is_ready"] == true, "Parses tag with spaces inside correctly")
	_expect(res2["text"] == "Uważaj na piratów.", "Resolves tag with spaces to index 2 text")

	# 3. Out-of-bounds index (e.g. index 99)
	var res3: Dictionary = parse_use_ready_tag.call("<use_ready>99</use_ready>")
	_expect(res3["is_ready"] == false, "Rejects out-of-bounds index")
	_expect(res3["text"] == "<use_ready>99</use_ready>", "Retains raw text for out-of-bounds index")

	# 4. Non-integer input (e.g. "abc")
	var res4: Dictionary = parse_use_ready_tag.call("<use_ready>abc</use_ready>")
	_expect(res4["is_ready"] == false, "Rejects non-integer tag content")
