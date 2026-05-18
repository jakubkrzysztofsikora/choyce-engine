## Value object representing a single quest objective.
## Quests track progress toward a goal and grant rewards upon completion.
## Used by the quest system to guide children through structured play.
class_name Quest
extends RefCounted


enum Status {
	LOCKED,
	ACTIVE,
	COMPLETED,
	CLAIMED,
}

var quest_id: String
var title_pl: String
var description_pl: String
var objective_type: String  ## "collect", "reach", "score", "build"
var target_count: int
var current_count: int
var reward_score: int
var reward_unlocks: Array[String]  ## node_ids or area_ids
var status: Status


func _init(p_id: String = "") -> void:
	quest_id = p_id
	title_pl = ""
	description_pl = ""
	objective_type = "collect"
	target_count = 1
	current_count = 0
	reward_score = 0
	reward_unlocks = []
	status = Status.LOCKED


func is_complete() -> bool:
	return current_count >= target_count


func progress_pct() -> int:
	if target_count <= 0:
		return 0
	return mini(100, int(float(current_count) / float(target_count) * 100.0))


func advance(amount: int = 1) -> void:
	if status != Status.ACTIVE:
		return
	current_count = mini(target_count, current_count + amount)
	if is_complete():
		status = Status.COMPLETED


func can_claim() -> bool:
	return status == Status.COMPLETED


func claim() -> bool:
	if not can_claim():
		return false
	status = Status.CLAIMED
	return true
