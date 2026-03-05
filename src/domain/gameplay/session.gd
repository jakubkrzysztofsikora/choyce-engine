## Entity representing an active gameplay session.
## Sessions track mode (create, play, co-op), participating players,
## and session-scoped progression state.
class_name Session
extends RefCounted

enum SessionMode { CREATE, PLAY, CO_OP }

var session_id: String
var world_id: String
var mode: SessionMode
var player_ids: Array[String]
var progress: ProgressState
var started_at: String  # ISO 8601
var is_active: bool


func _init(p_id: String = "", p_world_id: String = "") -> void:
	session_id = p_id
	world_id = p_world_id
	mode = SessionMode.PLAY
	player_ids = []
	progress = ProgressState.new()
	started_at = ""
	is_active = false


func add_player(profile_id: String) -> void:
	if profile_id not in player_ids:
		player_ids.append(profile_id)


func is_co_op() -> bool:
	return mode == SessionMode.CO_OP or player_ids.size() > 1
