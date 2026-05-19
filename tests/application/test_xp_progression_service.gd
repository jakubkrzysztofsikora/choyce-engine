## Smoke tests for XpProgressionService — curve, per-kill XP, apply_gain loop.
## Run: godot --headless --script tests/application/test_xp_progression_service.gd
class_name TestXpProgressionService
extends SceneTree


func _init() -> void:
	var svc := XpProgressionService.new()
	var failures: Array = []

	# xp_required: level<=0 → 4; otherwise int(pow(level,1.8) + level*4)
	_assert_eq(failures, "xp_required_level_0", svc.xp_required(0), 4)
	var expect_5 := int(pow(5.0, 1.8) + 5 * 4)
	_assert_eq(failures, "xp_required_level_5", svc.xp_required(5), expect_5)
	_assert_eq(failures, "xp_required_negative_clamps", svc.xp_required(-3), 4)

	# xp_for_kill: known, unknown fallback (5), override wins
	_assert_eq(failures, "kill_slime_green_default", svc.xp_for_kill("slime_green"), 8)
	_assert_eq(failures, "kill_unknown_fallback_5", svc.xp_for_kill("unknown_enemy"), 5)
	_assert_eq(failures, "kill_override_wins",
		svc.xp_for_kill("slime_green", {"slime_green": 50}), 50)
	_assert_eq(failures, "kill_big_slime", svc.xp_for_kill("big_slime"), 30)

	# apply_gain
	var r1: Dictionary = svc.apply_gain(0, 0, 4)
	_assert_eq(failures, "gain_exact_level_lvl", int(r1["level"]), 1)
	_assert_eq(failures, "gain_exact_level_xp", int(r1["xp"]), 0)

	var r2: Dictionary = svc.apply_gain(0, 0, 100)
	if int(r2["level"]) < 3:
		failures.append("gain_multi_skip: level=%d want>=3" % int(r2["level"]))

	var r3: Dictionary = svc.apply_gain(2, 5, 0)
	_assert_eq(failures, "gain_zero_noop_lvl", int(r3["level"]), 2)
	_assert_eq(failures, "gain_zero_noop_xp", int(r3["xp"]), 5)

	var r4: Dictionary = svc.apply_gain(0, 0, -10)
	_assert_eq(failures, "gain_negative_clamped_lvl", int(r4["level"]), 0)
	_assert_eq(failures, "gain_negative_clamped_xp", int(r4["xp"]), 0)

	if failures.is_empty():
		print("[test_xp_progression_service] OK")
		quit(0)
	else:
		printerr("[test_xp_progression_service] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _assert_eq(failures: Array, name: String, got: Variant, want: Variant) -> void:
	if got != want:
		failures.append("%s: got=%s want=%s" % [name, str(got), str(want)])
