## System clock adapter for ClockPort.
## Provides wall-clock timestamps for audit trails and IDs.
class_name SystemClock
extends ClockPort


func now_iso() -> String:
	return Time.get_datetime_string_from_system(true, false)


func now_msec() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
