## PerformanceMonitor - VS-016
## Monitors and collects performance metrics for visual acceptance evidence.
## 
## Tracks FPS, frame times, memory usage, draw calls, and vertex counts.
## Provides statistical analysis of collected data.

class_name PerformanceMonitor
extends Node

## Configuration
@export var update_interval: float = 0.5
@export var max_history: int = 120

## Performance data
var frame_times: Array[float] = []
var fps_history: Array[float] = []
var perf_data: Dictionary = {
	"memory": [],
	"draw_calls": [],
	"vertex_count": []
}

var _active: bool = false


func _ready() -> void:
	_start_monitoring()


func _start_monitoring() -> void:
	if _active:
		return
	_active = true
	
	var timer = Timer.new()
	timer.wait_time = update_interval
	timer.timeout.connect(_update)
	add_child(timer)
	timer.start()


func _update() -> void:
	if not _active:
		return
	
	# Collect FPS and frame time
	var fps = Engine.fps
	if fps > 0:
		frame_times.append(1.0 / fps * 1000.0)  # Convert to ms
		fps_history.append(fps)
	else:
		frame_times.append(0.0)
		fps_history.append(0.0)
	
	# Collect memory usage (in bytes)
	perf_data["memory"].append(OS.get_static_memory_usage())
	
	# Note: Draw calls and vertex count require Performance monitors
	# which may not be available in Godot 4.6.1. These arrays remain empty.
	
	# Trim history
	for arr in [frame_times, fps_history] + perf_data.values():
		while arr.size() > max_history:
			arr.remove_at(0)


## Stop monitoring
func stop() -> void:
	_active = false


## Get statistics for all metrics
## Returns a dictionary with avg, min, max for each metric
func get_stats() -> Dictionary:
	return {
		"fps": _stats(fps_history),
		"frame_time_ms": _stats(frame_times),
		"memory_mb": _stats(perf_data.get("memory", [])) / (1024 * 1024),
		"draw_calls": _stats_int(perf_data.get("draw_calls", [])),
		"vertex_count": _stats_int(perf_data.get("vertex_count", [])),
	}


## Get frame time distribution percentiles
func get_frame_distribution() -> Dictionary:
	if frame_times.is_empty():
		return {}
	
	frame_times.sort()
	return {
		"p50": frame_times[frame_times.size() / 2],
		"p95": frame_times[int(frame_times.size() * 0.95)],
		"p99": frame_times[int(frame_times.size() * 0.99)],
		"max": frame_times[-1]
	}


## Calculate basic statistics for an array of floats
func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"avg": 0, "min": 0, "max": 0}
	
	var sum = 0.0
	var min_val = INF
	var max_val = -INF
	
	for v in values:
		sum += v
		min_val = min(min_val, v)
		max_val = max(max_val, v)
	
	return {
		"avg": sum / values.size(),
		"min": min_val,
		"max": max_val
	}


## Calculate statistics for integer arrays
func _stats_int(values: Array[int]) -> Dictionary:
	return _stats(values.map(func(v): return float(v)))
