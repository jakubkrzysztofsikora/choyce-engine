## ScreenshotCapture - VS-016
## Captures screenshots at defined capture points for visual acceptance evidence.
## 
## Usage:
##   Add as autoload or child of main scene. Connect screenshot_captured signal
##   to EvidenceManager. Trigger capture() at each capture point.

class_name ScreenshotCapture
extends Node

## Capture points for visual acceptance evidence
enum CapturePoint {
	LAUNCHER,
	SPAWN,
	GUIDE_INTERACTION,
	REGION_TRANSITION,
	COMBAT
}

signal screenshot_captured(capture_point: CapturePoint, image: Image, metadata: Dictionary)

## Configuration
@export var output_path: String = "user://evidence/visual/"
@export var capture_delay: float = 0.3

## Hardware tier reference (injected at runtime)
var _hardware_tier: int = 2  # Default to TIER_2


## Capture a screenshot at the specified capture point
## 
## Args:
##   capture_point: The CapturePoint enum value
##   custom_meta: Optional additional metadata to include
func capture(capture_point: CapturePoint, custom_meta: Dictionary = {}) -> void:
	var metadata = _build_metadata(capture_point, custom_meta)
	
	# Add hardware tier if available
	var hardware_node = get_node_or_null("/root/HardwareTier")
	if hardware_node and hardware_node.has_method("get_current_tier"):
		_hardware_tier = hardware_node.get_current_tier()
		metadata["hardware_tier"] = _hardware_tier
		if hardware_node.has_method("get_hardware_info"):
			metadata["hardware_info"] = hardware_node.get_hardware_info()
	
	# Delay and capture to allow UI to settle
	var timer = Timer.new()
	timer.wait_time = capture_delay
	timer.timeout.connect(_perform_capture.bind(metadata))
	add_child(timer)
	timer.start()


func _perform_capture(metadata: Dictionary) -> void:
	var viewport = get_viewport()
	if viewport == null:
		push_error("ScreenshotCapture: No viewport available")
		return
	
	var image = viewport.get_texture().get_image()
	if image == null:
		push_error("ScreenshotCapture: Failed to capture image")
		return
	
	# Generate file path
	var tier_str = "tier_%d" % (_hardware_tier + 1)
	var ts = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system())
	var date_str = "%04d-%02d-%02d" % [ts["year"], ts["month"], ts["day"]]
	var time_str = "%02d-%02d-%02d" % [ts["hour"], ts["min"], ts["sec"]]
	var point_str = _capture_point_to_string(metadata["capture_point"]).to_lower()
	
	var rel_path = "%s%s/%s/%s_%s" % [output_path, tier_str, date_str, time_str, point_str]
	var full_path = "user://%s" % rel_path
	var dir_path = full_path.get_base_dir()
	
	# Create directory
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Save PNG
	var save_err = image.save_png("%s.png" % full_path)
	if save_err == OK:
		# Save metadata JSON
		metadata["file_path"] = "%s.png" % full_path
		metadata["image_size"] = Vector2i(image.get_width(), image.get_height())
		
		var file = FileAccess.open("%s.json" % full_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(metadata, "\t"))
			file.close()
		
		screenshot_captured.emit(metadata["capture_point"], image, metadata)
		return
	else:
		push_error("ScreenshotCapture: Failed to save PNG: %s.png" % full_path)


## Build metadata dictionary for the screenshot
func _build_metadata(capture_point: CapturePoint, custom_meta: Dictionary) -> Dictionary:
	return {
		"capture_point": capture_point,
		"timestamp": Time.get_unix_time_from_system(),
		"timestamp_iso": Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system()),
		"resolution": DisplayServer.screen_get_size(),
		"custom": custom_meta
	}


## Convert CapturePoint enum to string
func _capture_point_to_string(capture_point: CapturePoint) -> String:
	match capture_point:
		CapturePoint.LAUNCHER: return "launcher"
		CapturePoint.SPAWN: return "spawn"
		CapturePoint.GUIDE_INTERACTION: return "guide_interaction"
		CapturePoint.REGION_TRANSITION: return "region_transition"
		CapturePoint.COMBAT: return "combat"
		_: return "unknown"
