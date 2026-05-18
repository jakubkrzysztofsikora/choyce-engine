extends ApplicationTest

## Testing UsabilityTelemetryTracker
## Since UsabilityTelemetryTracker is `class_name` (I think I added it), I can use it.
## Wait, I added `class_name UsabilityTelemetryTracker` in step 1.
## But script class cache might not be updated headlessly unless I run editor.
## So using preload is safer.

const TrackerScn = preload("res://src/application/usability_telemetry_tracker.gd")
const TelemetryPortScn = preload("res://src/ports/outbound/telemetry_port.gd")
const ClockPortScn = preload("res://src/ports/outbound/clock_port.gd")

class MockTelemetry extends TelemetryPortScn:
	var last_event: String = ""
	var last_payload: Dictionary = {}
	
	func emit_event(name: String, payload: Dictionary) -> void:
		last_event = name
		last_payload = payload

class MockClock extends ClockPortScn:
	var _ticks: int = 1000
	
	func now_msec() -> int:
		return _ticks
		
	func advance(ms: int) -> void:
		_ticks += ms
		
	func now_iso() -> String:
		return "2026-03-06T12:00:00Z"

func run() -> Dictionary:
	_checks_run = 0
	_failures = []
	
	_test_tracking_flow()
	
	return _build_result("UsabilityTelemetryTracker")

func _test_tracking_flow() -> void:
	var mock_telemetry = MockTelemetry.new()
	var mock_clock = MockClock.new()
	
	var tracker = TrackerScn.new(mock_telemetry, mock_clock)
	# Casting in test logic not needed if arguments match.
	
	# Test session start
	tracker.start_session("s-1", "6-8")
	_assert_eq(mock_telemetry.last_event, "usability_session_start", "Session start event")
	
	# Test first fun
	mock_clock.advance(5000)
	tracker.mark_first_fun()
	_assert_eq(mock_telemetry.last_event, "usability_first_fun", "First fun event")
	
	var duration: float = float(mock_telemetry.last_payload.get("duration_seconds", 0.0))
	_assert_true(abs(duration - 5.0) < 0.001, "First fun duration 5s")
	
	# Test loop complete
	mock_clock.advance(10000)
	tracker.mark_loop_complete()
	
	_assert_eq(mock_telemetry.last_event, "usability_loop_complete", "Loop complete event")
	
	var loop_duration: float = float(mock_telemetry.last_payload.get("duration_seconds", 0.0))
	# Loop starts at session start (for now)
	_assert_true(abs(loop_duration - 15.0) < 0.001, "Loop duration 15s")
