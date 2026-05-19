## Smoke tests for CombatService.compute_damage kid-cap math.
## Run: godot --headless --script tests/application/test_combat_service.gd
class_name TestCombatService
extends SceneTree


func _init() -> void:
	var svc := CombatService.new()
	var failures: Array = []

	_assert(failures, "caps_at_third", svc.compute_damage(50, 30), 10)
	_assert(failures, "under_cap_passthrough", svc.compute_damage(5, 30), 5)
	_assert(failures, "negative_clamped_to_zero", svc.compute_damage(-5, 30), 0)
	# maxi(int(1/3),1) = maxi(0,1) = 1
	_assert(failures, "tiny_hp_floor_is_one", svc.compute_damage(100, 1), 1)
	# cap_divisor <= 0 disables cap entirely
	_assert(failures, "divisor_zero_disables_cap", svc.compute_damage(99999, 30, 0), 99999)
	_assert(failures, "divisor_negative_disables_cap", svc.compute_damage(99999, 30, -1), 99999)
	_assert(failures, "zero_raw_zero_out", svc.compute_damage(0, 30), 0)

	if failures.is_empty():
		print("[test_combat_service] OK 7/7")
		quit(0)
	else:
		printerr("[test_combat_service] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _assert(failures: Array, name: String, got: Variant, want: Variant) -> void:
	if got != want:
		failures.append("%s: got=%s want=%s" % [name, str(got), str(want)])
