## Focused checks for the shared fallback facial-performance rig.
## Imported packs do not expose a consistent blend-shape API, so this verifies
## the local mesh layer all live character paths use instead.
extends SceneTree

const FacialPerformanceScript = preload("res://src/adapters/inbound/gameplay/facial_performance.gd")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run_tests() -> void:
	var visual := Node3D.new()
	get_root().add_child(visual)
	var face = FacialPerformanceScript.new()
	visual.add_child(face)
	face.setup_face(Vector3(0.0, 0.51, 0.0), 0.20)
	_assert(face.get_node_or_null("FaceEyeL") != null, "humanoid face has a left eye")
	_assert(face.get_node_or_null("FaceEyeR") != null, "humanoid face has a right eye")
	_assert(face.get_node_or_null("FaceMouth") != null, "face has an animated mouth")
	face.speak_for(1.0, FacialPerformance.Emotion.HAPPY)
	face._process(0.05)
	var mouth := face.get_node_or_null("FaceMouth") as MeshInstance3D
	_assert(face._speech_remaining > 0.0, "speech state is temporary and active")
	_assert(mouth != null and mouth.scale.y > 1.0, "speech visibly opens the mouth")
	face.set_emotion(FacialPerformance.Emotion.ANGRY, 0.4)
	face._process(0.01)
	_assert(face._emotion == FacialPerformance.Emotion.ANGRY, "emotion state is applied")
	visual.queue_free()
	quit(_exit_code)
