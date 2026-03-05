## In-memory event-sourced action log for undo/redo and safe checkpoints.
## Stores world-edit and AI-patch entries per stream and reconstructs
## current state through replay of logged entries.
class_name EventSourcedActionLog
extends RefCounted

const DELETE_SENTINEL := "__deleted__"

var _streams: Dictionary = {}


func record_world_edit(event: WorldEditedEvent) -> bool:
	if event == null or event.world_id.strip_edges().is_empty():
		return false

	var entry := {
		"entry_id": event.event_id,
		"event_type": event.event_type,
		"timestamp": event.timestamp,
		"actor_id": event.actor_id,
		"target_id": event.target_node_id,
		"previous_state": _clone_variant(event.previous_state),
		"new_state": _clone_variant(event.new_state),
	}
	return _append_entry(event.world_id, entry)


func record_ai_patch(
	stream_id: String,
	new_state: Dictionary,
	previous_state: Dictionary = {},
	actor_id: String = "",
	timestamp: String = ""
) -> bool:
	var normalized_stream := stream_id.strip_edges()
	if normalized_stream.is_empty():
		return false

	var entry := {
		"entry_id": "ai_%s_%d" % [normalized_stream, _entry_count(normalized_stream) + 1],
		"event_type": "AIAssistanceApplied",
		"timestamp": timestamp,
		"actor_id": actor_id,
		"target_id": "",
		"previous_state": _clone_variant(previous_state),
		"new_state": _clone_variant(new_state),
	}
	return _append_entry(normalized_stream, entry)


func undo(stream_id: String) -> Dictionary:
	var stream_key := stream_id.strip_edges()
	if stream_key.is_empty() or not _streams.has(stream_key):
		return {"ok": false, "state": {}, "cursor": 0}

	var stream: Dictionary = _streams[stream_key]
	var cursor := int(stream.get("cursor", 0))
	if cursor <= 0:
		return {"ok": false, "state": _replay_state(stream, 0), "cursor": 0}

	cursor -= 1
	stream["cursor"] = cursor
	_streams[stream_key] = stream
	return {
		"ok": true,
		"state": _replay_state(stream, cursor),
		"cursor": cursor,
	}


func redo(stream_id: String) -> Dictionary:
	var stream_key := stream_id.strip_edges()
	if stream_key.is_empty() or not _streams.has(stream_key):
		return {"ok": false, "state": {}, "cursor": 0}

	var stream: Dictionary = _streams[stream_key]
	var entries: Array = stream.get("entries", [])
	var cursor := int(stream.get("cursor", 0))
	if cursor >= entries.size():
		return {"ok": false, "state": _replay_state(stream, cursor), "cursor": cursor}

	cursor += 1
	stream["cursor"] = cursor
	_streams[stream_key] = stream
	return {
		"ok": true,
		"state": _replay_state(stream, cursor),
		"cursor": cursor,
	}


func create_checkpoint(stream_id: String, label: String = "", checkpoint_id: String = "") -> String:
	var stream_key := stream_id.strip_edges()
	if stream_key.is_empty():
		return ""

	var stream: Dictionary = _ensure_stream(stream_key)
	var cursor := int(stream.get("cursor", 0))
	var state := _replay_state(stream, cursor)

	var cp_id := checkpoint_id.strip_edges()
	if cp_id.is_empty():
		cp_id = "%s_cp_%d" % [stream_key, cursor]

	var checkpoints: Dictionary = stream.get("checkpoints", {})
	checkpoints[cp_id] = {
		"label": label,
		"cursor": cursor,
		"state": _clone_variant(state),
	}
	stream["checkpoints"] = checkpoints

	var order: Array = stream.get("checkpoint_order", [])
	if not order.has(cp_id):
		order.append(cp_id)
		stream["checkpoint_order"] = order

	_streams[stream_key] = stream
	return cp_id


func restore_checkpoint(stream_id: String, checkpoint_id: String) -> Dictionary:
	var stream_key := stream_id.strip_edges()
	var cp_key := checkpoint_id.strip_edges()
	if stream_key.is_empty() or cp_key.is_empty() or not _streams.has(stream_key):
		return {"ok": false, "state": {}, "cursor": 0}

	var stream: Dictionary = _streams[stream_key]
	var checkpoints: Dictionary = stream.get("checkpoints", {})
	if not checkpoints.has(cp_key):
		return {"ok": false, "state": _replay_state(stream, int(stream.get("cursor", 0))), "cursor": int(stream.get("cursor", 0))}

	var checkpoint: Dictionary = checkpoints[cp_key]
	var cursor := int(checkpoint.get("cursor", 0))
	stream["cursor"] = cursor
	_streams[stream_key] = stream
	return {
		"ok": true,
		"state": _clone_variant(checkpoint.get("state", {})),
		"cursor": cursor,
		"checkpoint_id": cp_key,
	}


