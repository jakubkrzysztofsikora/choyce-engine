## VisualQAChecker - VS-016
## Performs automated visual quality checks on screenshots.
## 
## Checks for empty images, low variance, visible map edges, and composition issues.

class_name VisualQAChecker
extends Node

## Thresholds for QA checks
@export var min_variance: float = 0.05          # Empty image detection
@export var max_edge_variance: float = 0.001    # Map edge detection
@export var min_character_diff: float = 0.15   # Character visibility

## Capture point enum (must match ScreenshotCapture)
enum CapturePoint {
	LAUNCHER,
	SPAWN,
	GUIDE_INTERACTION,
	REGION_TRANSITION,
	COMBAT
}


## Check a screenshot for visual quality issues
## 
## Args:
##   image: The Image to check
##   capture_point: The CapturePoint enum value
## 
## Returns:
##   Dictionary with passed (bool), issues (Array), and metrics (Dictionary)
func check_screenshot(image: Image, capture_point: CapturePoint) -> Dictionary:
	var result: Dictionary = {
		"capture_point": capture_point,
		"passed": true,
		"issues": [],
		"metrics": {}
	}
	
	_check_empty(image, result)
	_check_variance(image, result)
	_check_edges(image, capture_point, result)
	_check_composition(image, capture_point, result)
	
	return result


## Check if image is empty
func _check_empty(image: Image, result: Dictionary) -> void:
	if image == null or image.get_width() == 0 or image.get_height() == 0:
		result["passed"] = false
		result["issues"].append({
			"type": "EMPTY_IMAGE",
			"severity": "CRITICAL",
			"message": "Image has zero dimensions"
		})


## Check image variance to detect flat/empty images
func _check_variance(image: Image, result: Dictionary) -> void:
	var variance = _calculate_variance(image)
	result["metrics"]["variance"] = variance
	
	if variance < min_variance:
		result["passed"] = false
		result["issues"].append({
			"type": "LOW_VARIANCE",
			"severity": "HIGH",
			"value": variance,
			"message": "Image variance %.4f is below threshold %.4f" % [variance, min_variance]
		})


## Check for visible map edges
func _check_edges(image: Image, capture_point: CapturePoint, result: Dictionary) -> void:
	# Check bottom edge for LAUNCHER and SPAWN (should not show map edge)
	if capture_point in [CapturePoint.LAUNCHER, CapturePoint.SPAWN]:
		var bottom_var = _get_edge_variance(image, "bottom")
		result["metrics"]["bottom_edge_variance"] = bottom_var
		
		if bottom_var < max_edge_variance:
			result["passed"] = false
			result["issues"].append({
				"type": "VISIBLE_MAP_EDGE",
				"severity": "CRITICAL",
				"value": bottom_var,
				"message": "Visible map edge detected at bottom (variance %.6f < %.6f)" % [bottom_var, max_edge_variance]
			})


## Check composition based on capture point
func _check_composition(image: Image, capture_point: CapturePoint, result: Dictionary) -> void:
	match capture_point:
		CapturePoint.LAUNCHER:
			_check_launcher(image, result)
		CapturePoint.SPAWN:
			_check_spawn(image, result)
		CapturePoint.GUIDE_INTERACTION:
			_check_guide(image, result)
		CapturePoint.REGION_TRANSITION:
			_check_region_transition(image, result)
		CapturePoint.COMBAT:
			_check_combat(image, result)
		_: pass


## Check launcher screenshot composition
func _check_launcher(image: Image, result: Dictionary) -> void:
	var center = _get_region_color(image, 0.4, 0.4, 0.2, 0.2)
	var edge = _get_region_color(image, 0.0, 0.0, 0.1, 0.1)
	
	if _color_diff(center, edge) < 0.1:
		result["passed"] = false
		result["issues"].append({
			"type": "LAUNCHER_EMPTY",
			"severity": "HIGH",
			"message": "Launcher center and edge colors too similar - may be empty"
		})


## Check spawn screenshot composition
func _check_spawn(image: Image, result: Dictionary) -> void:
	var horizon_var = _calculate_region_variance(image, 0.0, 0.4, 1.0, 0.2)
	result["metrics"]["horizon_variance"] = horizon_var
	
	if horizon_var < 0.01:
		result["passed"] = false
		result["issues"].append({
			"type": "HORIZON_FLAT",
			"severity": "HIGH",
			"value": horizon_var,
			"message": "Horizon variance %.4f is too low - may be flat" % horizon_var
		})


