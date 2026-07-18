class_name NPCPersonalityContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	var npc := NPCCharacter.new("npc_test", "guide", "Testownik", {}, "npc_test")
	_assert_true(npc.openness == 0.5, "default openness is 0.5")
	_assert_true(npc.agreeableness == 0.5, "default agreeableness is 0.5")
	_assert_true(npc.happiness == 0.5, "default happiness is 0.5")
	_assert_true(npc.anxiety == 0.1, "default anxiety is 0.1")
	_assert_true(npc.machiavellianism == 0.0, "default machiavellianism is 0.0")
	_assert_true(npc.narcissism == 0.0, "default narcissism is 0.0")
	_assert_true(npc.psychopathy == 0.0, "default psychopathy is 0.0")

	var friendly := NPCCharacter.new(
		"npc_helper", "guide", "Pomocnik", {}, "npc_helper",
		0.5, 0.5, 0.5, 0.9, 0.2
	)
	# Hostile character with high psychopathy/narcissism
	var hostile := NPCCharacter.new(
		"npc_enemy", "hostile", "Wrog", {}, "npc_enemy",
		0.5, 0.5, 0.5, 0.2, 0.6,
		0.7, 0.6, 0.8
	)

	friendly.update_emotional_state(0.2, 10)
	hostile.update_emotional_state(0.2, 10)

	_assert_true(friendly.anxiety > 0.1, "agreeable NPC becomes anxious when player is hurt")
	_assert_true(friendly.happiness < 0.5, "agreeable NPC becomes less happy when player is hurt")
	_assert_true(hostile.happiness > 0.5, "psychopathic NPC becomes happier (amused) when player is hurt")

	var friendly_score := NPCCharacter.new(
		"npc_helper2", "guide", "Pomocnik2", {}, "npc_helper2",
		0.5, 0.5, 0.5, 0.9, 0.2
	)
	var hostile_score := NPCCharacter.new(
		"npc_enemy2", "hostile", "Wrog2", {}, "npc_enemy2",
		0.5, 0.5, 0.5, 0.2, 0.6,
		0.7, 0.8, 0.4  # Highly narcissistic
	)

	friendly_score.update_emotional_state(1.0, 100)
	hostile_score.update_emotional_state(1.0, 100)

	_assert_true(friendly_score.happiness > 0.5, "friendly NPC becomes happier when player has a high score")
	_assert_true(hostile_score.irritability > 0.2, "narcissistic NPC becomes highly irritated by player's success")

	var loader := NPCDialogueLoader.new()
	var npcs := loader.load_npcs_for_template("adventure")
	var pirate: NPCCharacter = null
	for n in npcs:
		if n.npc_id == "npc_pirate":
			pirate = n
			break

	_assert_true(pirate != null, "pirate exists in adventure template")
	if pirate != null:
		_assert_true(pirate.machiavellianism == 0.7, "pirate should have high Machiavellianism (0.7)")
		_assert_true(pirate.narcissism == 0.6, "pirate should have high Narcissism (0.6)")
		_assert_true(pirate.psychopathy == 0.4, "pirate should have medium Psychopathy (0.4)")

	return _build_result("NPCPersonality")