func get_current_state(stream_id: String) -> Dictionary:
	var stream_key := stream_id.strip_edges()
	if stream_key.is_empty() or not _streams.has(stream_key):
		return {}
	var stream: Dictionary = _streams[stream_key]
	var cursor := int(stream.get("cursor", 0))
	return _replay_state(stream, cursor)


func get_entry_count(stream_id: String) -> int:
	return _entry_count(stream_id.strip_edges())


func get_checkpoint_ids(stream_id: String) -> Array[String]:
	var stream_key := stream_id.strip_edges()
	var ids: Array[String] = []
	if stream_key.is_empty() or not _streams.has(stream_key):
		return ids
	var stream: Dictionary = _streams[stream_key]
	var order: Array = stream.get("checkpoint_order", [])
	for item in order:
		ids.append(str(item))
	return ids


func _append_entry(stream_id: String, entry: Dictionary) -> bool:
	var stream: Dictionary = _ensure_stream(stream_id)
	var entries: Array = stream.get("entries", [])
	var cursor := int(stream.get("cursor", 0))

	# If a new entry is appended after undo, trim abandoned redo branch.
	if cursor < entries.size():
		entries = entries.slice(0, cursor)

	entries.append(_clone_variant(entry))
	cursor = entries.size()
	stream["entries"] = entries
	stream["cursor"] = cursor
	_streams[stream_id] = stream
	return true


func _ensure_stream(stream_id: String) -> Dictionary:
	if not _streams.has(stream_id):
		_streams[stream_id] = {
			"entries": [],
			"cursor": 0,
			"checkpoints": {},
			"checkpoint_order": [],
		}
	return _streams[stream_id]


func _entry_count(stream_id: String) -> int:
	if stream_id.is_empty() or not _streams.has(stream_id):
		return 0
	var stream: Dictionary = _streams[stream_id]
	var entries: Array = stream.get("entries", [])
	return entries.size()


func _replay_state(stream: Dictionary, cursor: int) -> Dictionary:
	var checkpoint := _find_base_checkpoint(stream, cursor)
	var state: Dictionary = _clone_variant(checkpoint.get("state", {}))
	var start_index := int(checkpoint.get("cursor", 0))
	var entries: Array = stream.get("entries", [])
	var end_index := mini(cursor, entries.size())

	for i in range(start_index, end_index):
		var entry: Dictionary = entries[i]
		var patch: Dictionary = entry.get("new_state", {})
		_apply_patch(state, patch)

	return state


func _find_base_checkpoint(stream: Dictionary, cursor: int) -> Dictionary:
	var checkpoints: Dictionary = stream.get("checkpoints", {})
	var best_cursor := -1
	var best_checkpoint: Dictionary = {"cursor": 0, "state": {}}

	for checkpoint_id in checkpoints.keys():
		var checkpoint_value: Dictionary = checkpoints[checkpoint_id]
		var cp_cursor := int(checkpoint_value.get("cursor", 0))
		if cp_cursor <= cursor and cp_cursor >= best_cursor:
			best_cursor = cp_cursor
			best_checkpoint = checkpoint_value

	return best_checkpoint


func _apply_patch(state: Dictionary, patch: Dictionary) -> void:
	for key in patch.keys():
		var value: Variant = patch[key]
		if value is String and value == DELETE_SENTINEL:
			state.erase(key)
			continue

		if value is Dictionary and state.get(key, null) is Dictionary:
			var merged: Dictionary = _clone_variant(state[key])
			_deep_merge_dict(merged, value)
			state[key] = merged
			continue

		state[key] = _clone_variant(value)


func _deep_merge_dict(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		var source_value: Variant = source[key]
		if source_value is String and source_value == DELETE_SENTINEL:
			target.erase(key)
		elif source_value is Dictionary and target.get(key, null) is Dictionary:
			var nested: Dictionary = target[key]
			_deep_merge_dict(nested, source_value)
			target[key] = nested
		else:
			target[key] = _clone_variant(source_value)


func _clone_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
