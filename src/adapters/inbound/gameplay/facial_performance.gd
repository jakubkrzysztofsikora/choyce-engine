## Reusable lightweight facial-performance layer for imported character rigs
## that do not provide blend-shapes. It is intentionally mesh-based and local:
## no external service, no unsafe generated content, and no permanent talking.
class_name FacialPerformance
extends Node3D

enum Emotion { NEUTRAL, HAPPY, FOCUSED, SURPRISED, HURT, ANGRY }

var _left_eye: MeshInstance3D
var _right_eye: MeshInstance3D
var _left_brow: MeshInstance3D
var _right_brow: MeshInstance3D
var _mouth: MeshInstance3D
var _speech_remaining := 0.0
var _emotion := Emotion.NEUTRAL
var _emotion_remaining := 0.0
var _elapsed := 0.0
var _blink_phase := 0.0
var _show_eyes := true
var _show_brows := true
var _mouth_width := 0.16
var _mouth_height := 0.026


## Imported character clips animate the head bone independently of the model
## root. A face parented to that root becomes a detached mask during idle/walk
## poses, so always prefer a BoneAttachment3D for humanoid rigs.
static func attach_kenney_humanoid(model: Node3D) -> FacialPerformance:
	return attach_to_bone(model, "head", Vector3(0.0, 0.167, 0.0), 0.202)


static func attach_to_bone(
	model: Node3D,
	bone_name: String,
	face_origin: Vector3,
	front_z: float,
	visual_scale: float = 1.0,
	show_eyes: bool = true,
	show_brows: bool = true
) -> FacialPerformance:
	if model == null:
		push_warning("FacialPerformance.attach_to_bone needs a model node")
		return null
	var face := FacialPerformance.new()
	face.name = "FacialPerformance"
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null and skeleton.find_bone(bone_name) >= 0:
		var anchor := BoneAttachment3D.new()
		anchor.name = "FaceHeadAnchor"
		anchor.bone_name = bone_name
		skeleton.add_child(anchor)
		anchor.add_child(face)
	else:
		# Keep the fallback expressive, but only use the model root when no rig
		# exists (primitive NPCs and creatures).
		model.add_child(face)
	face.setup_face(face_origin, front_z, visual_scale, show_eyes, show_brows)
	return face


## `face_origin` is the local centre of the head; `front_z` is the feature
## plane offset from that centre. This lets human rigs (front +Z before their
## scene rotation) and creatures (front -Z) share the same animator.
func setup_face(
	face_origin: Vector3,
	front_z: float,
	visual_scale: float = 1.0,
	show_eyes: bool = true,
	show_brows: bool = true
) -> FacialPerformance:
	position = face_origin
	scale = Vector3.ONE * visual_scale
	_show_eyes = show_eyes
	_show_brows = show_brows
	_build_features(front_z)
	return self


func speak_for(seconds: float, emotion: int = Emotion.HAPPY) -> void:
	_speech_remaining = maxf(_speech_remaining, maxf(seconds, 0.35))
	set_emotion(emotion, _speech_remaining + 0.25)


func set_emotion(emotion: int, seconds: float = 0.55) -> void:
	_emotion = clampi(emotion, Emotion.NEUTRAL, Emotion.ANGRY)
	_emotion_remaining = maxf(seconds, 0.05)


