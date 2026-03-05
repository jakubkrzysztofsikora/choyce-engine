## Outbound port contract for time access.
## Keeps deterministic time behavior testable through adapter substitution.
class_name ClockPort
extends RefCounted


func now_iso() -> String:
	push_error("ClockPort.now_iso() not implemented")
	return ""


func now_msec() -> int:
	push_error("ClockPort.now_msec() not implemented")
	return 0
