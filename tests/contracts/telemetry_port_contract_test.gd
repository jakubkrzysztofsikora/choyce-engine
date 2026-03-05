class_name TelemetryPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()
	var port := TelemetryPort.new()

	_assert_has_method(port, "emit_event")

	port.emit_event("world_opened", {"project_id": "proj-1"})
	_note_check()

	port.emit_event("", {})
	_note_check()

	return _build_result("TelemetryPort")
