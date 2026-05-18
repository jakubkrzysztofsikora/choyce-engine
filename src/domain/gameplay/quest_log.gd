## Aggregate managing a collection of quests for a player session.
## Tracks active quest, publishes domain events via DomainEventBus, and handles quest lifecycle.
## Signals have been removed (Phase 7c): all notifications go through event_bus.publish().
class_name QuestLog
extends RefCounted

var quests: Array = []
var active_quest_id: String = ""

## actor_id is stored so published events carry the player identity.
var _actor_id: String = ""
var _event_bus: DomainEventBus = null
var _warned_null_bus: bool = false


func setup(event_bus: DomainEventBus, actor_id: String = "") -> QuestLog:
	_event_bus = event_bus
	_actor_id = actor_id
	return self


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
	_emit(ActiveQuestChangedEvent.new(quest_id, _actor_id))
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
	_emit(QuestProgressedEvent.new(quest_id, quest.current_count, quest.target_count, _actor_id))

	if not was_complete and quest.is_complete():
		_emit(QuestCompletedEvent.new(quest_id, _actor_id))


func claim_quest(quest_id: String) -> bool:
	var quest = get_quest(quest_id)
	if quest == null:
		return false
	if not quest.claim():
		return false
	_emit(QuestClaimedEvent.new(quest_id, quest.reward_score, quest.reward_unlocks.duplicate(), _actor_id))
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


func _emit(event: DomainEvent) -> void:
	if _event_bus != null:
		_event_bus.emit(event)
	elif not _warned_null_bus:
		_warned_null_bus = true
		push_warning("QuestLog: event_bus not wired; event lost: %s" % event.event_type)
