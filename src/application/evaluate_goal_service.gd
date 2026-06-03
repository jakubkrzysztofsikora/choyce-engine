## Application service: turns a GameGoal + session context into a WinOutcome.
##
## Bridges the parsed `WinConditionInterpreter` DSL with the WinOutcome
## value object the gameplay runtime consumes to fire SessionEndedEvent.
## Stays pure RefCounted so contract tests can drive it deterministically.
##
## Usage:
##   var svc := EvaluateGoalService.new()
##   var outcome := svc.evaluate(goal, {"inventory": {"key": 3}}, current_score)
##   if outcome.won: emit SessionEndedEvent
##
## Lose conditions (lives==0, timeout) are tracked by gameplay_runtime and
## passed in via `forced_lose_reason` — keeps this service pure-eval.
class_name EvaluateGoalService
extends RefCounted

const _INTERPRETER_CACHE_KEY := "_cached_interp"

var _interpreter_cache: Dictionary = {}


## Evaluate the goal against a context dict. Returns:
##   - WinOutcome.goal_met(score) if the goal's win_condition evaluates true
##   - WinOutcome.timeout(score) if forced_lose_reason == REASON_TIMEOUT
##   - WinOutcome.abandoned(score) if forced_lose_reason == REASON_ABANDONED
##   - null if the goal is still in progress (no terminal state)
##
## Fail-closed: malformed win_condition never produces a win.
func evaluate(
	goal: GameGoal,
	ctx: Dictionary,
	score: int = 0,
	forced_lose_reason: String = ""
) -> WinOutcome:
	if forced_lose_reason == WinOutcome.REASON_TIMEOUT:
		return WinOutcome.timeout(score)
	if forced_lose_reason == WinOutcome.REASON_ABANDONED:
		return WinOutcome.abandoned(score)
	if forced_lose_reason == WinOutcome.REASON_ERROR:
		var w := WinOutcome.new(false, WinOutcome.REASON_ERROR, score)
		w.mark_completed_now()
		return w

	if goal == null or goal.win_condition.strip_edges().is_empty():
		return null

	var interp := _get_or_parse(goal)
	if interp == null:
		return null  # parse failure → fail-closed, treat as in-progress

	if interp.evaluate(ctx):
		return WinOutcome.goal_met(score)

	return null


## Compute 0..1 progress for the Quest HUD progress bar.
## Delegates to GameGoal so callers don't need to know the kind logic.
func progress_ratio(goal: GameGoal, ctx: Dictionary) -> float:
	if goal == null:
		return 0.0
	return goal.progress_ratio(ctx)


func _get_or_parse(goal: GameGoal) -> WinConditionInterpreter:
	var key := goal.win_condition
	if _interpreter_cache.has(key):
		return _interpreter_cache[key]

	var interp := WinConditionInterpreter.new()
	if not interp.parse(key):
		_interpreter_cache[key] = null
		return null

	_interpreter_cache[key] = interp
	return interp
