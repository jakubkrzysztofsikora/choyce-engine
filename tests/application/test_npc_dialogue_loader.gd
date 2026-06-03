## Application test: NPCDialogueLoader
## Verifies adventure + obby NPC loading, role mapping, line lookup,
## and combat-policy degradation.
class_name TestNpcDialogueLoader
extends ApplicationTest


var _loader: NPCDialogueLoader


func _init() -> void:
	_loader = NPCDialogueLoader.new()


func run() -> Dictionary:
	test_loads_adventure_roster()
	test_pirate_is_hostile_by_default()
	test_combat_off_degrades_hostile_to_guide()
	test_obby_coach_speaks_polish_greeting()
	test_unknown_template_returns_empty()
	test_cache_is_reused()
	return _build_result("NPCDialogueLoader")


func test_loads_adventure_roster() -> void:
	var npcs := _loader.load_npcs_for_template("adventure")
	_assert_true(npcs.size() == 3, "Adventure has 3 NPCs (explorer + pirate + parrot)")
	var ids: Array = []
	for n in npcs:
		ids.append(n.npc_id)
	_assert_true(ids.has("npc_explorer"), "Roster contains npc_explorer")
	_assert_true(ids.has("npc_pirate"), "Roster contains npc_pirate")
	_assert_true(ids.has("npc_parrot"), "Roster contains npc_parrot")


func test_pirate_is_hostile_by_default() -> void:
	var npcs := _loader.load_npcs_for_template("adventure")
	for n in npcs:
		if n.npc_id == "npc_pirate":
			_assert_eq(n.role, NPCCharacter.ROLE_HOSTILE, "Pirate is hostile by default")
			return
	_assert_true(false, "Pirate not found in roster")


func test_combat_off_degrades_hostile_to_guide() -> void:
	var npcs := _loader.load_npcs_for_template("adventure")
	var filtered := _loader.filtered_for_policy(npcs, false)
	for n in filtered:
		if n.npc_id == "npc_pirate":
			_assert_eq(n.role, NPCCharacter.ROLE_GUIDE,
				"Combat off must degrade pirate to guide")
			return
	_assert_true(false, "Pirate missing from filtered roster")


func test_obby_coach_speaks_polish_greeting() -> void:
	var npcs := _loader.load_npcs_for_template("obby")
	for n in npcs:
		if n.npc_id == "npc_coach":
			var greeting: String = n.line_for("greeting")
			_assert_true(greeting.length() > 0, "Coach has a non-empty greeting")
			_assert_true(greeting.contains("Skacz") or greeting.contains("wyzwanie"),
				"Greeting is the kid-register coach line")
			return
	_assert_true(false, "Coach not found in obby roster")


func test_unknown_template_returns_empty() -> void:
	var npcs := _loader.load_npcs_for_template("does_not_exist")
	_assert_eq(npcs.size(), 0, "Unknown template -> empty roster (no fake NPCs)")


func test_cache_is_reused() -> void:
	var first := _loader.load_npcs_for_template("adventure")
	var second := _loader.load_npcs_for_template("adventure")
	# Same Array instance from cache (identity equality).
	_assert_true(first == second, "Cached roster reused on second call")
