class_name AuditLedgerPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := AuditLedgerPort.new()

	_assert_has_method(port, "append_record")
	_assert_has_method(port, "get_records")
	_assert_has_method(port, "verify_integrity")
	_assert_has_method(port, "record_count")
	_assert_has_method(port, "last_hash")

	# Default returns
	var appended := port.append_record(AuditRecord.new("r-1", "TestEvent", "e-1", "actor-1", "2026-03-02T12:00:00Z"))
	_assert_true(not appended, "Default append_record should return false")

	var records := port.get_records()
	_assert_array(records, "AuditLedgerPort.get_records()")
	_assert_true(records.is_empty(), "Default get_records should return empty array")

	var integrity := port.verify_integrity()
	_assert_dictionary(integrity, "AuditLedgerPort.verify_integrity()")

	var count := port.record_count()
	_assert_true(count == 0, "Default record_count should return 0")

	var hash := port.last_hash()
	_assert_string(hash, "AuditLedgerPort.last_hash()")

	return _build_result("AuditLedgerPort")
