## Application service for deterministic AI memory orchestration.
## Maintains short-term session memory plus compacted long-term project summaries
## via an explicit outbound memory store port.
class_name AIMemoryLayerService
extends RefCounted

var _memory_store: AIMemoryStorePort
var _moderation: ModerationPort
var _clock: ClockPort


func setup(
	memory_store: AIMemoryStorePort,
	moderation: ModerationPort = null,
	clock: ClockPort = null
) -> AIMemoryLayerService:
	_memory_store = memory_store
	_moderation = moderation
	_clock = clock
	return self


func record_turn(
	session_id: String,
	project_id: String,
	actor: PlayerProfile,
	content: String,
	metadata: Dictionary = {}
) -> bool:
	if _memory_store == null:
		return false
	if session_id.is_empty() or project_id.is_empty() or actor == null:
		return false

	var existing := _memory_store.list_session_entries(session_id, 100000)
	var next_sequence := existing.size() + 1
	var trimmed_content := content.strip_edges()

	var blocked := bool(metadata.get("blocked", false))
	if _moderation != null and not blocked and not trimmed_content.is_empty():
		var check := _moderation.check_text(trimmed_content, actor.age_band)
		blocked = check.is_blocked()

	var entry := {
		"seq": next_sequence,
		"project_id": project_id,
		"actor_id": actor.profile_id,
		"actor_role": "parent" if actor.is_parent() else "kid",
		"visibility": str(metadata.get("visibility", "shared")),
		"content": trimmed_content,
		"content_hash": _hash_text(trimmed_content),
		"blocked": blocked,
		"created_at": _now_iso(),
		"tags": _normalize_tags(metadata.get("tags", [])),
	}
	return _memory_store.append_session_entry(session_id, entry)


func compact_project_history(session_id: String, project_id: String) -> Dictionary:
	if _memory_store == null:
		return {}

	var all_entries := _memory_store.list_session_entries(session_id, 100000)
	var safe_excerpts: Array[String] = []
	var blocked_refs: Array[String] = []

	for raw in all_entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if str(entry.get("project_id", "")) != project_id:
			continue

		var blocked := bool(entry.get("blocked", false))
		if blocked:
			blocked_refs.append(str(entry.get("content_hash", "")))
			continue

		var visibility := str(entry.get("visibility", "shared"))
		if visibility == "parent_only":
			# Parent-private notes are retained in session memory only.
			continue

		var excerpt := _safe_excerpt(str(entry.get("content", "")))
		if not excerpt.is_empty():
			safe_excerpts.append(excerpt)

	var excerpt_limit := mini(8, safe_excerpts.size())
	var used_excerpts := safe_excerpts.slice(safe_excerpts.size() - excerpt_limit, safe_excerpts.size())
	var summary_text := _build_summary_text(used_excerpts)

	var summary := {
		"project_id": project_id,
		"session_id": session_id,
		"summary_text": summary_text,
		"safe_excerpt_count": used_excerpts.size(),
		"blocked_entry_refs": blocked_refs,
		"blocked_count": blocked_refs.size(),
		"compacted_at": _now_iso(),
		"policy": "blocked_content_redacted",
		"version": int(_memory_store.load_project_summary(project_id).get("version", 0)) + 1,
	}
	_memory_store.save_project_summary(project_id, summary)
	return summary


func build_retrieval_context(
	session_id: String,
	project_id: String,
	actor: PlayerProfile,
	session_limit: int = 6
) -> Dictionary:
	if _memory_store == null or actor == null:
		return {
			"policy": "unavailable",
			"session_memory": [],
			"project_summary": {},
			"filtered_entries": 0,
		}

	var all_entries := _memory_store.list_session_entries(session_id, 100000)
	var filtered: Array = []
	var filtered_entries := 0

	for raw in all_entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if str(entry.get("project_id", "")) != project_id:
			continue

		var blocked := bool(entry.get("blocked", false))
		var visibility := str(entry.get("visibility", "shared"))
		var normalized := entry.duplicate(true)

		if actor.is_kid():
			if blocked or visibility == "parent_only":
				filtered_entries += 1
				continue
			filtered.append(normalized)
		else:
			if blocked:
				normalized["content"] = "[zablokowane]"
			filtered.append(normalized)

	_sort_entries(filtered)

	var cap := maxi(1, session_limit)
	var start := maxi(0, filtered.size() - cap)
	var session_memory := filtered.slice(start, filtered.size())

	var summary := _memory_store.load_project_summary(project_id)
	if summary.is_empty():
		summary = compact_project_history(session_id, project_id)
	if actor.is_kid():
		summary.erase("blocked_entry_refs")

	return {
		"policy": "kid_safe" if actor.is_kid() else "parent_audit",
		"session_memory": session_memory,
		"project_summary": summary,
		"filtered_entries": filtered_entries,
	}


func _sort_entries(entries: Array) -> void:
	entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("seq", 0)) < int(b.get("seq", 0))
	)


func _safe_excerpt(text: String) -> String:
	var normalized := text.strip_edges().replace("\n", " ")
	if normalized.length() <= 96:
		return normalized
	return "%s..." % normalized.substr(0, 96)


func _build_summary_text(excerpts: Array[String]) -> String:
	if excerpts.is_empty():
		return "Brak bezpiecznych wpisów pamięci projektu."
	return "Najważniejsze kroki: %s" % " | ".join(excerpts)


func _normalize_tags(raw_tags: Variant) -> Array[String]:
	var tags: Array[String] = []
	if not (raw_tags is Array):
		return tags
	for tag in raw_tags:
		var value := str(tag).strip_edges().to_lower()
		if not value.is_empty():
			tags.append(value)
	return tags


func _hash_text(text: String) -> String:
	return "h_%d" % absi(text.hash())


func _now_iso() -> String:
	if _clock == null:
		return ""
	return _clock.now_iso()
