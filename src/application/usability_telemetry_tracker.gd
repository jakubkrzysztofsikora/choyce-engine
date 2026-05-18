class_name UsabilityTelemetryTracker
extends RefCounted

## Application service for capturing usability metrics during gameplay sessions.
## Tracks time-to-first-fun, loop completion, and frustration signals.

const EVENT_Start := "usability_session_start"
const EVENT_FirstFun := "usability_first_fun"
const EVENT_LoopComplete := "usability_loop_complete"
const EVENT_Rescue := "usability_adult_rescue"
const EVENT_Frustration := "usability_frustration"
const EVENT_End := "usability_session_end"

var _telemetry: TelemetryPort
var _clock: ClockPort

var _current_session_id: String = ""
var _session_start_ms: int = 0
var _first_fun_ms: int = 0
var _loop_start_ms: int = 0
var _rescue_count: int = 0
var _frustration_stats: Dictionary = {"rage_taps": 0, "abandoned": false}

func _init(telemetry: TelemetryPort, clock: ClockPort) -> void:
	_telemetry = telemetry
	_clock = clock

func start_session(session_id: String, age_band: String) -> void:
	_current_session_id = session_id
	_session_start_ms = _clock.now_msec()
	_first_fun_ms = 0
	_loop_start_ms = _session_start_ms
	_rescue_count = 0
	_frustration_stats = {"rage_taps": 0, "abandoned": false}
	
	_telemetry.emit_event(EVENT_Start, {
		"session_id": session_id,
		"age_band": age_band,
		"timestamp_utc": _clock.now_iso()
	})

func mark_first_fun() -> void:
	if _current_session_id.is_empty() or _first_fun_ms > 0:
		return
		
	var now := _clock.now_msec()
	_first_fun_ms = now
	var duration_sec := float(now - _session_start_ms) / 1000.0
	
	_telemetry.emit_event(EVENT_FirstFun, {
		"session_id": _current_session_id,
		"duration_seconds": duration_sec
	})

func mark_loop_complete() -> void:
	if _current_session_id.is_empty():
		return
		
	var now := _clock.now_msec()
	var duration_sec := float(now - _loop_start_ms) / 1000.0
	# Reset loop start for next loop? Or just track first loop?
	# Typically "First Playable Loop" is the metric.
	
	_telemetry.emit_event(EVENT_LoopComplete, {
		"session_id": _current_session_id,
		"duration_seconds": duration_sec
	})

func record_adult_rescue() -> void:
	if _current_session_id.is_empty():
		return
	_rescue_count += 1
	_telemetry.emit_event(EVENT_Rescue, {
		"session_id": _current_session_id,
		"count": _rescue_count
	})

func record_frustration(type: String) -> void:
	if _current_session_id.is_empty():
		return
		
	if type == "rage_tap":
		_frustration_stats["rage_taps"] = int(_frustration_stats.get("rage_taps", 0)) + 1
	elif type == "abandoned":
		_frustration_stats["abandoned"] = true
		
	_telemetry.emit_event(EVENT_Frustration, {
		"session_id": _current_session_id,
		"type": type,
		"stats": _frustration_stats
	})

func end_session(trust_score: float = 0.0) -> void:
	if _current_session_id.is_empty():
		return
		
	var now := _clock.now_msec()
	var duration_sec := float(now - _session_start_ms) / 1000.0
	var first_fun_sec := float(_first_fun_ms - _session_start_ms) / 1000.0 if _first_fun_ms > 0 else 0.0
	
	_telemetry.emit_event(EVENT_End, {
		"session_id": _current_session_id,
		"duration_seconds": duration_sec,
		"time_to_first_fun_seconds": first_fun_sec,
		"adult_rescue_count": _rescue_count,
		"frustration": _frustration_stats,
		"parent_trust_score": trust_score
	})
	
	_current_session_id = ""
