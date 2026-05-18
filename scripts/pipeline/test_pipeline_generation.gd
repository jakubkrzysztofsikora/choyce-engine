extends SceneTree

# Simple mock pipeline script

const TrackerScn = preload("res://src/application/usability_telemetry_tracker.gd")

class MockLocalTelemetry extends TelemetryPort:
    # Duck typing TelemetryPort
    # We must match method signature.
    func emit_event(name: String, payload: Dictionary) -> void:
        _append_to_log(name, payload)
        
    func _append_to_log(name: String, payload: Dictionary) -> void:
        var event = {"event_name": name, "properties": payload, "timestamp": Time.get_datetime_string_from_system()}
        var line = JSON.stringify(event)
        
        # Ensure directory exists first
        var dir = DirAccess.open("user://")
        if not dir.dir_exists("pipeline_test"):
            dir.make_dir("pipeline_test")
            
        var file_path = "user://pipeline_test/session_logs.jsonl"
        var file
        if FileAccess.file_exists(file_path):
             file = FileAccess.open(file_path, FileAccess.READ_WRITE)
             file.seek_end()
        else:
             file = FileAccess.open(file_path, FileAccess.WRITE)
             
        if file:
            file.store_line(line)
            file.close()

class MockClock extends ClockPort:
    # Duck typing ClockPort
    var _ticks: int = 1000
    
    func now_msec() -> int:
        return _ticks
        
    func advance(ms: int) -> void:
        _ticks += ms
        
    func now_iso() -> String:
        return Time.get_datetime_string_from_system()
        
    func get_datetime_dict_from_system(_utc: bool = false) -> Dictionary:
        return {"year": 2026, "month": 3, "day": 6}

func _init() -> void:
    print("Initializing pipeline test...")
    var dir = DirAccess.open("user://")
    if dir.dir_exists("pipeline_test"):
        # Manual cleanup (recursive is annoying in GDScript 2, but let's assume flat)
        var subdir = DirAccess.open("user://pipeline_test")
        subdir.list_dir_begin()
        var file_name = subdir.get_next()
        while file_name != "":
            if not subdir.current_is_dir() and file_name.ends_with(".jsonl"):
                subdir.remove(file_name)
            file_name = subdir.get_next()
        dir.remove("pipeline_test")
        
    var telemetry = MockLocalTelemetry.new()
    var clock = MockClock.new()
    var tracker = TrackerScn.new(telemetry, clock)
    
    print("Generating logs via UsabilityTelemetryTracker...")
    # Session 1: Good session
    tracker.start_session("s-100", "6-8")
    clock.advance(5000)
    tracker.mark_first_fun() # 5s
    clock.advance(10000)
    tracker.mark_loop_complete() # 15s
    tracker.end_session(5.0) # Trust 5
    
    # Session 2: Bad session
    tracker.start_session("s-101", "6-8")
    clock.advance(120000) # 2 mins
    tracker.mark_first_fun() # 120s
    tracker.record_frustration("abandoned")
    tracker.end_session(1.0) # Trust 1
    
    var file_exists = FileAccess.file_exists("user://pipeline_test/session_logs.jsonl")
    if file_exists:
        print("[PASS] Log file generated at user://pipeline_test/session_logs.jsonl")
        print("Log contents:")
        var f = FileAccess.open("user://pipeline_test/session_logs.jsonl", FileAccess.READ)
        print(f.get_as_text())
        
        # Now invoke the reporting script logic?
        # Since running another script inside this one is tricky without quitting,
        # we will rely on bash script to chain them.
    else:
        print("[FAIL] Log file missing.")
        quit(1)
        
    quit(0)
