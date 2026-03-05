class_name AIFailsafeControllerContractTest
extends PortContractTest


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T16:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767427200000 + _tick


func run() -> Dictionary:
	_reset()

	var controller := AIFailsafeController.new().setup(false)
	_assert_true(
		not controller.is_enabled(),
		"Failsafe should be disabled by default when setup(false)"
	)

	controller.enable("model outage")
	_assert_true(
		controller.is_enabled(),
		"enable() should activate failsafe mode"
	)
	_assert_true(
		controller.current_reason() == "model outage",
		"enable(reason) should persist failsafe reason"
	)

	var action := controller.build_disabled_action(
		"session-1",
		"Dodaj nowe zadanie",
		MockClock.new()
	)
	_assert_true(
		action.status == AIAssistantAction.ActionStatus.REJECTED,
		"Disabled action should be REJECTED in failsafe mode"
	)
	_assert_true(
		action.explanation.to_lower().contains("tryb awaryjny"),
		"Disabled action explanation should mention failsafe mode"
	)

	var hint_lvl1 := controller.rules_based_hint({"objective": "zbuduj sklep"}, 1)
	var hint_lvl2 := controller.rules_based_hint({"objective": "zbuduj sklep"}, 2)
	var hint_lvl3 := controller.rules_based_hint({"objective": "zbuduj sklep"}, 3)
	_assert_true(
		not hint_lvl1.strip_edges().is_empty(),
		"Rules-based helper should return level-1 hint text"
	)
	_assert_true(
		not hint_lvl2.strip_edges().is_empty(),
		"Rules-based helper should return level-2 hint text"
	)
	_assert_true(
		not hint_lvl3.strip_edges().is_empty(),
		"Rules-based helper should return level-3 hint text"
	)

	controller.disable()
	_assert_true(
		not controller.is_enabled(),
		"disable() should turn failsafe mode off"
	)
	_assert_true(
		controller.current_reason().is_empty(),
		"disable() should clear failsafe reason"
	)

	return _build_result("AIFailsafeController")
