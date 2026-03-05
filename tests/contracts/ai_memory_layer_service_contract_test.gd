class_name AIMemoryLayerServiceContractTest
extends PortContractTest


class MockModeration:
	extends ModerationPort

	func check_text(text: String, _age_band: AgeBand) -> ModerationResult:
		if text.to_lower().contains("unsafe"):
			var blocked := ModerationResult.new(ModerationResult.Verdict.BLOCK, "unsafe")
			blocked.safe_alternative = "Wybierz bezpieczniejszy opis."
			return blocked
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T14:30:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767421800000 + _tick


func run() -> Dictionary:
	_reset()

	var store := InMemoryAIMemoryStore.new()
	var service := AIMemoryLayerService.new().setup(store, MockModeration.new(), MockClock.new())

	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)

	_assert_true(
		service.record_turn("session-1", "project-1", kid, "Zbuduj farme z kurnikiem."),
		"record_turn should store safe kid memory entries"
	)
	_assert_true(
		service.record_turn("session-1", "project-1", kid, "unsafe plan z przemocą"),
		"record_turn should store blocked entries for auditability"
	)
	_assert_true(
		service.record_turn(
			"session-1",
			"project-1",
			parent,
			"Dla rodzica: podbij mnoznik ekonomii.",
			{"visibility": "parent_only"}
		),
		"record_turn should store parent-only notes"
	)
	_assert_true(
		service.record_turn("session-1", "project-1", kid, "Dodaj monety co 10 sekund."),
		"record_turn should append deterministic sequence numbers"
	)

	var summary := service.compact_project_history("session-1", "project-1")
	_assert_dictionary(summary, "compact_project_history should return summary dictionary")
	_assert_true(
		int(summary.get("safe_excerpt_count", 0)) == 2,
		"Compaction should keep only shared safe excerpts"
	)
	_assert_true(
		int(summary.get("blocked_count", 0)) == 1,
		"Compaction should track blocked entry references"
	)
	_assert_true(
		not str(summary.get("summary_text", "")).to_lower().contains("unsafe"),
		"Compaction summary should not leak blocked text"
	)

	var kid_context := service.build_retrieval_context("session-1", "project-1", kid, 10)
	_assert_true(
		str(kid_context.get("policy", "")) == "kid_safe",
		"Kid retrieval policy should be kid_safe"
	)
	var kid_entries: Array = kid_context.get("session_memory", [])
	_assert_true(
		kid_entries.size() == 2,
		"Kid context should exclude blocked and parent-only entries"
	)
	var kid_summary: Dictionary = kid_context.get("project_summary", {})
	_assert_true(
		not kid_summary.has("blocked_entry_refs"),
		"Kid summary should hide blocked entry references"
	)

	var parent_context := service.build_retrieval_context("session-1", "project-1", parent, 10)
	_assert_true(
		str(parent_context.get("policy", "")) == "parent_audit",
		"Parent retrieval policy should be parent_audit"
	)
	var parent_entries: Array = parent_context.get("session_memory", [])
	_assert_true(
		parent_entries.size() == 4,
		"Parent context should include all entries for audit"
	)
	var redacted_found := false
	var parent_only_found := false
	for raw in parent_entries:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		if str(entry.get("content", "")) == "[zablokowane]":
			redacted_found = true
		if str(entry.get("visibility", "")) == "parent_only":
			parent_only_found = true
	_assert_true(redacted_found, "Blocked entry should be redacted for parent retrieval")
	_assert_true(parent_only_found, "Parent retrieval should include parent_only notes")

	var parent_summary: Dictionary = parent_context.get("project_summary", {})
	_assert_true(
		parent_summary.has("blocked_entry_refs"),
		"Parent summary should expose blocked entry references for audit"
	)

	var second_parent_context := service.build_retrieval_context("session-1", "project-1", parent, 10)
	var seq_a := _extract_seq(parent_context.get("session_memory", []))
	var seq_b := _extract_seq(second_parent_context.get("session_memory", []))
	_assert_true(
		seq_a == seq_b,
		"Retrieval order should be deterministic across repeated reads"
	)

	return _build_result("AIMemoryLayerService")


func _extract_seq(entries: Array) -> Array:
	var seq: Array = []
	for raw in entries:
		if raw is Dictionary:
			seq.append(int((raw as Dictionary).get("seq", 0)))
	return seq
