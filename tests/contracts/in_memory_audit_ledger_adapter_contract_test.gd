class_name InMemoryAuditLedgerAdapterContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var ledger := InMemoryAuditLedger.new().setup()

	# Empty ledger integrity should pass
	var empty_check := ledger.verify_integrity()
	_assert_true(empty_check.get("ok", false), "Empty ledger should pass integrity check")
	_assert_true(ledger.record_count() == 0, "Empty ledger should have 0 records")
	_assert_true(ledger.last_hash() == "", "Empty ledger should have empty last_hash")

	# Append first record (no previous hash)
	var r1 := AuditRecord.new(
		"rec-1", "AIAssistanceRequested", "evt-1", "kid-1",
		"2026-03-02T12:00:00Z", {"session_id": "sess-1"}, ""
	)
	_assert_true(ledger.append_record(r1), "First record should append successfully")
	_assert_true(ledger.record_count() == 1, "Ledger should have 1 record after first append")
	_assert_true(not ledger.last_hash().is_empty(), "last_hash should be non-empty after append")

	# Append second record chained to first
	var r2 := AuditRecord.new(
		"rec-2", "SafetyInterventionTriggered", "evt-2", "kid-1",
		"2026-03-02T12:01:00Z", {"decision_type": "BLOCK"}, ledger.last_hash()
	)
	_assert_true(ledger.append_record(r2), "Second record should append successfully")
	_assert_true(ledger.record_count() == 2, "Ledger should have 2 records")

	var wrong_chain := AuditRecord.new(
		"rec-bad-chain", "TestEvent", "evt-bad-chain", "kid-1",
		"2026-03-02T12:01:30Z", {}, "invalid-previous-hash"
	)
	_assert_true(
		not ledger.append_record(wrong_chain),
		"Record with mismatched previous_hash should be rejected"
	)

	var tampered_new := AuditRecord.new(
		"rec-bad-hash", "TestEvent", "evt-bad-hash", "kid-1",
		"2026-03-02T12:01:40Z", {}, ledger.last_hash()
	)
	tampered_new.payload["tampered"] = true
	_assert_true(
		not ledger.append_record(tampered_new),
		"Record whose payload no longer matches record_hash should be rejected"
	)

	# Append third record from different actor
	var r3 := AuditRecord.new(
		"rec-3", "WorldEdited", "evt-3", "parent-1",
		"2026-03-02T12:02:00Z", {"edit_type": "node_added"}, ledger.last_hash()
	)
	_assert_true(ledger.append_record(r3), "Third record should append successfully")

	# Hash chain integrity check
	var integrity := ledger.verify_integrity()
	_assert_true(integrity.get("ok", false), "3-record chain should pass integrity check")
	_assert_true(integrity.get("total_records", 0) == 3, "Integrity check should report 3 total records")
	_assert_true(integrity.get("last_valid_index", -1) == 2, "Last valid index should be 2")

	# Filter by actor_id
	var kid_records := ledger.get_records({"actor_id": "kid-1"})
	_assert_true(kid_records.size() == 2, "Should find 2 records for kid-1")

	var parent_records := ledger.get_records({"actor_id": "parent-1"})
	_assert_true(parent_records.size() == 1, "Should find 1 record for parent-1")

	# Filter by event_type
	var safety_records := ledger.get_records({"event_type": "SafetyInterventionTriggered"})
	_assert_true(safety_records.size() == 1, "Should find 1 SafetyIntervention record")

	# Filter by timestamp range
	var range_records := ledger.get_records({
		"from_iso": "2026-03-02T12:00:30Z",
		"to_iso": "2026-03-02T12:02:00Z"
	})
	_assert_true(range_records.size() == 1, "Timestamp range filter should return 1 record")

	# Filter with limit
	var limited := ledger.get_records({"limit": 1})
	_assert_true(limited.size() == 1, "Limit=1 should return only 1 record")

	# Null record rejected
	_assert_true(not ledger.append_record(null), "Null record should be rejected")

	# Empty ID rejected
	var bad_record := AuditRecord.new("", "Test", "e-bad", "actor", "2026-03-02T12:00:00Z")
	_assert_true(not ledger.append_record(bad_record), "Empty record_id should be rejected")

	# Tamper detection: corrupt a record hash and verify_integrity should fail
	var tamper_ledger := InMemoryAuditLedger.new().setup()
	var t1 := AuditRecord.new("t-1", "Test", "e-t1", "a", "2026-03-02T12:00:00Z", {}, "")
	tamper_ledger.append_record(t1)
	var t2 := AuditRecord.new("t-2", "Test", "e-t2", "a", "2026-03-02T12:01:00Z", {}, tamper_ledger.last_hash())
	tamper_ledger.append_record(t2)
	var t3 := AuditRecord.new("t-3", "Test", "e-t3", "a", "2026-03-02T12:02:00Z", {}, tamper_ledger.last_hash())
	tamper_ledger.append_record(t3)

	# Tamper with second record's payload
	t2.payload["injected"] = "tampered"
	var tamper_check := tamper_ledger.verify_integrity()
	_assert_true(not tamper_check.get("ok", true), "Tampered ledger should fail integrity check")
	_assert_true(tamper_check.get("last_valid_index", -1) == 0, "Tamper at index 1 should report last valid at 0")

	# from_dict should preserve stored hash to keep tamper detection meaningful.
	var serialized := t1.to_dict()
	serialized["payload"] = {"rewritten": "value"}
	var hydrated := AuditRecord.from_dict(serialized)
	_assert_true(
		not hydrated.verify(),
		"Hydrated record should fail verification when payload differs from stored hash"
	)

	return _build_result("InMemoryAuditLedgerAdapter")
