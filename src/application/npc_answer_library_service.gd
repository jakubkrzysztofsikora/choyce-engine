## Application service to load and persist dynamically generated NPC answers,
## allowing NPCs to grow a reusable library of answers over time.
class_name NPCAnswerLibraryService
extends RefCounted

const _LIBRARY_DIR := "user://npc_library"


## Load all ready answers for an NPC, combining static dialogs and persisted dynamic answers.
func load_library(npc_id: String, static_lines: Dictionary) -> Array[Dictionary]:
	var answers: Array[Dictionary] = []
	var index := 0

	# 1. Add static lines from config/JSON
	for key in static_lines.keys():
		var val: Variant = static_lines[key]
		if val is String:
			answers.append({
				"index": index,
				"text": val.strip_edges(),
				"source": "static",
				"type": key,
				"player_prompt": ""
			})
			index += 1
		elif val is Dictionary:
			# Handles complex structures like fart_reaction
			var dict_val: Dictionary = val
			var text: String = str(dict_val.get("line_pl", dict_val.get("text", ""))).strip_edges()
			if not text.is_empty():
				answers.append({
					"index": index,
					"text": text,
					"source": "static",
					"type": key,
					"player_prompt": ""
				})
				index += 1

	# 2. Add persisted dynamic lines
	var dynamic_list := _load_dynamic_answers(npc_id)
	for item in dynamic_list:
		var text: String = str(item.get("text", "")).strip_edges()
		if not text.is_empty():
			answers.append({
				"index": index,
				"text": text,
				"source": "dynamic",
				"type": "dynamic_reply",
				"player_prompt": str(item.get("player_prompt", ""))
			})
			index += 1

	return answers


## Append a new dynamically generated answer to the NPC's library and save to disk.
func save_new_answer(npc_id: String, text: String, player_text: String, emotion: String) -> void:
	var list := _load_dynamic_answers(npc_id)
	
	# Prevent duplicate saves of identical text
	for item in list:
		if str(item.get("text", "")).strip_edges() == text.strip_edges():
			return

	var new_entry := {
		"text": text.strip_edges(),
		"player_prompt": player_text.strip_edges(),
		"emotion": emotion,
		"timestamp_iso": Time.get_datetime_string_from_system(true)
	}
	list.append(new_entry)
	_save_dynamic_answers(npc_id, list)


func _load_dynamic_answers(npc_id: String) -> Array:
	var path := "%s/%s.json" % [_LIBRARY_DIR, npc_id]
	if not FileAccess.file_exists(path):
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) == OK and json.data is Array:
		return json.data

	return []


func _save_dynamic_answers(npc_id: String, list: Array) -> void:
	_ensure_library_dir()
	var path := "%s/%s.json" % [_LIBRARY_DIR, npc_id]
	var tmp_path := path + ".tmp"

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("NPCAnswerLibraryService: cannot open temp file for write: %s" % tmp_path)
		return

	file.store_string(JSON.stringify(list, "\t"))
	file.close()

	# Atomic swap
	var dir := DirAccess.open(_LIBRARY_DIR)
	if dir != null:
		if dir.file_exists(npc_id + ".json"):
			dir.remove(npc_id + ".json")
		dir.rename(npc_id + ".json.tmp", npc_id + ".json")


func _ensure_library_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_LIBRARY_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_LIBRARY_DIR))
