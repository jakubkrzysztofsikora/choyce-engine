## Value object tracking session-based progression within a gameplay session.
## Captures collectibles, achievements, unlocks, and quest progress
## as an immutable snapshot that can be persisted and restored.
class_name ProgressState
extends RefCounted

var collectibles: Dictionary  # item_id: String -> count: int
var achievements: Array[String]
var unlocks: Array[String]
var quest_progress: Dictionary  # quest_id: String -> stage: int
var score: int


func _init() -> void:
	collectibles = {}
	achievements = []
	unlocks = []
	quest_progress = {}
	score = 0


func has_achievement(achievement_id: String) -> bool:
	return achievement_id in achievements


func is_quest_complete(quest_id: String, total_stages: int) -> bool:
	return quest_progress.get(quest_id, 0) >= total_stages
