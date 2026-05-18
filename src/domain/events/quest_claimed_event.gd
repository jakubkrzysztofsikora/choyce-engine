## Domain event: Quest reward claimed by a player.
## Emitted by QuestLog.claim_quest() after status transitions to CLAIMED.
class_name QuestClaimedEvent
extends DomainEvent

var quest_id: String
var reward_score: int
var reward_unlocks: Array


func _init(p_quest_id: String = "", p_score: int = 0, p_unlocks: Array = [], p_actor: String = "", p_timestamp: String = "") -> void:
	super._init("QuestClaimed", p_actor, p_timestamp)
	quest_id = p_quest_id
	reward_score = p_score
	reward_unlocks = p_unlocks.duplicate()
	payload = {
		"quest_id": quest_id,
		"reward_score": reward_score,
		"reward_unlocks": reward_unlocks,
	}
