## Aggregate managing a collection of quests for a player session.
## Tracks active quest, emits progress signals, and handles quest lifecycle.
class_name QuestLog
extends RefCounted


signal quest_progressed(quest_id: String, current_count: int, target_count: int)
signal quest_completed(quest_id: String)
signal quest_claimed(quest_id: String, reward_score: int, reward_unlocks: Array)
signal active_quest_changed(quest_id: String)

var quests: Array = []
var active_quest_id: String = ""


func add_quest(quest) -> void:
	quests.append(quest)


func get_quest(quest_id: String):
	for quest in quests:
		if quest.quest_id == quest_id:
			return quest
	return null


func set_active_quest(quest_id: String) -> bool:
	var quest = get_quest(quest_id)
	if quest == null:
		return false
	if quest.status == 0:  # LOCKED
		quest.status = 1  # ACTIVE
	active_quest_id = quest_id
	active_quest_changed.emit(quest_id)
	return true


func get_active_quest():
	return get_quest(active_quest_id)


func progress_quest(quest_id: String, amount: int = 1) -> void:
	var quest = get_quest(quest_id)
	if quest == null:
		return
	if quest.status != 1:  # ACTIVE
		return

	var was_complete = quest.is_complete()
	quest.advance(amount)
	quest_progressed.emit(quest_id, quest.current_count, quest.target_count)

	if not was_complete and quest.is_complete():
		quest_completed.emit(quest_id)


func claim_quest(quest_id: String) -> bool:
	var quest = get_quest(quest_id)
	if quest == null:
		return false
	if not quest.claim():
		return false
	quest_claimed.emit(quest_id, quest.reward_score, quest.reward_unlocks.duplicate())
	return true


func get_completed_quests() -> Array:
	var result: Array = []
	for quest in quests:
		if quest.status == 2 or quest.status == 3:  # COMPLETED or CLAIMED
			result.append(quest)
	return result


func get_available_quests() -> Array:
	var result: Array = []
	for quest in quests:
		if quest.status == 0 or quest.status == 1:  # LOCKED or ACTIVE
			result.append(quest)
	return result


func unlock_quest(quest_id: String) -> bool:
	var quest = get_quest(quest_id)
	if quest == null:
		return false
	if quest.status != 0:  # LOCKED
		return false
	quest.status = 1  # ACTIVE
	return true


func reset_all() -> void:
	for quest in quests:
		quest.current_count = 0
		quest.status = 0  # LOCKED
	active_quest_id = ""
