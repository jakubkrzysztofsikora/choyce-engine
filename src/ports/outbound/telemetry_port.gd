## Outbound port contract for telemetry emission.
## Analytics implementations must remain child-safe and privacy-preserving.
class_name TelemetryPort
extends RefCounted


func emit_event(event_name: String, properties: Dictionary) -> void:
	push_error("TelemetryPort.emit_event() not implemented")
