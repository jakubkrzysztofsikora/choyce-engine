## Application test: EvaluateGoalService
## Adventure (collect) + Obby (enter_zone) + lose-reason paths.
class_name TestEvaluateGoalService
extends ApplicationTest


var _svc: EvaluateGoalService


func _init() -> void:
	_svc = EvaluateGoalService.new()


func run() -> Dictionary:
	test_collect_in_progress_returns_null()
	test_collect_goal_met_returns_win()
	test_enter_zone_goal_met()
	test_forced_timeout_returns_lose()
	test_forced_abandoned_returns_lose()
	test_malformed_condition_fails_closed()
	test_progress_ratio_adventure()
	return _build_result("EvaluateGoalService")


func test_collect_in_progress_returns_null() -> void:
	var goal := GameGoal.new(
		GameGoal.KIND_COLLECT, 3, "Zbierz 3 klucze", "icon_key", "inventory.key>=3"
	)
	var outcome := _svc.evaluate(goal, {"inventory": {"key": 1}}, 10)
	_assert_true(outcome == null, "1 of 3 keys: still in progress")


func test_collect_goal_met_returns_win() -> void:
	var goal := GameGoal.new(
		GameGoal.KIND_COLLECT, 3, "Zbierz 3 klucze", "icon_key", "inventory.key>=3"
	)
	var outcome := _svc.evaluate(goal, {"inventory": {"key": 3}}, 100)
	_assert_true(outcome != null, "3 of 3 keys: outcome produced")
	_assert_true(outcome.won, "Should be a win")
	_assert_eq(outcome.reason, WinOutcome.REASON_GOAL_MET, "Reason goal_met")
	_assert_eq(outcome.score, 100, "Score preserved")


func test_enter_zone_goal_met() -> void:
	var goal := GameGoal.new(
		GameGoal.KIND_ENTER_ZONE, 1, "Dotrzyj do mety", "icon_flag", "in_zone.finish"
	)
	var outcome := _svc.evaluate(goal, {"in_zone": {"finish": true}}, 50)
	_assert_true(outcome != null, "Reached finish zone: outcome produced")
	_assert_true(outcome.won, "Reached finish zone: should win")


func test_forced_timeout_returns_lose() -> void:
	var goal := GameGoal.new(
		GameGoal.KIND_COLLECT, 3, "Zbierz", "icon", "inventory.key>=3"
	)
	var outcome := _svc.evaluate(goal, {"inventory": {"key": 1}}, 20, WinOutcome.REASON_TIMEOUT)
	_assert_true(outcome != null, "Forced timeout: outcome produced")
	_assert_true(not outcome.won, "Timeout = lose")
	_assert_eq(outcome.reason, WinOutcome.REASON_TIMEOUT, "Reason timeout")


func test_forced_abandoned_returns_lose() -> void:
	var goal := GameGoal.new(GameGoal.KIND_COLLECT, 3, "Z", "i", "inventory.k>=3")
	var outcome := _svc.evaluate(goal, {}, 0, WinOutcome.REASON_ABANDONED)
	_assert_true(outcome != null, "Abandoned: outcome produced")
	_assert_eq(outcome.reason, WinOutcome.REASON_ABANDONED, "Reason abandoned")


func test_malformed_condition_fails_closed() -> void:
	# Identifier not in whitelist → parse fails → fail-closed (null = in progress)
	var goal := GameGoal.new(GameGoal.KIND_COLLECT, 3, "Z", "i", "evil.payload==1")
	var outcome := _svc.evaluate(goal, {"evil": {"payload": 1}}, 0)
	_assert_true(outcome == null, "Malformed condition must never produce a win")


func test_progress_ratio_adventure() -> void:
	var goal := GameGoal.new(GameGoal.KIND_COLLECT, 3, "Z", "i", "inventory.key>=3")
	var r := _svc.progress_ratio(goal, {"inventory": {"key": 2}})
	# 2 of 3 ≈ 0.66
	_assert_true(absf(r - (2.0 / 3.0)) < 0.001, "Progress 2/3")
