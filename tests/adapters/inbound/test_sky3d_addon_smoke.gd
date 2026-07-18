## Isolated compatibility smoke check for the locally installed MIT Sky3D addon.
extends SceneTree

const Sky3DScript = preload("res://addons/sky_3d/src/Sky3D.gd")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run() -> void:
	var sky := Sky3DScript.new() as WorldEnvironment
	get_root().add_child(sky)
	await process_frame
	_assert(sky != null and sky.environment != null, "Sky3D creates an Environment")
	_assert(sky != null and sky.get_node_or_null("SunLight") is DirectionalLight3D, "Sky3D creates its sun")
	_assert(sky != null and sky.get_node_or_null("MoonLight") is DirectionalLight3D, "Sky3D creates its moon")
	_assert(sky != null and sky.get_node_or_null("SkyDome") != null, "Sky3D creates the atmosphere/cloud dome")
	if sky != null:
		sky.set("current_time", 22.0)
		await process_frame
		_assert(bool(sky.call("is_night")), "Sky3D reports night after a time transition")
		sky.queue_free()
	quit(_exit_code)
