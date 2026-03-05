class_name ParentAuditReadModelAdapterContractTest
extends PortContractTest


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T14:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767427200000 + _tick


func run() -> Dictionary:
	_reset()
	var ledger := InMemoryAuditLedger.new().setup()
	var clock := MockClock.new()
	var adapter := ParentAuditReadModelAdapter.new().setup(ledger, clock)

	# Register family link: parent-1 owns kid-1
	adapter.register_family_link("parent-1", "kid-1")

	# Feed domain events through update_from_event
	var safety_event := SafetyInterventionTriggeredEvent.new("dec-1", "kid-1", "2026-03-02T14:00:01Z")
	safety_event.decision_type = "BLOCK"
	safety_event.policy_rule = "MODERATION_BLOCK"
	safety_event.trigger_context = "unsafe prompt"
	safety_event.safe_alternative_offered = true
	adapter.update_from_event(safety_event)

	_assert_true(ledger.record_count() == 1, "First event should produce 1 audit record")

	var ai_event := AIAssistanceRequestedEvent.new("sess-1", "kid-1", "2026-03-02T14:00:02Z")
	ai_event.intent_summary = "Dodaj drzewo"
	adapter.update_from_event(ai_event)

	_assert_true(ledger.record_count() == 2, "Two events should produce 2 audit records")

	var parent_event := AIAssistanceAppliedEvent.new("action-1", "parent-1", "2026-03-02T14:00:03Z")
	parent_event.tool_invocations_count = 2
	parent_event.impact_level = "LOW"
	parent_event.was_parent_approved = true
	adapter.update_from_event(parent_event)

	_assert_true(ledger.record_count() == 3, "Three events should produce 3 audit records")

	# Hash chain should be intact
	var integrity := ledger.verify_integrity()
	_assert_true(integrity.get("ok", false), "Ledger should pass integrity after 3 events")

	# get_timeline for parent-1 should include kid-1 events via family link
	var timeline := adapter.get_timeline("parent-1")
	_assert_true(timeline.size() == 3, "Parent timeline should include own + kid events (3 total)")

	# get_timeline for kid-1 should only show kid events (no family link the other way)
	var kid_timeline := adapter.get_timeline("kid-1")
	_assert_true(kid_timeline.size() == 2, "Kid timeline should show only kid-1 events (2)")

	# get_timeline with timestamp filter
	var filtered := adapter.get_timeline("parent-1", "2026-03-02T14:00:02Z", "2026-03-02T14:00:03Z")
	_assert_true(filtered.size() == 1, "Filtered timeline should return 1 event in range")

	# get_timeline with limit
	var limited := adapter.get_timeline("parent-1", "", "", 2)
	_assert_true(limited.size() == 2, "Limited timeline should return max 2 entries")

	# get_interventions for parent-1 should find kid's safety event
	var interventions := adapter.get_interventions("parent-1")
	_assert_true(interventions.size() == 1, "Parent should see 1 safety intervention from kid")
	if interventions.size() > 0 and interventions[0] is AuditRecord:
		var intervention: AuditRecord = interventions[0]
		_assert_true(
			intervention.event_type == "SafetyInterventionTriggered",
			"Intervention event_type should be SafetyInterventionTriggered"
		)
		_assert_true(
			intervention.actor_id == "kid-1",
			"Intervention actor should be kid-1"
		)

	# get_interventions for unlinked parent should return empty
	var other_interventions := adapter.get_interventions("parent-2")
	_assert_true(other_interventions.is_empty(), "Unlinked parent should see no interventions")

	# Null event should not crash
	adapter.update_from_event(null)
	_assert_true(ledger.record_count() == 3, "Null event should not add records")

	var unstamped_event := AIAssistanceRequestedEvent.new("sess-2", "kid-1")
	adapter.update_from_event(unstamped_event)
	var unstamped_record: AuditRecord = null
	for candidate in ledger.get_records({"event_type": "AIAssistanceRequested", "limit": 10}):
		if candidate is AuditRecord and (candidate as AuditRecord).event_id == unstamped_event.event_id:
			unstamped_record = candidate
			break
	_assert_true(unstamped_record != null, "Unstamped events should still be persisted")
	if unstamped_record != null:
		_assert_true(
			not unstamped_record.timestamp.strip_edges().is_empty(),
			"Adapter should stamp missing event timestamps using ClockPort"
		)

	# AuditRecord payload should contain event-specific fields
	var records := ledger.get_records({"event_type": "SafetyInterventionTriggered"})
	if records.size() > 0 and records[0] is AuditRecord:
		var rec: AuditRecord = records[0]
		_assert_true(
			rec.payload.get("decision_type", "") == "BLOCK",
			"Safety record payload should contain decision_type=BLOCK"
		)
		_assert_true(
			rec.payload.get("policy_rule", "") == "MODERATION_BLOCK",
			"Safety record payload should contain policy_rule"
		)

	return _build_result("ParentAuditReadModelAdapter")
