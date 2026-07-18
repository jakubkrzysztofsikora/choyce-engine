## EvidenceManager - VS-016
## Coordinates collection of visual acceptance evidence and performance measurements.
## 
## Collects screenshots from all capture points, runs visual QA checks, and
## captures performance data. Saves all evidence to disk with proper structure.

class_name EvidenceManager
extends Node

signal evidence_collected
signal capture_complete

## Component references (injected or found in scene tree)
@export var screenshot_capture: ScreenshotCapture
@export var performance_monitor: PerformanceMonitor
@export var visual_qa: VisualQAChecker

## Configuration
@export var output_root: String = "user://evidence/"

## Evidence data
var evidence: Dictionary = {
	"screenshots": [],
	"performance": null,
	"visual_qa": [],
	"hardware_info": {},
	"timestamp": 0
}

## Track which capture points have been captured
var _captured_points: Array = []


func _ready() -> void:
	# Connect to screenshot capture signals if available
	if screenshot_capture != null:
		screenshot_capture.screenshot_captured.connect(_on_screenshot)


## Start collecting evidence from all capture points
func start_collection() -> void:
	_captured_points.clear()
	evidence = {
		"screenshots": [],
		"performance": null,
		"visual_qa": [],
		"hardware_info": {},
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Get hardware info
	var hardware_tier = get_node_or_null("/root/HardwareTier")
	if hardware_tier and hardware_tier.has_method("get_hardware_info"):
		evidence["hardware_info"] = hardware_tier.get_hardware_info()
	if hardware_tier and hardware_tier.has_method("get_current_tier"):
		evidence["hardware_tier"] = hardware_tier.get_current_tier()
	
	# Start performance monitoring if available
	if performance_monitor != null:
		performance_monitor.stop()  # Reset and restart
		performance_monitor._start_monitoring()
	
	# Trigger all screenshot captures
	if screenshot_capture != null:
		for point in range(5):  # All 5 CapturePoint values
			screenshot_capture.capture(point, {"evidence_session": evidence["timestamp"]})


## Handle screenshot captured from ScreenshotCapture
func _on_screenshot(capture_point: int, image: Image, metadata: Dictionary) -> void:
	if _captured_points.has(capture_point):
		return  # Already captured this point
	
	_captured_points.append(capture_point)
	
	# Store screenshot info
	evidence["screenshots"].append({
		"point": capture_point,
		"file_path": metadata.get("file_path", ""),
		"metadata": metadata
	})
	
	# Run QA check if visual_qa is available
	if visual_qa != null:
		var qa_result = visual_qa.check_screenshot(image, capture_point)
		evidence["visual_qa"].append(qa_result)
	
	# Check if all 5 points captured
	if _captured_points.size() >= 5:
		_capture_performance()


## Capture performance data and finalize evidence
func _capture_performance() -> void:
	if performance_monitor != null:
		evidence["performance"] = performance_monitor.get_stats()
		evidence["performance"]["distribution"] = performance_monitor.get_frame_distribution()
		
		# Add release recommendation
		evidence["performance"]["recommendation"] = _get_recommendation()
	
	# Save evidence
	_save_evidence()
	
	capture_complete.emit()
	evidence_collected.emit()


## Generate release recommendation based on performance data
func _get_recommendation() -> String:
	var tier = evidence["hardware_tier"] if "hardware_tier" in evidence else 2
	
	if "performance" not in evidence or evidence["performance"] == null:
		return "UNKNOWN"
	
	var perf = evidence["performance"]
	var avg_fps = perf["fps"]["avg"] if "fps" in perf and "avg" in perf["fps"] else 0
	var max_frame = perf["distribution"]["max"] if "distribution" in perf and "max" in perf["distribution"] else 999
	
	if tier == 0:  # TIER_1
		if avg_fps >= 60 and max_frame <= 16.67:
			return "RELEASE_READY_TIER_1"
		elif avg_fps >= 45:
			return "RELEASE_READY_TIER_1_LOWERED"
		elif avg_fps >= 30:
			return "BETA_TIER_1"
		else:
			return "ALPHA_TIER_1"
	else:  # TIER_2 or UNKNOWN
		if avg_fps >= 45 and max_frame <= 22.22:
			return "RELEASE_READY_TIER_2"
		elif avg_fps >= 30:
			return "RELEASE_READY_TIER_2_LOWERED"
		elif avg_fps >= 20:
			return "BETA_TIER_2"
		else:
			return "ALPHA_TIER_2"


## Save evidence to disk
func _save_evidence() -> void:
	var ts = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system())
	var dir = "%04d-%02d-%02d_%02d-%02d-%02d/" % [
		ts["year"], ts["month"], ts["day"], ts["hour"], ts["min"], ts["sec"]
	]
	var rel_path = "session_" + dir
	var full_path = "user://%s" % [output_root + rel_path]
	var dir_path = full_path.get_base_dir()
	
	# Create directory
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Save main evidence file
	var file = FileAccess.open("%sevidence.json" % full_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(evidence, "\t"))
		file.close()
		print("EvidenceManager: Saved evidence to %s" % full_path)
	else:
		push_error("EvidenceManager: Failed to save evidence file")


## Get current evidence status
func get_status() -> Dictionary:
	return {
		"captured_points": _captured_points.size(),
		"total_points": 5,
		"performance_monitor_active": performance_monitor != null,
		"screenshots": evidence["screenshots"].size()
	}
