## HardwareTier - VS-016
## Detects and classifies hardware tier for performance profiling.
## 
## Tier 1: High-end (RTX 30/40, RX 6000+, 8+ cores, 16+ GB RAM)
## Tier 2: Mid-range (UHD/MX/Vega, 4-6 cores, 8-16 GB RAM)
## UNKNOWN: Everything else

class_name HardwareTier
extends Node

enum Tier { TIER_1, TIER_2, UNKNOWN }

var current_tier: Tier = Tier.UNKNOWN
var hardware_info: Dictionary = {}


func _ready() -> void:
	detect_tier()


## Detect hardware tier and store info
func detect_tier() -> Tier:
	hardware_info = _gather_info()
	current_tier = _classify(hardware_info)
	return current_tier


## Get current hardware tier
func get_current_tier() -> Tier:
	return current_tier


## Get detailed hardware information
func get_hardware_info() -> Dictionary:
	return hardware_info.duplicate(true)


## Gather hardware information from system APIs
func _gather_info() -> Dictionary:
	return {
		"os": OS.get_name(),
		"cpu_cores": OS.get_processor_count(),
		"cpu_name": _get_cpu_name(),
		"memory_mb": OS.get_static_memory_usage() / (1024 * 1024),
		"gpu_name": _get_gpu_name(),
		"gpu_vendor": _get_gpu_vendor(),
		"gpu_vram_mb": _get_gpu_vram(),
		"screen_resolution": DisplayServer.screen_get_size(),
		"screen_refresh": DisplayServer.screen_get_refresh_rate(),
	}


func _get_cpu_name() -> String:
	# Platform-specific implementation would go here
	# For now, return generic info
	return "Unknown"


func _get_gpu_name() -> String:
	if RenderingServer == null:
		return "Unknown"
	if not RenderingServer.has_method("get_video_adapter_name"):
		return "Unknown"
	return RenderingServer.get_video_adapter_name()


func _get_gpu_vendor() -> String:
	if RenderingServer == null:
		return "Unknown"
	if not RenderingServer.has_method("get_video_adapter_vendor"):
		return "Unknown"
	return RenderingServer.get_video_adapter_vendor()


func _get_gpu_vram() -> float:
	# Godot 4 exposes adapter identity but deliberately has no cross-platform
	# VRAM query. Calling a non-existent RenderingServer method made the entire
	# main scene fail to compile, leaving the Play shell blank. Keep the optional
	# telemetry field conservative until a platform adapter can provide it.
	return 0.0


## Classify hardware based on gathered info
func _classify(info: Dictionary) -> Tier:
	var gpu = info.get("gpu_name", "").to_lower()
	var cores = info.get("cpu_cores", 0)
	var memory = info.get("memory_mb", 0.0)
	
	# Tier 1: High-end
	if ((gpu.contains("rtx 30") or gpu.contains("rtx 40") or gpu.contains("rx 6") or 
		 gpu.contains("rx 7")) and cores >= 8 and memory >= 16000) or \
		(gpu.contains("gtx 16") and cores >= 6 and memory >= 12000):
		return Tier.TIER_1
	
	# Tier 2: Mid-range
	if (gpu.contains("uhd") or gpu.contains("mx") or gpu.contains("vega") or 
		gpu.contains("iris") or gpu.contains("adreno")) and cores >= 4 and memory >= 8000:
		return Tier.TIER_2
	
	return Tier.UNKNOWN
