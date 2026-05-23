## Domain value object: the terminal state of a gameplay session.
## Produced by EvaluateGoalService when the active GameGoal's
## WinConditionInterpreter expression flips true, by a timeout, or by
## an explicit "back to landing" tap. Pure data, RefCounted.
class_name WinOutcome
extends RefCounted

const REASON_GOAL_MET := "goal_met"
const REASON_TIMEOUT := "timeout"
const REASON_ABANDONED := "abandoned"
const REASON_ERROR := "error"

var won: bool
var reason: String
var score: int
## Unix epoch seconds. Set by `mark_completed_now()` or the test fixture.
var completed_at: int


func _init(
	p_won: bool = false,
	p_reason: String = REASON_ABANDONED,
	p_score: int = 0,
	p_completed_at: int = 0,
) -> void:
	won = p_won
	reason = p_reason
	score = p_score
	completed_at = p_completed_at


## Stamp the outcome with the current wall-clock. Kept on the entity (vs
## a service) so tests can drive deterministic timestamps via _init.
func mark_completed_now() -> void:
	completed_at = int(Time.get_unix_time_from_system())


static func goal_met(score_value: int) -> WinOutcome:
	var w := WinOutcome.new(true, REASON_GOAL_MET, score_value)
	w.mark_completed_now()
	return w


static func timeout(score_value: int) -> WinOutcome:
	var w := WinOutcome.new(false, REASON_TIMEOUT, score_value)
	w.mark_completed_now()
	return w


static func abandoned(score_value: int) -> WinOutcome:
	var w := WinOutcome.new(false, REASON_ABANDONED, score_value)
	w.mark_completed_now()
	return w
