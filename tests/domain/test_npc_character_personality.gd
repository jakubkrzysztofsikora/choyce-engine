## Headless domain test for NPC character personality and psychology traits.
## Run: godot --headless --path . --script tests/domain/test_npc_character_personality.gd
extends SceneTree

const NPC_CHARACTER := preload("res://src/domain/world_authoring/npc_character.gd")
const NPC_LOADER := preload("res://src/application/npc_dialogue_loader.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_defaults()
	_test_dynamic_emotion_transitions()
	_test_loader_presets()
	if _failures.is_empty():
		print("[test_npc_character_personality] PASS")
		quit(0)
	else:
		printerr("[test_npc_character_personality] FAIL ", _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_defaults() -> void:
	var npc := NPC_CHARACTER.new("npc_test", "guide", "Testownik", {}, "npc_test")
	_expect(npc.openness == 0.5, "default openness should be 0.5")
	_expect(npc.agreeableness == 0.5, "default agreeableness should be 0.5")
	_expect(npc.happiness == 0.5, "default happiness should be 0.5")
	_expect(npc.anxiety == 0.1, "default anxiety should be 0.1")


func _test_dynamic_emotion_transitions() -> void:
	var friendly := NPC_CHARACTER.new(
		"npc_helper", "guide", "Pomocnik", {}, "npc_helper",
		0.5, 0.5, 0.5, 0.9, 0.2  # Highly agreeable
	)
	var hostile := NPC_CHARACTER.new(
		"npc_enemy", "hostile", "Wrog", {}, "npc_enemy",
		0.5, 0.5, 0.5, 0.2, 0.6  # Hostile (low agreeableness)
	)

	# When player is hurt (low HP ratio < 0.4)
	friendly.update_emotional_state(0.2, 10)
	hostile.update_emotional_state(0.2, 10)

	_expect(friendly.anxiety > 0.1, "agreeable NPC becomes anxious when player is hurt")
	_expect(friendly.happiness < 0.5, "agreeable NPC becomes less happy when player is hurt")
	_expect(hostile.happiness > 0.5, "hostile NPC becomes happier/amused when player is hurt")

	# Create fresh characters to test high score reaction without carrying over previous hurt states
	var friendly_score := NPC_CHARACTER.new(
		"npc_helper2", "guide", "Pomocnik2", {}, "npc_helper2",
		0.5, 0.5, 0.5, 0.9, 0.2
	)
	var hostile_score := NPC_CHARACTER.new(
		"npc_enemy2", "hostile", "Wrog2", {}, "npc_enemy2",
		0.5, 0.5, 0.5, 0.2, 0.6
	)

	# When player is doing very well (high score > 50)
	friendly_score.update_emotional_state(1.0, 100)
	hostile_score.update_emotional_state(1.0, 100)

	_expect(friendly_score.happiness > 0.5, "friendly NPC becomes happier when player has a high score")
	_expect(hostile_score.irritability > 0.2, "hostile NPC becomes irritated by player's success")


func _test_loader_presets() -> void:
	var loader := NPC_LOADER.new()
	var npcs := loader.load_npcs_for_template("adventure")
	var explorer: NPCCharacter = null
	var pirate: NPCCharacter = null
	for npc in npcs:
		if npc.npc_id == "npc_explorer":
			explorer = npc
		elif npc.npc_id == "npc_pirate":
			pirate = npc

	if explorer != null:
		_expect(explorer.openness == 0.9, "explorer should have high openness (0.9)")
		_expect(explorer.neuroticism == 0.2, "explorer should have low neuroticism (0.2)")
	else:
		_expect(false, "npc_explorer not found in adventure template")

	if pirate != null:
		_expect(pirate.agreeableness == 0.2, "pirate should have low agreeableness (0.2)")
		_expect(pirate.extraversion == 0.7, "pirate should have high extraversion (0.7)")
	else:
		_expect(false, "npc_pirate not found in adventure template")
