class_name ShellTransition
extends Node

const DURATION := 0.2

func transition_in(control: Control) -> void:
	if control == null:
		return
	control.modulate.a = 0.0
	control.scale = Vector2(0.98, 0.98)
	control.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, DURATION)
	tween.parallel().tween_property(control, "scale", Vector2.ONE, DURATION)


func transition_out(control: Control, callback: Callable) -> void:
	if control == null:
		if callback.is_valid():
			callback.call()
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(control, "modulate:a", 0.0, DURATION)
	tween.parallel().tween_property(control, "scale", Vector2(0.98, 0.98), DURATION)
	tween.finished.connect(func():
		control.visible = false
		if callback.is_valid():
			callback.call()
	)
