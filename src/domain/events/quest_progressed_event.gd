## Domain event: Quest progress advanced for a player.
## Emitted when QuestLog.progress_quest() increments a quest's counter.
class_name QuestProgressedEvent
extends DomainEvent

var quest_id: String
var current_count: int
var target_count: int


func _init(p_quest_id: String = "", p_current: int = 0, p_target: int = 0, p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("QuestProgressed", p_actor, p_timestamp)
	quest_id = p_quest_id
	current_count = p_current
	target_count = p_target
	payload = {
		"quest_id": quest_id,
		"current_count": current_count,
		"target_count": target_count,
	}
