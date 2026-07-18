## Unit tests for VS-016 evidence capture components
## Run: godot --headless --script tests/adapters/outbound/test_evidence_capture.gd

class_name TestEvidenceCapture
extends SceneTree

const ScreenshotCaptureClass := preload("res://src/adapters/outbound/evidence/screenshot_capture.gd")
const PerformanceMonitorClass := preload("res://src/adapters/outbound/evidence/performance_monitor.gd")
const HardwareTierClass := preload("res://src/adapters/outbound/evidence/hardware_tier.gd")
const VisualQACheckerClass := preload("res://src/adapters/outbound/evidence/visual_qa_checker.gd")
const EvidenceManagerClass := preload("res://src/adapters/outbound/evidence/evidence_manager.gd")


func _init() -> void:
	var failures: Array = []
	
	_test_screenshot_capture(failures)
	_test_performance_monitor(failures)
	_test_hardware_tier(failures)
	_test_visual_qa_checker(failures)
	_test_evidence_manager(failures)
	
	if failures.is_empty():
		print("[test_evidence_capture] OK")
		quit(0)
	else:
		printerr("[test_evidence_capture] FAIL ", failures.size())
		for f in failures:
			printerr("  - ", f)
		quit(1)


func _test_screenshot_capture(failures: Array) -> void:
	# Test that ScreenshotCapture can be instantiated
	var capture = ScreenshotCaptureClass.new()
	if capture == null:
		failures.append("ScreenshotCapture: failed to instantiate")
		return
	
	# Test capture point enum
	if ScreenshotCaptureClass.CapturePoint.LAUNCHER != 0:
		failures.append("ScreenshotCapture: LAUNCHER enum value incorrect")
	if ScreenshotCaptureClass.CapturePoint.SPAWN != 1:
		failures.append("ScreenshotCapture: SPAWN enum value incorrect")
	if ScreenshotCaptureClass.CapturePoint.GUIDE_INTERACTION != 2:
		failures.append("ScreenshotCapture: GUIDE_INTERACTION enum value incorrect")
	if ScreenshotCaptureClass.CapturePoint.REGION_TRANSITION != 3:
		failures.append("ScreenshotCapture: REGION_TRANSITION enum value incorrect")
	if ScreenshotCaptureClass.CapturePoint.COMBAT != 4:
		failures.append("ScreenshotCapture: COMBAT enum value incorrect")


func _test_performance_monitor(failures: Array) -> void:
	var monitor = PerformanceMonitorClass.new()
	if monitor == null:
		failures.append("PerformanceMonitor: failed to instantiate")
		return
	
	# Test _stats function with empty array
	var empty_stats = monitor._stats([])
	if empty_stats["avg"] != 0 or empty_stats["min"] != 0 or empty_stats["max"] != 0:
		failures.append("PerformanceMonitor: empty stats not zero")
	
	# Test _stats function with values
	var values: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
	var stats = monitor._stats(values)
	if abs(stats["avg"] - 3.0) > 0.001:
		failures.append("PerformanceMonitor: avg calculation incorrect")
	if stats["min"] != 1.0:
		failures.append("PerformanceMonitor: min calculation incorrect")
	if stats["max"] != 5.0:
		failures.append("PerformanceMonitor: max calculation incorrect")


func _test_hardware_tier(failures: Array) -> void:
	var tier = HardwareTierClass.new()
	if tier == null:
		failures.append("HardwareTier: failed to instantiate")
		return
	
	# Test detect_tier returns a valid Tier enum
	var current_tier = tier.detect_tier()
	if current_tier != HardwareTierClass.Tier.TIER_1 and \
	   current_tier != HardwareTierClass.Tier.TIER_2 and \
	   current_tier != HardwareTierClass.Tier.UNKNOWN:
		failures.append("HardwareTier: detect_tier returned invalid value")


func _test_visual_qa_checker(failures: Array) -> void:
	var checker = VisualQACheckerClass.new()
	if checker == null:
		failures.append("VisualQAChecker: failed to instantiate")
		return
	
	# Test _color_diff function
	var c1 = Color(1, 0, 0)
	var c2 = Color(0, 0, 0)
	var diff = checker._color_diff(c1, c2)
	if abs(diff - 1.0) > 0.001:
		failures.append("VisualQAChecker: color_diff calculation incorrect")
	
	# Test _color_diff with same colors
	var same_diff = checker._color_diff(c1, c1)
	if same_diff > 0.001:
		failures.append("VisualQAChecker: color_diff same color not zero")


func _test_evidence_manager(failures: Array) -> void:
	var manager = EvidenceManagerClass.new()
	if manager == null:
		failures.append("EvidenceManager: failed to instantiate")
		return
	
	# Test get_status returns expected structure
	var status = manager.get_status()
	if "captured_points" not in status:
		failures.append("EvidenceManager: status missing captured_points")
	if "total_points" not in status:
		failures.append("EvidenceManager: status missing total_points")
	if status["total_points"] != 5:
		failures.append("EvidenceManager: total_points should be 5")
