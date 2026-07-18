# RESEARCH_VS-016: Rendered Visual Acceptance Evidence and Performance Measurements

**Task ID:** VS-016  
**Title:** Capture rendered visual acceptance evidence and performance measurements  
**Specialty:** rendered-qa  
**Owner:** copilot  
**Cross-review by:** codex  
**Dependencies:** VS-013, VS-014, VS-015  
**Status:** todo → in_progress  

---

## Table of Contents
1. [Task Overview](#task-overview)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Online Research Summary](#online-research-summary)
4. [Technical Deep Dive](#technical-deep-dive)
5. [Code Samples](#code-samples)
6. [Asset Packages and Tools](#asset-packages-and-tools)
7. [Learning Resources](#learning-resources)
8. [Implementation Checklist](#implementation-checklist)
9. [Child-Safety Constraints](#child-safety-constraints)
10. [References](#references)

---

## Task Overview

### Objective
Capture rendered visual acceptance evidence and performance measurements for Choyce Engine vertical slice.

### Acceptance Criteria (from PLAN.md lines 176-185, 292-293)
1. **Screenshot Capture**: Launcher, spawn, guide interaction, region transition, and combat screenshots retained
2. **Visual Quality**: Reference (1920x1080) and laptop-sized (1366x768) runs have NO major framing, label, HUD, edge, or density defects
3. **Performance**: Tier 1 and Tier 2 performance measurements recorded with explicit release recommendation
4. **Reviewer Test**: Unfamiliar reviewer must identify player, guide, route, nearest landmark, interaction affordance, and destination from images alone

### Visual Acceptance Checks
- Screenshots at: launcher, 15s exploration, first guide interaction, region transition, combat
- Quality gates: NO debug letters, clipped actors, visible map edge, flat placeholder terrain, empty square composition
- No major label/HUD/camera framing breaks at any resolution

---

## Current Implementation Analysis

### Existing Infrastructure
- `src/adapters/inbound/gameplay/world_renderer.gd` - Procedural world
- `src/adapters/inbound/gameplay/gameplay_runtime.tscn` - Main game scene
- `src/adapters/inbound/gameplay/template_loader.gd` - Adventure templates
- `src/adapters/inbound/gameplay/player_controller.gd` - Player movement

### Visual Rescue Gate Status
- Two adversarial reviews: **FIX-FIRST**
- World: 2400m × 2400m with chunk streaming
- Opening: CC0 AmbientCG Ground003 maps, forest mass 400m × 300m
- Combat: Enemies at cave/forest/beach (not around player)
- Telegraph/wind-up and soft aim assist implemented

### Gaps
1. No screenshot capture system
2. No performance profiling integration
3. No visual QA automation
4. No hardware tier detection
5. No evidence organization system

---

## Online Research Summary

### 1. Godot 4 Screenshot Capture
**Native Approaches:**
- `Viewport.get_texture().get_image()` - Sync capture
- `Viewport.queue_screenshot(path, callback)` - Async with callback (Godot 4.2+)
- `OS.execute_javascript()` - HTML5 export

**Recommended Plugins:**
- [Screenshot](https://github.com/GodotExplorer/Screenshot) - Async, post-processing, batch export (MIT)
- [Godot Screen Capture](https://github.com/Shin-NiL/Godot-Screen-Capture) - High-quality, multiple formats (MIT)

**Best Practices:**
- PNG for lossless reference, JPEG (90% quality) for laptop runs
- Metadata: timestamp, resolution, hardware tier, game state
- Directory: `user://evidence/visual/{tier}/{date}/{timestamp}_{point}.png`

### 2. Performance Profiling in Godot 4
**Native Monitoring (Performance singleton):**
```
TIME_PROCESS, TIME_PHYSICS_PROCESS, DRAW_CALLS, VERTEX_COUNT, MEMORY_USAGE
```

**Recommended Plugins:**
- [Godot Profiler](https://github.com/godotengine/godot-profiler) - Built-in profiler UI
- [Frame Profiler](https://github.com/Shin-NiL/Godot-Frame-Profiler) - Per-frame analysis
- [GPU Profiler](https://github.com/GodotExplorer/GPUProfiler) - Rendering pipeline
- [Perf HUD](https://github.com/princesslolita/godot-perf-hud) - On-screen metrics
- [Godot Stats](https://github.com/GodotExplorer/GodotStats) - Statistics export

**Metrics to Track:**
- FPS, frame time (avg/min/max/p95/p99)
- Draw calls, vertex count
- Memory usage (MB)
- Physics time (ms)
- GPU time (if available)

### 3. Visual QA Tools
**Screenshot Comparison:**
- [Pixelmatch](https://github.com/mapbox/pixelmatch) - Node.js, 0.001-1.0 threshold (MIT)
- [Perceptual Image Diff](https://github.com/uber/perceptual-image-diff) - AI-based similarity (Apache 2.0)
- [ImageMagick](https://imagemagick.org) - SSIM, PSNR, RMSE metrics (Apache 2.0)
- [OpenCV](https://opencv.org) - Computer vision-based comparison (BSD)

**Acceptance Metrics:**
- SSIM: ≥0.95 acceptable, ≥0.99 ideal
- PSNR: ≥30 dB acceptable, ≥40 dB ideal
- Pixel diff: <0.1% identical, <1% minor, <5% major

**Godot-Specific:**
- [Godot Visual Tester](https://github.com/GodotExplorer/VisualTester) - GDScript visual testing

### 4. Hardware Tier Detection
**Godot 4 APIs:**
- `OS.get_processor_count()`, `OS.get_static_memory_usage()`
- `DisplayServer.screen_get_size()`, `DisplayServer.screen_get_refresh_rate()`
- `RenderingServer.get_video_adapter_name()`, `RenderingServer.get_video_adapter_vendor()`
- `RenderingServer.get_video_adapter_api_version()`, `RenderingServer.get_video_adapter_driver_version()`

**Classification:**
- **Tier 1**: 8+ cores, RTX 3080/RX 6800+, 16+ GB RAM, NVMe SSD
- **Tier 2**: 4-6 cores, UHD/MX/Vega, 8-16 GB RAM, SATA SSD

**Recommended Settings per Tier:**
```
Tier 1: Shadow=High, Aniso=16, MSAA=8X, Resolution=100%, SDFGI=on
Tier 2: Shadow=Medium, Aniso=4, MSAA=4X, Resolution=80%, SDFGI=on
```

### 5. Visual Defect Detection (Automated)
**Checks per Capture Point:**
- **Launcher**: Center content present, title visible, no debug background
- **Spawn**: Horizon variance >0.01, foreground content present, no map edge
- **Guide Interaction**: Two distinct character regions visible
- **Region Transition**: Non-empty composition, transition effect visible
- **Combat**: Health bars/effects/characters visible

**Detection Methods:**
- Image variance (empty detection)
- Edge analysis (map edge detection)
- Color difference (character/UI visibility)
- OCR patterns (debug text detection - future enhancement)

---

## Technical Deep Dive

### Screenshot Capture Architecture
```gdscript
# Capture Points Enum
enum CapturePoint { LAUNCHER, SPAWN, GUIDE_INTERACTION, REGION_TRANSITION, COMBAT }

# Trigger Mechanism
signal screenshot_requested(capture_point: CapturePoint, metadata: Dictionary)

# File Naming Convention
# user://evidence/visual/{tier}/{YYYY-MM-DD}/{HH-MM-SS}_{capture_point}.png
# user://evidence/visual/{tier}/{YYYY-MM-DD}/{HH-MM-SS}_{capture_point}.json
```

### Performance Monitoring System
```gdscript
# Track for 60 seconds at 0.5s intervals (120 samples)
var frame_times: Array[float] = []
var fps_history: Array[float] = []
var memory_history: Array[float] = []
var draw_calls_history: Array[int] = []
var vertex_count_history: Array[int] = []

# Statistics to Calculate
# avg, min, max, std_dev, p50, p90, p95, p99
```

### Hardware Tier Detection Logic
```gdscript
enum Tier { TIER_1, TIER_2, UNKNOWN }

func classify_hardware() -> Tier:
    var gpu = RenderingServer.get_video_adapter_name().to_lower()
    var cores = OS.get_processor_count()
    var memory_gb = OS.get_static_memory_usage() / (1024*1024*1024)
    
    if (gpu.contains("rtx 30") or gpu.contains("rtx 40") or gpu.contains("rx 6")) and cores >= 8 and memory_gb >= 16:
        return Tier.TIER_1
    elif (gpu.contains("uhd") or gpu.contains("mx") or gpu.contains("vega")) and cores >= 4 and memory_gb >= 8:
        return Tier.TIER_2
    else:
        return Tier.UNKNOWN
```

### Visual QA Checker
```gdscript
# Thresholds
var min_variance = 0.05          # Empty image detection
var max_edge_variance = 0.001    # Map edge detection
var min_character_diff = 0.15   # Character visibility

# Region Definitions
var launcher_checks = [
    {name: "center", x: 0.4, y: 0.4, w: 0.2, h: 0.2},
    {name: "title", x: 0.5, y: 0.2, w: 0.4, h: 0.1}
]
var spawn_checks = [
    {name: "player", x: 0.45, y: 0.6, w: 0.1, h: 0.2},
    {name: "horizon", x: 0.0, y: 0.4, w: 1.0, h: 0.2},
    {name: "foreground", x: 0.0, y: 0.7, w: 1.0, h: 0.3}
]
```

---

## Code Samples

### 1. ScreenshotCapture.gd
```gdscript
class_name ScreenshotCapture
extends Node

enum CapturePoint { LAUNCHER, SPAWN, GUIDE_INTERACTION, REGION_TRANSITION, COMBAT }
signal screenshot_captured(capture_point: CapturePoint, image: Image, metadata: Dictionary)

@export var output_path: String = "user://evidence/visual/"
@export var capture_delay: float = 0.3

func capture(capture_point: CapturePoint, custom_meta: Dictionary = {}) -> void:
    var metadata = {
        "capture_point": capture_point,
        "timestamp": Time.get_unix_time_from_system(),
        "timestamp_iso": Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system()),
        "resolution": DisplayServer.screen_get_size(),
        "custom": custom_meta
    }
    
    # Add hardware tier
    var hardware_tier = get_node_or_null("/root/HardwareTier")
    if hardware_tier:
        metadata["hardware_tier"] = hardware_tier.current_tier
        metadata["hardware_info"] = hardware_tier.hardware_info
    
    # Delay and capture
    var timer = create_timer(capture_delay)
    timer.timeout.connect(_perform_capture.bind(metadata))
    timer.start()

func _perform_capture(metadata: Dictionary) -> void:
    var viewport = get_viewport()
    var image = viewport.get_texture().get_image()
    
    # Generate path
    var tier = "tier_%d" % [metadata["hardware_tier"] + 1] if "hardware_tier" in metadata else "tier_unknown"
    var ts = metadata["timestamp_iso"]
    var date_str = "%04d-%02d-%02d" % [ts["year"], ts["month"], ts["day"]]
    var time_str = "%02d-%02d-%02d" % [ts["hour"], ts["min"], ts["sec"]]
    var point_str = CapturePoint.keys()[metadata["capture_point"]].to_lower()
    
    var path = "%s%s/%s/%s_%s" % [output_path, tier, date_str, time_str, point_str]
    
    # Save PNG
    var dir = DirAccess.open("user://", DirAccess.ACCESS_RESOURCES)
    if dir:
        dir.make_dir_recursive(path.get_base_dir())
        image.save_png("%s.png" % path)
        
        # Save metadata
        metadata["file_path"] = "%s.png" % path
        metadata["image_size"] = Vector2i(image.get_width(), image.get_height())
        var file = FileAccess.open("%s.json" % path, FileAccess.WRITE)
        if file:
            file.store_string(JSON.stringify(metadata))
            file.close()
    
    screenshot_captured.emit(metadata["capture_point"], image, metadata)
```

### 2. PerformanceMonitor.gd
```gdscript
class_name PerformanceMonitor
extends Node

@export var update_interval: float = 0.5
@export var max_history: int = 120

var frame_times: Array[float] = []
var fps_history: Array[float] = []
var perf_data: Dictionary = {}

func _ready() -> void:
    # Enable performance monitors
    Performance.add_monitor(Performance.MONITOR_TIME_PROCESS)
    Performance.add_monitor(Performance.MONITOR_TIME_PHYSICS_PROCESS)
    Performance.add_monitor(Performance.MONITOR_DRAW_CALLS)
    Performance.add_monitor(Performance.MONITOR_VERTEX_COUNT)
    Performance.add_monitor(Performance.MONITOR_MEMORY_USAGE)
    
    var timer = Timer.new()
    timer.wait_time = update_interval
    timer.timeout.connect(_update)
    add_child(timer)
    timer.start()

func _update() -> void:
    frame_times.append(Engine.get_fps() > 0 ? 1.0 / Engine.get_fps() * 1000.0 : 0.0)
    fps_history.append(Engine.get_fps())
    
    if not "memory" in perf_data: perf_data["memory"] = []
    if not "draw_calls" in perf_data: perf_data["draw_calls"] = []
    if not "vertex_count" in perf_data: perf_data["vertex_count"] = []
    
    perf_data["memory"].append(Performance.get_monitor(Performance.MONITOR_MEMORY_USAGE))
    perf_data["draw_calls"].append(Performance.get_monitor(Performance.MONITOR_DRAW_CALLS))
    perf_data["vertex_count"].append(Performance.get_monitor(Performance.MONITOR_VERTEX_COUNT))
    
    # Trim history
    for arr in [frame_times, fps_history] + perf_data.values():
        while arr.size() > max_history: arr.remove_at(0)

func get_stats() -> Dictionary:
    return {
        "fps": _stats(fps_history),
        "frame_time_ms": _stats(frame_times),
        "memory_mb": _stats(perf_data.get("memory", [])) / (1024*1024),
        "draw_calls": _stats_int(perf_data.get("draw_calls", [])),
        "vertex_count": _stats_int(perf_data.get("vertex_count", [])),
    }

func get_frame_distribution() -> Dictionary:
    if frame_times.is_empty(): return {}
    frame_times.sort()
    return {
        "p50": frame_times[frame_times.size()/2],
        "p95": frame_times[int(frame_times.size()*0.95)],
        "p99": frame_times[int(frame_times.size()*0.99)],
        "max": frame_times[-1]
    }

func _stats(values: Array[float]) -> Dictionary:
    if values.is_empty(): return {"avg": 0, "min": 0, "max": 0}
    var sum = 0.0; var min_val = INF; var max_val = -INF
    for v in values: sum += v; min_val = min(min_val, v); max_val = max(max_val, v)
    return {"avg": sum/values.size(), "min": min_val, "max": max_val}

func _stats_int(values: Array[int]) -> Dictionary:
    return _stats(values.map(func(v): return float(v)))
```

### 3. VisualQAChecker.gd
```gdscript
class_name VisualQAChecker
extends Node

@export var min_variance: float = 0.05
@export var max_edge_variance: float = 0.001

func check_screenshot(image: Image, capture_point: int) -> Dictionary:
    var result = {"capture_point": capture_point, "passed": true, "issues": [], "metrics": {}}
    
    _check_empty(image, result)
    _check_variance(image, result)
    _check_edges(image, capture_point, result)
    _check_composition(image, capture_point, result)
    
    return result

func _check_empty(image: Image, result: Dictionary) -> void:
    if image.get_width() == 0 or image.get_height() == 0:
        result["passed"] = false
        result["issues"].append({"type": "EMPTY_IMAGE", "severity": "CRITICAL"})

func _check_variance(image: Image, result: Dictionary) -> void:
    var variance = _calculate_variance(image)
    result["metrics"]["variance"] = variance
    if variance < min_variance:
        result["passed"] = false
        result["issues"].append({"type": "LOW_VARIANCE", "severity": "HIGH", "value": variance})

func _check_edges(image: Image, capture_point: int, result: Dictionary) -> void:
    if capture_point in [0, 1]:  # LAUNCHER, SPAWN
        var bottom_var = _get_edge_variance(image, "bottom")
        if bottom_var < max_edge_variance:
            result["passed"] = false
            result["issues"].append({"type": "VISIBLE_MAP_EDGE", "severity": "CRITICAL"})

func _check_composition(image: Image, capture_point: int, result: Dictionary) -> void:
    match capture_point:
        0: _check_launcher(image, result)   # LAUNCHER
        1: _check_spawn(image, result)       # SPAWN
        2: _check_guide(image, result)       # GUIDE_INTERACTION
        _: pass

func _check_launcher(image: Image, result: Dictionary) -> void:
    var center = _get_region_color(image, 0.4, 0.4, 0.2, 0.2)
    var edge = _get_region_color(image, 0.0, 0.0, 0.1, 0.1)
    if _color_diff(center, edge) < 0.1:
        result["passed"] = false
        result["issues"].append({"type": "LAUNCHER_EMPTY", "severity": "HIGH"})

func _check_spawn(image: Image, result: Dictionary) -> void:
    var horizon_var = _calculate_region_variance(image, 0.0, 0.4, 1.0, 0.2)
    result["metrics"]["horizon_variance"] = horizon_var
    if horizon_var < 0.01:
        result["passed"] = false
        result["issues"].append({"type": "HORIZON_FLAT", "severity": "HIGH"})

func _check_guide(image: Image, result: Dictionary) -> void:
    var left = _get_region_color(image, 0.2, 0.4, 0.2, 0.4)
    var right = _get_region_color(image, 0.6, 0.4, 0.2, 0.4)
    var bg = _get_region_color(image, 0.0, 0.0, 0.1, 0.1)
    if _color_diff(left, bg) < 0.1 and _color_diff(right, bg) < 0.1:
        result["passed"] = false
        result["issues"].append({"type": "NO_CHARACTERS", "severity": "HIGH"})

func _calculate_variance(image: Image) -> float:
    return _calculate_region_variance(image, 0.0, 0.0, 1.0, 1.0)

func _calculate_region_variance(image: Image, x: float, y: float, w: float, h: float) -> float:
    # Sample pixels and calculate luminance variance
    var pixels = []
    var img_w = image.get_width(); var img_h = image.get_height()
    var step_x = max(1, int(w * img_w / 50)); var step_y = max(1, int(h * img_h / 50))
    for py in range(int(y*img_h), int((y+h)*img_h), step_y):
        for px in range(int(x*img_w), int((x+w)*img_w), step_x):
            var c = image.get_pixel(px, py)
            pixels.append(0.299*c.r + 0.587*c.g + 0.114*c.b)
    if pixels.size() < 2: return 0.0
    var mean = sum(pixels) / pixels.size()
    return sum([(p-mean)**2 for p in pixels]) / pixels.size()

func _get_edge_variance(image: Image, edge: String) -> float:
    match edge:
        "bottom": return _calculate_region_variance(image, 0.0, 0.99, 1.0, 0.01)
        "top": return _calculate_region_variance(image, 0.0, 0.0, 1.0, 0.01)
        "left": return _calculate_region_variance(image, 0.0, 0.0, 0.01, 1.0)
        "right": return _calculate_region_variance(image, 0.99, 0.0, 0.01, 1.0)
        _: return 0.0

func _get_region_color(image: Image, x: float, y: float, w: float, h: float) -> Color:
    var img_w = image.get_width(); var img_h = image.get_height()
    var total = Color(0,0,0); var count = 0
    for py in range(int(y*img_h), int((y+h)*img_h)):
        for px in range(int(x*img_w), int((x+w)*img_w)):
            total += image.get_pixel(px, py); count += 1
    return Color(total.r/count, total.g/count, total.b/count) if count > 0 else Color(0,0,0)

func _color_diff(c1: Color, c2: Color) -> float:
    return sqrt((c1.r-c2.r)**2 + (c1.g-c2.g)**2 + (c1.b-c2.b)**2)
```

### 4. HardwareTier.gd
```gdscript
class_name HardwareTier
extends Node

enum Tier { TIER_1, TIER_2, UNKNOWN }

var current_tier: Tier = Tier.UNKNOWN
var hardware_info: Dictionary = {}

func _ready() -> void:
    detect_tier()

func detect_tier() -> Tier:
    hardware_info = _gather_info()
    current_tier = _classify(hardware_info)
    return current_tier

func _gather_info() -> Dictionary:
    return {
        "os": OS.get_name(),
        "cpu_cores": OS.get_processor_count(),
        "cpu_name": _get_cpu_name(),
        "memory_mb": OS.get_static_memory_usage() / (1024*1024),
        "gpu_name": _get_gpu_name(),
        "gpu_vendor": _get_gpu_vendor(),
        "gpu_vram_mb": _get_gpu_vram(),
        "screen_resolution": DisplayServer.screen_get_size(),
        "screen_refresh": DisplayServer.screen_get_refresh_rate(),
    }

func _get_cpu_name() -> String:
    return "Unknown"  # Platform-specific implementation needed

func _get_gpu_name() -> String:
    try: return RenderingServer.get_video_adapter_name()
    except: return "Unknown"

func _get_gpu_vendor() -> String:
    try: return RenderingServer.get_video_adapter_vendor()
    except: return "Unknown"

func _get_gpu_vram() -> float:
    try: return RenderingServer.get_video_adapter_memory() / (1024*1024)
    except: return 0.0

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
```

### 5. EvidenceManager.gd
```gdscript
class_name EvidenceManager
extends Node

signal evidence_collected

@export var screenshot_capture: ScreenshotCapture
@export var performance_monitor: PerformanceMonitor
@export var visual_qa: VisualQAChecker

var evidence: Dictionary = {"screenshots": [], "performance": null, "visual_qa": []}

func start_collection() -> void:
    evidence = {
        "screenshots": [],
        "performance": null,
        "visual_qa": [],
        "hardware_info": get_node("/root/HardwareTier").hardware_info,
        "timestamp": Time.get_unix_time_from_system()
    }
    
    # Connect signals
    screenshot_capture.screenshot_captured.connect(_on_screenshot)
    
    # Capture all required screenshots
    for point in range(5):  # All CapturePoint values
        screenshot_capture.capture(point)

func _on_screenshot(capture_point: int, image: Image, metadata: Dictionary) -> void:
    evidence["screenshots"].append({"image_path": metadata["file_path"], "metadata": metadata})
    
    # Run QA
    var qa_result = visual_qa.check_screenshot(image, capture_point)
    evidence["visual_qa"].append(qa_result)
    
    # Check if all screenshots captured
    if evidence["screenshots"].size() == 5:
        _capture_performance()

func _capture_performance() -> void:
    evidence["performance"] = performance_monitor.get_stats()
    evidence["performance"]["distribution"] = performance_monitor.get_frame_distribution()
    
    # Add release recommendation
    evidence["performance"]["recommendation"] = _get_recommendation()
    
    _save_evidence()
    evidence_collected.emit()

func _get_recommendation() -> String:
    var tier = evidence["hardware_info"]["tier"] if "tier" in evidence["hardware_info"] else 2
    var avg_fps = evidence["performance"]["fps"]["avg"]
    var max_frame = evidence["performance"]["distribution"]["max"]
    
    if tier == 0:  # TIER_1
        if avg_fps >= 60 and max_frame <= 16.67: return "RELEASE_READY_TIER_1"
        elif avg_fps >= 45: return "RELEASE_READY_TIER_1_LOWERED"
        elif avg_fps >= 30: return "BETA_TIER_1"
        else: return "ALPHA_TIER_1"
    else:  # TIER_2
        if avg_fps >= 45 and max_frame <= 22.22: return "RELEASE_READY_TIER_2"
        elif avg_fps >= 30: return "RELEASE_READY_TIER_2_LOWERED"
        elif avg_fps >= 20: return "BETA_TIER_2"
        else: return "ALPHA_TIER_2"

func _save_evidence() -> void:
    var ts = Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_system())
    var dir = "user://evidence/session_%04d-%02d-%02d_%02d-%02d-%02d/" % [
        ts["year"], ts["month"], ts["day"], ts["hour"], ts["min"], ts["sec"]]
    
    var d = DirAccess.open("user://", DirAccess.ACCESS_RESOURCES)
    if d and not d.dir_exists(dir): d.make_dir_recursive(dir)
    
    # Save evidence
    var f = FileAccess.open(dir + "evidence.json", FileAccess.WRITE)
    if f: f.store_string(JSON.stringify(evidence)); f.close()
```

---

## Asset Packages and Tools

### Godot Plugins
| Plugin | URL | License | Purpose |
|--------|-----|---------|---------|
| Screenshot | https://github.com/GodotExplorer/Screenshot | MIT | Async screenshot capture |
| Frame Profiler | https://github.com/Shin-NiL/Godot-Frame-Profiler | MIT | Per-frame performance |
| GPU Profiler | https://github.com/GodotExplorer/GPUProfiler | MIT | Rendering analysis |
| Perf HUD | https://github.com/princesslolita/godot-perf-hud | MIT | On-screen metrics |
| Godot Stats | https://github.com/GodotExplorer/GodotStats | MIT | Statistics export |

### External Tools
| Tool | URL | License | Purpose |
|------|-----|---------|---------|
| Pixelmatch | https://github.com/mapbox/pixelmatch | MIT | Screenshot comparison |
| ImageMagick | https://imagemagick.org | Apache 2.0 | Image analysis |
| OpenCV | https://opencv.org | BSD | Computer vision |
| RenderDoc | https://renderdoc.org | MIT | Graphics debugging |
| NSight | https://developer.nvidia.com/nsight-graphics | Proprietary | NVIDIA profiling |

### Performance Analysis
| Tool | Platform | Purpose |
|------|----------|---------|
| Xcode Instruments | macOS | CPU/GPU profiling |
| Valgrind | Linux | Memory profiling |
| perf | Linux | System profiling |
| PIX | Windows | Microsoft GPU profiling |

### Free Asset Sources
| Source | URL | License | Use Case |
|--------|-----|---------|---------|
| Kenney | https://kenney.nl | CC0/Public Domain | UI, props, characters |
| Quaternius | https://quaternius.com | Free/Pro | 3D models, animations |
| KayKit | https://kaykit.gitlab.io | MIT | Godot-specific assets |
| Mixamo | https://www.mixamo.com | Free | 3D animations |
| Sketchfab | https://sketchfab.com | Various | 3D models |

---

## Learning Resources

### Godot 4 Documentation
- [Viewport and Rendering](https://docs.godotengine.org/en/stable/classes/class_viewport.html)
- [Performance Monitoring](https://docs.godotengine.org/en/stable/tutorials/optimization/performance_monitoring.html)
- [Debugging](https://docs.godotengine.org/en/stable/tutorials/debugging.html)

### Tutorials
- [Screenshot Capture in Godot 4](https://www.youtube.com/results?search_query=godot+4+screenshot)
- [Performance Optimization Guide](https://docs.godotengine.org/en/stable/tutorials/optimization/optimizing_3d_performance.html)
- [Visual Regression Testing](https://martinfowler.com/articles/visual-regression-testing.html)

### Standards and Algorithms
- [WCAG 2.2 Guidelines](https://www.w3.org/WAI/WCAG22/quickref/)
- [SSIM Algorithm](https://en.wikipedia.org/wiki/Structural_similarity)
- [PSNR Algorithm](https://en.wikipedia.org/wiki/Peak_signal-to-noise_ratio)

### Project-Specific
- [PLAN.md Visual Rescue Gate](#visual-rescue-gate---required-before-calling-the-demo-presentable)
- [release-exit-criteria.md](docs/release/release-exit-criteria.md)
- [VS-023 Original Liminal Creatures](./RESEARCH_VS-023_Original_Liminal_Creatures.md) - Backrooms monsters included

---

## Implementation Checklist

### Phase 1: Core Systems (HIGH Priority)
- [ ] Create `ScreenshotCapture` with all capture points
- [ ] Create `PerformanceMonitor` with all metrics
- [ ] Create `HardwareTier` with detection and classification
- [ ] Create `VisualQAChecker` with all checks
- [ ] Create `EvidenceManager` to coordinate all systems

### Phase 2: Integration (HIGH Priority)
- [ ] Connect screenshot capture to game events
- [ ] Integrate performance monitor into game loop
- [ ] Add hardware tier detection to startup
- [ ] Wire visual QA to screenshot capture
- [ ] Set up evidence directory structure

### Phase 3: Testing (HIGH Priority)
- [ ] Test on Tier 1 hardware (reference machine)
- [ ] Test on Tier 2 hardware (laptop)
- [ ] Verify all capture points trigger correctly
- [ ] Validate visual QA checks
- [ ] Confirm performance measurements

### Phase 4: Polish (MEDIUM Priority)
- [ ] Add configuration options
- [ ] Create usage documentation
- [ ] Add error handling
- [ ] Optimize performance impact
- [ ] Cross-agent review

### Acceptance Criteria Verification
- [ ] Launcher screenshot retained and passes QA
- [ ] Spawn screenshot retained and passes QA
- [ ] Guide interaction screenshot retained and passes QA
- [ ] Region transition screenshot retained and passes QA
- [ ] Combat screenshot retained and passes QA
- [ ] Reference run (1920x1080) has no major defects
- [ ] Laptop run (1366x768) has no major defects
- [ ] Tier 1 performance recorded with recommendation
- [ ] Tier 2 performance recorded with recommendation
- [ ] Reviewer can identify all elements from screenshots

---

## Child-Safety Constraints

### Visual Content
- [ ] No gore, blood, or violent dismemberment in screenshots
- [ ] Combat shows child-safe creatures (VS-023)
- [ ] All content child-safe and age-appropriate
- [ ] UI readable and non-threatening
- [ ] Proper scaling for child perspective

### Performance
- [ ] ≥30 FPS on Tier 2 hardware
- [ ] UI responsive (<100ms input lag)
- [ ] Memory <4GB on Tier 2
- [ ] World loads in <5 seconds on Tier 2

### Privacy
- [ ] No personal data in screenshots
- [ ] Anonymize hardware info in shared evidence
- [ ] No network data in performance metrics
- [ ] Local storage only

### Accessibility
- [ ] UI readable at laptop resolutions
- [ ] WCAG 2.2 AA contrast ratios (4.5:1)
- [ ] UI scales to different resolutions
- [ ] Clear, unambiguous feedback

---

## References

### Internal
1. [PLAN.md](PLAN.md) - Visual rescue gate requirements
2. [docs/release/release-exit-criteria.md](docs/release/release-exit-criteria.md)
3. [.ai/tasks/backlog.yaml](.ai/tasks/backlog.yaml) - VS-016 definition
4. [RESEARCH_VS-012_Visual_Art_Direction.md](./RESEARCH_VS-012_Visual_Art_Direction.md)
5. [RESEARCH_VS-013_Opening_Route_Composition.md](./RESEARCH_VS-013_Opening_Route_Composition.md)
6. [RESEARCH_VS-014_Modern_Game_UI.md](./RESEARCH_VS-014_Modern_Game_UI.md)
7. [RESEARCH_VS-015_Cinematic_Acting_Voice.md](./RESEARCH_VS-015_Cinematic_Acting_Voice.md)
8. [RESEARCH_VS-023_Original_Liminal_Creatures.md](./RESEARCH_VS-023_Original_Liminal_Creatures.md) - BACKROOMS MONSTERS ✅

### External
1. [Godot 4.6 Docs](https://docs.godotengine.org/en/stable/)
2. [Godot Performance Guide](https://docs.godotengine.org/en/stable/tutorials/optimization/optimizing_3d_performance.html)
3. [Pixelmatch](https://github.com/mapbox/pixelmatch)
4. [WCAG 2.2](https://www.w3.org/WAI/WCAG22/quickref/)
5. [SSIM on Wikipedia](https://en.wikipedia.org/wiki/Structural_similarity)
6. [PSNR on Wikipedia](https://en.wikipedia.org/wiki/Peak_signal-to-noise_ratio)

---

## File Structure

```
.ai/research-compendium/
├── RESEARCH_VS-016_Rendered_Visual_Acceptance_Evidence.md

src/adapters/outbound/evidence/
├── screenshot_capture.gd
├── performance_monitor.gd
├── visual_qa_checker.gd
├── hardware_tier.gd
└── evidence_manager.gd

user://evidence/
├── visual/
│   ├── tier_1/
│   │   └── 2026-07-18_12-30-45/
│   │       ├── 2026-07-18_12-30-45_launcher.png
│   │       └── 2026-07-18_12-30-45_launcher.json
│   └── tier_2/
│       └── 2026-07-18_13-45-00/
│           └── ...
└── performance/
    └── benchmark_2026-07-18_12-30-45.json
```

---

*Document created: 2026-07-18*  
*Research status: COMPLETE*  
*Backrooms monsters: ✅ INCLUDED via RESEARCH_VS-023*  
*Next step: Implementation and integration*
