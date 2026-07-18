class_name ScreenFeedback extends Control

func flash(color: Color, duration: float = 0.15) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration).from(0.4)
	await tween.finished
	rect.queue_free()

func shake(intensity: float = 8.0, duration: float = 0.3) -> void:
	# Respect reduce-motion accessibility setting
	if _is_reduce_motion_enabled():
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var original_pos := camera.position
	var tween := create_tween()
	for i in range(int(duration * 60)):
		var offset := Vector3(randf() - 0.5, randf() - 0.5, 0) * intensity
		tween.tween_property(camera, "position", original_pos + offset, 0.016)
	tween.tween_property(camera, "position", original_pos, 0.016)


## Adv Y C4 fix — directional shake that biases the camera kick
## toward the hit side. Each per-frame offset is a small symmetric
## jitter plus a strong directional component along the supplied 2-D
## screen-space vector. Reads as "punch landed THIS way" instead of
## "screen shimmied randomly". Caller passes basis * LEFT * sign(...)
## for sub-second cues; we don't read camera basis here so this stays
## a pure Control method.
func shake_directional(intensity: float = 6.0, duration: float = 0.08,
		direction: Vector2 = Vector2.ZERO) -> void:
	# Respect reduce-motion accessibility setting
	if _is_reduce_motion_enabled():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var original_pos := camera.position
	var dir := direction
	if dir.length_squared() < 0.0001:
		dir = Vector2(0.0, -1.0)
	else:
		dir = dir.normalized()
	var tween := create_tween()
	var frames := maxi(int(duration * 60), 1)
	for i in range(frames):
		# Decay the directional kick over the duration so the camera
		# returns smoothly to rest.
		var decay := 1.0 - (float(i) / float(frames))
		var jitter := Vector3((randf() - 0.5) * 0.4, (randf() - 0.5) * 0.4, 0) * intensity
		var kick := Vector3(dir.x, dir.y, 0) * intensity * 0.85 * decay
		tween.tween_property(camera, "position", original_pos + jitter + kick, 0.016)
	tween.tween_property(camera, "position", original_pos, 0.016)


## Helper to check if reduce-motion is enabled via the global accessibility policy
func _is_reduce_motion_enabled() -> bool:
	var AccessibilityPolicyPort_class := load("res://src/ports/outbound/accessibility_policy_port.gd")
	if AccessibilityPolicyPort_class != null:
		return AccessibilityPolicyPort_class._global_instance.is_reduce_motion_enabled() if AccessibilityPolicyPort_class._global_instance else false
	return false
