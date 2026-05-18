## Domain event: Quest completed (all objectives met) for a player.
## Emitted by QuestLog.progress_quest() when a quest crosses the completion threshold.
class_name QuestCompletedEvent
extends DomainEvent

var quest_id: String


func _init(p_quest_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("QuestCompleted", p_actor, p_timestamp)
	quest_id = p_quest_id
	payload = {"quest_id": quest_id}
