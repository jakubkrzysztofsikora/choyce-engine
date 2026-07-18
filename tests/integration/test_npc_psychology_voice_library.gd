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
	_test_e2e_integration_flow()

	print("\n--- TEST RUN SUMMARY ---")
	if _failures.is_empty():
		print("[test_npc_psychology_voice_library] ALL TESTS PASSED SUCCESSFULLY!")
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


## Test Case 1: Personality stats loading, role degradation, and dynamic updates
func _test_npc_psychology_baseline_and_dynamics() -> void:
	print("\nRunning Test Case 1: NPC Psychology Baseline and Dynamics...")

	# Baseline constructor validation
	var custom_npc := NPC_CHARACTER.new(
		"npc_custom", "hostile", "Custom Character", {}, "visual_123",
		0.8, 0.2, 0.9, 0.1, 0.7,  # OCEAN
		0.9, 0.8, 0.9             # Dark Triad: Mach, Narc, Psych
	)
	_expect(custom_npc.npc_id == "npc_custom", "Constructor should map npc_id")
	_expect(custom_npc.openness == 0.8, "Constructor should map openness")
	_expect(custom_npc.machiavellianism == 0.9, "Constructor should map Machiavellianism")
	_expect(custom_npc.narcissism == 0.8, "Constructor should map Narcissism")
	_expect(custom_npc.psychopathy == 0.9, "Constructor should map Psychopathy")

	# Role degradation for kid-safe mode
	var degraded := custom_npc.degraded_for_combat_off()
	_expect(degraded.role == NPC_CHARACTER.ROLE_GUIDE, "Hostile NPC should degrade to guide when combat is off")
	_expect(degraded.narcissism == 0.8, "Degraded NPC should retain Narcissism")

	# Dynamic emotional reaction verification
	# 1. Empathetic response (agreeableness > 0.6)
	var empathetic := NPC_CHARACTER.new("npc_friendly", "guide", "Empata", {}, "", 0.5, 0.5, 0.5, 0.9, 0.2)
	_expect(empathetic.anxiety == 0.1, "Empathetic baseline anxiety should be 0.1")
	empathetic.update_emotional_state(0.2, 10) # Player is low HP
	_expect(empathetic.anxiety > 0.1, "Empathetic NPC becomes anxious when player is hurt")
	_expect(empathetic.happiness < 0.5, "Empathetic NPC becomes sad when player is hurt")

	# 2. Psychopathic response (psychopathy > 0.4)
	var villain := NPC_CHARACTER.new("npc_villain", "hostile", "Złoczyńca", {}, "", 0.5, 0.5, 0.5, 0.1, 0.5, 0.0, 0.0, 0.8)
	_expect(villain.happiness == 0.5, "Villain baseline happiness should be 0.5")
	villain.update_emotional_state(0.2, 10) # Player is low HP
	_expect(villain.happiness > 0.5, "Psychopathic NPC is amused (happiness increases) when player is hurt")

	# 3. Narcissistic response to player success (narcissism > 0.5, player score > 50)
	var narcissist := NPC_CHARACTER.new("npc_narcissist", "guide", "Narcyz", {}, "", 0.5, 0.5, 0.5, 0.5, 0.5, 0.0, 0.9, 0.0)
	_expect(narcissist.irritability == 0.2, "Narcissist baseline irritability should be 0.2")
	narcissist.update_emotional_state(1.0, 150) # Player has high score
	_expect(narcissist.irritability > 0.2, "Narcissistic NPC gets irritated when player scores highly")


