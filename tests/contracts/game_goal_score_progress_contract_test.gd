## Contract: a score-based collect goal (win_condition "score>=N") advances
## its HUD progress bar from ctx["score"], not from inventory. The Adventure
## slice wins on score>=15 (3 monsters x 5), so the bar must fill 0->1 as the
## kid racks up kills — otherwise it reads as a broken flat bar until win.
##
## Existing inventory-based collect goals (win_condition "inventory.<name>>=N")
## must be untouched: they keep reading inventory.
class_name GameGoalScoreProgressContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	# Score-based collect goal: bar tracks ctx.score / target.
	var score_goal := GameGoal.new(
		GameGoal.KIND_COLLECT, 15, "Pokonaj 3 potwory", "icon_sword", "score>=15"
	)
	_assert_eq(score_goal.progress_ratio({"score": 0}), 0.0, "score goal at 0 kills = 0.0")
	_assert_eq(score_goal.progress_ratio({"score": 5}), 5.0 / 15.0, "score goal at 1 kill = 1/3")
	_assert_eq(score_goal.progress_ratio({"score": 10}), 10.0 / 15.0, "score goal at 2 kills = 2/3")
	_assert_eq(score_goal.progress_ratio({"score": 15}), 1.0, "score goal at 3 kills = full")
	_assert_eq(score_goal.progress_ratio({"score": 25}), 1.0, "score goal clamps past target")
	# Score goal ignores inventory entirely.
	_assert_eq(
		score_goal.progress_ratio({"score": 5, "inventory": {"key": 99}}),
		5.0 / 15.0,
		"score goal ignores inventory"
	)
	# Missing score key = 0, no crash.
	_assert_eq(score_goal.progress_ratio({}), 0.0, "score goal with empty ctx = 0")

	# Regression: inventory-based collect goal still reads inventory.
	var inv_goal := GameGoal.new(
		GameGoal.KIND_COLLECT, 3, "Zbierz 3 klucze", "icon_key", "inventory.key>=3"
	)
	_assert_eq(inv_goal.progress_ratio({"inventory": {"key": 2}}), 2.0 / 3.0, "inventory goal reads inventory")
	_assert_eq(
		inv_goal.progress_ratio({"score": 99, "inventory": {"key": 1}}),
		1.0 / 3.0,
		"inventory goal ignores score"
	)

	return _build_result("GameGoal score-based progress_ratio")
