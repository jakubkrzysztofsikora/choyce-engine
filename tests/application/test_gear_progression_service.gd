## Smoke tests for GearProgressionService — tier eligibility + material consumption.
## Run: godot --headless --script tests/application/test_gear_progression_service.gd
class_name TestGearProgressionService
extends SceneTree


func _init() -> void:
	var svc := GearProgressionService.new()
	var failures: Array = []

	# empty tier list → -1
	_assert_eq(failures, "empty_tiers", svc.next_eligible_tier([], {}, 0, -1), -1)

	var t0 := _mk_tier("stick", 0, {})
	var t1 := _mk_tier("sword_iron", 1, {"wood": 2})
	var t2 := _mk_tier("sword_epic", 5, {"wood": 5, "gem": 1})
	var tiers: Array = [t0, t1, t2]

	# current_tier_index at end → -1
	_assert_eq(failures, "at_end_no_upgrade",
		svc.next_eligible_tier(tiers, {"wood": 99, "gem": 99}, 99, 2), -1)

	# locked by xp (t2 unlock_level=5, xp_level=3, but t1 still affordable and unlocked)
	_assert_eq(failures, "locked_returns_t1_when_t1_available",
		svc.next_eligible_tier(tiers, {"wood": 5}, 3, 0), 1)

	# locked when next tier above xp gate (start at index 1, t2 unlock=5, xp=3 → -1)
	_assert_eq(failures, "locked_by_xp_returns_neg1",
		svc.next_eligible_tier(tiers, {"wood": 99, "gem": 99}, 3, 1), -1)

	# affordable + unlocked → returns index
	_assert_eq(failures, "affordable_returns_t2",
		svc.next_eligible_tier(tiers, {"wood": 5, "gem": 1}, 5, 1), 2)

	# can't afford → -1
	_assert_eq(failures, "cannot_afford_returns_neg1",
		svc.next_eligible_tier(tiers, {"wood": 0}, 5, 0), -1)

	# consume_materials: success path mutates inventory
	var inv1 := {"wood": 5}
	var ok1 := svc.consume_materials(inv1, {"wood": 3})
	_assert_eq(failures, "consume_ok_returns_true", ok1, true)
	_assert_eq(failures, "consume_ok_remainder", int(inv1.get("wood", -1)), 2)

	# consume_materials: failure path leaves inventory alone
	var inv2 := {"wood": 2}
	var ok2 := svc.consume_materials(inv2, {"wood": 5})
	_assert_eq(failures, "consume_fail_returns_false", ok2, false)
	_assert_eq(failures, "consume_fail_unchanged", int(inv2.get("wood", -1)), 2)

	if failures.is_empty():
		print("[test_gear_progression_service] OK")
		quit(0)
	else:
		printerr("[test_gear_progression_service] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _mk_tier(tier_id: String, unlock_level: int, recipe: Dictionary) -> GearTierResource:
	var t := GearTierResource.new()
	t.tier_id = tier_id
	t.unlock_level = unlock_level
	t.recipe = recipe
	return t


func _assert_eq(failures: Array, name: String, got: Variant, want: Variant) -> void:
	if got != want:
		failures.append("%s: got=%s want=%s" % [name, str(got), str(want)])