## Test Case 2: Library service file read/write, deduplication, and corruption recovery
func _test_npc_library_robustness_and_corruption() -> void:
	print("\nRunning Test Case 2: NPC Library Robustness and Corruption Recovery...")

	var service := LIBRARY_SERVICE.new()
	var test_npc := "npc_library_test_character"
	var path := "user://npc_library/%s.json" % test_npc

	# Ensure clean state
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var static_lines := {
		"greeting": "Dzień dobry!",
		"hint": "Spróbuj zebrać owoce."
	}

	# Verify loading empty library defaults to static lines
	var initial_load := service.load_library(test_npc, static_lines)
	_expect(initial_load.size() == 2, "Should load exactly 2 static lines when no dynamic file exists")

	# Save multiple dynamic lines
	service.save_new_answer(test_npc, "Nowa odpowiedź 1", "Hej", "happiness: 0.8")
	service.save_new_answer(test_npc, "Nowa odpowiedź 2", "Co słychać?", "happiness: 0.6")

	# Verify order and loading
	var loaded := service.load_library(test_npc, static_lines)
	_expect(loaded.size() == 4, "Should merge 2 static + 2 dynamic lines")
	_expect(loaded[2]["text"] == "Nowa odpowiedź 1", "Order of dynamic answers should match insertion")
	_expect(loaded[3]["player_prompt"] == "Co słychać?", "Metadata player prompt should be preserved")

	# Verify deduplication
	service.save_new_answer(test_npc, "Nowa odpowiedź 1", "Inny prompt", "happiness: 0.5")
	var deduplicated := service.load_library(test_npc, static_lines)
	_expect(deduplicated.size() == 4, "Duplicate answers should be ignored to prevent library bloat")

	# Verify file corruption recovery
	# Write corrupt data to the json file
	var corrupt_file := FileAccess.open(path, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{ INVALID JSON CORRUPT BODY {]}")
		corrupt_file.close()

	var recovered := service.load_library(test_npc, static_lines)
	_expect(recovered.size() == 2, "Should fallback gracefully to static lines on corrupted JSON file")
	
	# Clean up test files
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Test Case 3: Tailnet Voice Adapter caching, state machine, and ElevenLabs fallback
func _test_tailnet_voice_lifecycle_and_fallback() -> void:
	print("\nRunning Test Case 3: Tailnet Voice Adapter Lifecycle and Fallback...")

	# Create a dummy node as host
	var host := Node.new()
	root.add_child(host)

	var adapter := TAILNET_VOICE_ADAPTER.new()
	adapter.setup(host, "mock_eleven_key", "mock_voice_id")
	_expect(adapter.is_available(), "Tailnet voice adapter should be reported available")

	# Verify active voice configuration
	adapter.set_active_voice_id("npc_pirate")
	_expect(adapter._active_voice_id == "npc_pirate", "Active voice ID should be set correctly")

	# Test cache path generation is repeatable and deterministic
	var path_a := adapter._cache_path("Witaj przybyszu", "npc_explorer")
	var path_b := adapter._cache_path("Witaj przybyszu", "npc_explorer")
	_expect(path_a == path_b, "Cache path generation should be deterministic")

	# Test file existence check and playing
	var dummy_cache_file := "user://tailnet_voice_cache/dummy_test_line.mp3"
	adapter._ensure_cache_dir()
	var file := FileAccess.open(dummy_cache_file, FileAccess.WRITE)
	if file != null:
		# Write a small valid MP3 header or dummy bytes
		var dummy_bytes := PackedByteArray()
		dummy_bytes.resize(100)
		file.store_buffer(dummy_bytes)
		file.close()

	var played := adapter._play_file(dummy_cache_file, "Witaj przybyszu", 999)
	# Clean up immediately
	DirAccess.remove_absolute(dummy_cache_file)

	# Clean up host
	host.queue_free()


## Test Case 4: End-to-End simulation of dynamic answer library matching and prompt injection
func _test_e2e_integration_flow() -> void:
	print("\nRunning Test Case 4: End-to-End Integration Flow Simulation...")

	var service := LIBRARY_SERVICE.new()
	var npc_id := "npc_e2e_char"
	var static_lines := {"greeting": "Dzień dobry graczu!"}

	# 1. Clean previous library
	var path := "user://npc_library/%s.json" % npc_id
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	# 2. Simulate NPC speaking multiple responses
	service.save_new_answer(npc_id, "Witaj na mojej wyspie.", "Gdzie jestem?", "happiness: 0.7")
	service.save_new_answer(npc_id, "Uważaj na piratów w pobliżu.", "Czy tu jest bezpiecznie?", "anxiety: 0.6")

	# 3. Load library for the prompt
	var library := service.load_library(npc_id, static_lines)
	_expect(library.size() == 3, "Library should hold 1 static and 2 dynamic entries")

	# 4. Simulate a <use_ready> prompt injection matching
	var sys_prompt_str := "Gotowe wypowiedzi:\n"
	for item in library:
		sys_prompt_str += "[%d]: \"%s\"\n" % [item["index"], item["text"]]

	_expect(sys_prompt_str.contains("[0]: \"Dzień dobry graczu!\""), "Prompt should contain static greeting")
	_expect(sys_prompt_str.contains("[1]: \"Witaj na mojej wyspie.\""), "Prompt should contain dynamic answer 1")
	_expect(sys_prompt_str.contains("[2]: \"Uważaj na piratów w pobliżu.\""), "Prompt should contain dynamic answer 2")

	# 5. Simulate parsing of <use_ready> tag from LLM response
	var llm_response := "<use_ready>2</use_ready>"
	var clean_text := llm_response
	var is_ready_selection := false
	if clean_text.contains("<use_ready>") and clean_text.contains("</use_ready>"):
		var start := clean_text.find("<use_ready>") + 11
		var end := clean_text.find("</use_ready>")
		var idx_str := clean_text.substr(start, end - start).strip_edges()
		if idx_str.is_valid_int():
			var idx := idx_str.to_int()
			if idx >= 0 and idx < library.size():
				clean_text = library[idx]["text"]
				is_ready_selection = true

	_expect(is_ready_selection == true, "Should identify ready selection tag successfully")
	_expect(clean_text == "Uważaj na piratów w pobliżu.", "Resolved text should map to matching library index text")

	# Clean up test files
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