## Check guide interaction screenshot composition
func _check_guide(image: Image, result: Dictionary) -> void:
	var left = _get_region_color(image, 0.2, 0.4, 0.2, 0.4)
	var right = _get_region_color(image, 0.6, 0.4, 0.2, 0.4)
	var bg = _get_region_color(image, 0.0, 0.0, 0.1, 0.1)
	
	if _color_diff(left, bg) < 0.1 and _color_diff(right, bg) < 0.1:
		result["passed"] = false
		result["issues"].append({
			"type": "NO_CHARACTERS",
			"severity": "HIGH",
			"message": "No distinct characters visible in guide interaction"
		})


## Check region transition screenshot composition
func _check_region_transition(image: Image, result: Dictionary) -> void:
	# Should have non-empty composition with visible transition effect
	var total_var = _calculate_variance(image)
	result["metrics"]["total_variance"] = total_var
	
	if total_var < 0.05:
		result["passed"] = false
		result["issues"].append({
			"type": "TRANSITION_EMPTY",
			"severity": "HIGH",
			"value": total_var,
			"message": "Region transition image variance too low" % total_var
		})


## Check combat screenshot composition
func _check_combat(image: Image, result: Dictionary) -> void:
	# Combat should show health bars, effects, or characters
	# Check for UI elements (health bars are typically red/green)
	var health_bar_region = _get_region_color(image, 0.5, 0.1, 0.4, 0.05)
	var bg_region = _get_region_color(image, 0.0, 0.0, 0.1, 0.1)
	
	# Health bars should be different from background
	if _color_diff(health_bar_region, bg_region) < 0.2:
		result["issues"].append({
			"type": "WARNING_HEALTH_BAR_NOT_VISIBLE",
			"severity": "MEDIUM",
			"message": "Health bar may not be visible"
		})


## Calculate variance of entire image
func _calculate_variance(image: Image) -> float:
	return _calculate_region_variance(image, 0.0, 0.0, 1.0, 1.0)


## Calculate variance of a specific region (normalized coordinates 0-1)
func _calculate_region_variance(image: Image, x: float, y: float, w: float, h: float) -> float:
	var pixels: Array[float] = []
	var img_w = image.get_width()
	var img_h = image.get_height()
	
	# Sample step - limit to ~50 samples per dimension for performance
	var step_x = max(1, int(w * img_w / 50))
	var step_y = max(1, int(h * img_h / 50))
	
	for py in range(int(y * img_h), int((y + h) * img_h), step_y):
		for px in range(int(x * img_w), int((x + w) * img_w), step_x):
			var c = image.get_pixel(px, py)
			# Calculate luminance
			pixels.append(0.299 * c.r + 0.587 * c.g + 0.114 * c.b)
	
	if pixels.size() < 2:
		return 0.0
	
	# Calculate mean
	var total = 0.0
	for p in pixels:
		total += p
	var mean = total / pixels.size()
	
	# Calculate variance
	var sum_sq = 0.0
	for p in pixels:
		sum_sq += (p - mean) ** 2
	return sum_sq / pixels.size()


## Get variance of a specific edge
func _get_edge_variance(image: Image, edge: String) -> float:
	match edge:
		"bottom": return _calculate_region_variance(image, 0.0, 0.99, 1.0, 0.01)
		"top": return _calculate_region_variance(image, 0.0, 0.0, 1.0, 0.01)
		"left": return _calculate_region_variance(image, 0.0, 0.0, 0.01, 1.0)
		"right": return _calculate_region_variance(image, 0.99, 0.0, 0.01, 1.0)
		_: return 0.0


## Get average color of a region (normalized coordinates 0-1)
func _get_region_color(image: Image, x: float, y: float, w: float, h: float) -> Color:
	var img_w = image.get_width()
	var img_h = image.get_height()
	var total = Color(0, 0, 0)
	var count = 0
	
	for py in range(int(y * img_h), int((y + h) * img_h)):
		for px in range(int(x * img_w), int((x + w) * img_w)):
			total += image.get_pixel(px, py)
			count += 1
	
	return Color(total.r / count, total.g / count, total.b / count) if count > 0 else Color(0, 0, 0)


## Calculate color difference (Euclidean distance in RGB space)
func _color_diff(c1: Color, c2: Color) -> float:
	return sqrt((c1.r - c2.r) ** 2 + (c1.g - c2.g) ** 2 + (c1.b - c2.b) ** 2)