func _build_features(front_z: float) -> void:
	var dark := _face_material(Color(0.035, 0.024, 0.018))
	var eye_white := _face_material(Color(0.96, 0.96, 0.90))
	var iris := _face_material(Color(0.05, 0.08, 0.12))
	if _show_eyes:
		for side in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			eye.name = "FaceEyeL" if side < 0.0 else "FaceEyeR"
			var eye_mesh := SphereMesh.new()
			eye_mesh.radius = 0.052
			eye_mesh.height = 0.096
			eye.mesh = eye_mesh
			eye.material_override = eye_white
			eye.position = Vector3(side * 0.095, 0.045, front_z)
			add_child(eye)
			var pupil := MeshInstance3D.new()
			var pupil_mesh := SphereMesh.new()
			pupil_mesh.radius = 0.025
			pupil_mesh.height = 0.03
			pupil.mesh = pupil_mesh
			pupil.material_override = iris
			pupil.position = Vector3(0.0, 0.0, signf(front_z) * 0.045)
			eye.add_child(pupil)
			if side < 0.0:
				_left_eye = eye
			else:
				_right_eye = eye
	if _show_brows:
		for side in [-1.0, 1.0]:
			var brow := MeshInstance3D.new()
			brow.name = "FaceBrowL" if side < 0.0 else "FaceBrowR"
			var brow_mesh := BoxMesh.new()
			brow_mesh.size = Vector3(0.12, 0.018, 0.018)
			brow.mesh = brow_mesh
			brow.material_override = dark
			brow.position = Vector3(side * 0.095, 0.125, front_z)
			brow.rotation.z = -side * 0.12
			add_child(brow)
			if side < 0.0:
				_left_brow = brow
			else:
				_right_brow = brow
	_mouth = MeshInstance3D.new()
	_mouth.name = "FaceMouth"
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(_mouth_width, _mouth_height, 0.018)
	_mouth.mesh = mouth_mesh
	_mouth.material_override = dark
	_mouth.position = Vector3(0.0, -0.085, front_z)
	add_child(_mouth)


func _face_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material


func _process(delta: float) -> void:
	_elapsed += delta
	_speech_remaining = maxf(_speech_remaining - delta, 0.0)
	_emotion_remaining = maxf(_emotion_remaining - delta, 0.0)
	if _emotion_remaining <= 0.0:
		_emotion = Emotion.NEUTRAL
	_update_blink()
	_update_expression()


func _update_blink() -> void:
	# Two short staggered blinks per 5.6 seconds keep faces alive without the
	# unsettling permanent-motion look of the old floating-character treatment.
	_blink_phase = fmod(_elapsed + float(get_instance_id() % 37) * 0.17, 5.6)
	var closed := _blink_phase < 0.11 or (_blink_phase > 0.17 and _blink_phase < 0.24)
	var height := 0.16 if closed else 1.0
	if _left_eye != null:
		_left_eye.scale.y = height
	if _right_eye != null:
		_right_eye.scale.y = height


func _update_expression() -> void:
	if _mouth == null:
		return
	var speaking := _speech_remaining > 0.0
	var mouth_open := 0.62 + sin(_elapsed * 18.0) * 0.38 if speaking else 0.0
	var mouth_y_scale := 1.0
	var mouth_x_scale := 1.0
	var brow_y := 0.125
	var brow_tilt := 0.12
	match _emotion:
		Emotion.HAPPY:
			mouth_x_scale = 1.2
			brow_y = 0.14
		Emotion.FOCUSED:
			mouth_x_scale = 0.85
			brow_y = 0.108
			brow_tilt = 0.30
		Emotion.SURPRISED:
			mouth_x_scale = 0.58
			mouth_y_scale = 2.3
			brow_y = 0.17
		Emotion.HURT:
			mouth_x_scale = 0.70
			brow_y = 0.102
			brow_tilt = 0.36
		Emotion.ANGRY:
			mouth_x_scale = 0.78
			brow_y = 0.102
			brow_tilt = 0.52
	if speaking:
		mouth_y_scale = maxf(mouth_y_scale, 1.2 + mouth_open * 2.0)
		mouth_x_scale *= 0.92 + mouth_open * 0.15
	_mouth.scale = Vector3(mouth_x_scale, mouth_y_scale, 1.0)
	if _left_brow != null:
		_left_brow.position.y = brow_y
		_left_brow.rotation.z = brow_tilt
	if _right_brow != null:
		_right_brow.position.y = brow_y
		_right_brow.rotation.z = -brow_tilt
