## Domain event: Player progression changes during gameplay session.
## Emitted when collectibles, achievements, unlocks, or quest progress change.
## Used for audit trail, telemetry, and parent timeline visibility.
class_name SessionProgressUpdatedEvent
extends DomainEvent


var session_id: String
var world_id: String
var profile_id: String
var progress: ProgressState
var changes: Dictionary  # What changed: { "collectible_id": {"before": 5, "after": 7}, ... }


func _init(p_session_id: String, p_world_id: String, p_profile_id: String, p_progress: ProgressState, p_changes: Dictionary = {}) -> void:
	super._init()
	session_id = p_session_id
	world_id = p_world_id
	profile_id = p_profile_id
	progress = p_progress
	changes = p_changes
