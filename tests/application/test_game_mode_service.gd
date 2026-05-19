## Smoke tests for GameModeService — mode resolution + LMB/RMB action routing.
## Run: godot --headless --script tests/application/test_game_mode_service.gd
class_name TestGameModeService
extends SceneTree


func _init() -> void:
	var svc := GameModeService.new()
	var failures: Array = []

	# current_mode: blocks → BUILD
	_assert_eq(failures, "grass_is_build",
		svc.current_mode("grass"), GameModeService.Mode.BUILD)
	_assert_eq(failures, "tree_oak_is_build",
		svc.current_mode("tree_oak"), GameModeService.Mode.BUILD)
	_assert_eq(failures, "ore_node_is_build",
		svc.current_mode("ore_node"), GameModeService.Mode.BUILD)

	# weapons → COMBAT
	_assert_eq(failures, "fist_is_combat",
		svc.current_mode("fist"), GameModeService.Mode.COMBAT)
	_assert_eq(failures, "sword_iron_is_combat",
		svc.current_mode("sword_iron"), GameModeService.Mode.COMBAT)

	# empty + unknown → NEUTRAL
	_assert_eq(failures, "empty_is_neutral",
		svc.current_mode(""), GameModeService.Mode.NEUTRAL)
	_assert_eq(failures, "unknown_is_neutral",
		svc.current_mode("unknown_id"), GameModeService.Mode.NEUTRAL)

	# action routing
	_assert_eq(failures, "lmb_build_break",
		svc.lmb_action_for(GameModeService.Mode.BUILD), "break_block")
	_assert_eq(failures, "lmb_combat_attack",
		svc.lmb_action_for(GameModeService.Mode.COMBAT), "attack")
	_assert_eq(failures, "rmb_build_place",
		svc.rmb_action_for(GameModeService.Mode.BUILD), "place_block")
	_assert_eq(failures, "rmb_combat_camera",
		svc.rmb_action_for(GameModeService.Mode.COMBAT), "camera_look")

	if failures.is_empty():
		print("[test_game_mode_service] OK")
		quit(0)
	else:
		printerr("[test_game_mode_service] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _assert_eq(failures: Array, name: String, got: Variant, want: Variant) -> void:
	if got != want:
		failures.append("%s: got=%s want=%s" % [name, str(got), str(want)])
