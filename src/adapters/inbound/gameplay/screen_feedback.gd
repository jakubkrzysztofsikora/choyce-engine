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
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var original_pos := camera.position
	var tween := create_tween()
	for i in range(int(duration * 60)):
		var offset := Vector3(randf() - 0.5, randf() - 0.5, 0) * intensity
		tween.tween_property(camera, "position", original_pos + offset, 0.016)
	tween.tween_property(camera, "position", original_pos, 0.016)
