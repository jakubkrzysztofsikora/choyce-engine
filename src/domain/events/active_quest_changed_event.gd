## Domain event: The player's active quest changed.
## Emitted by QuestLog.set_active_quest() when focus switches to a different quest.
class_name ActiveQuestChangedEvent
extends DomainEvent

var quest_id: String


func _init(p_quest_id: String = "", p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("ActiveQuestChanged", p_actor, p_timestamp)
	quest_id = p_quest_id
	payload = {"quest_id": quest_id}
