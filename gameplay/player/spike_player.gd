extends CharacterBody3D
## Spike-grade player. Deliberately dumb: proves per-device input routing and
## per-pane camera follow. Gets replaced by a state-chart-driven controller.
## Builds its own visuals in code so the spike needs no authored .tscn.

const SPEED := 7.0
const ACCEL := 14.0
const JUMP_VELOCITY := 6.5

var profile: SandboxPlayerProfile
var device: int = -1
var _cam: Camera3D
var _cam_yaw: float = 0.0

@export var cam_distance: float = 7.0
@export var cam_height: float = 3.5


func _ready() -> void:
	collision_layer = Layers.PLAYER_BODY
	collision_mask = Layers.SOLID_WORLD | Layers.PROP_DYNAMIC | Layers.VEHICLE

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.4
	capsule_mesh.height = 1.8
	mesh.mesh = capsule_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = profile.colour if profile else Color.WHITE
	mat.roughness = 0.6
	mesh.material_override = mat
	mesh.name = "Body"
	add_child(mesh)

	# Nose cone so facing direction is readable in a screenshot.
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.25, 0.25, 0.5)
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 0.4, -0.55)
	nose.material_override = mat
	add_child(nose)


func setup(p: SandboxPlayerProfile) -> void:
	profile = p
	device = p.device_id
	if is_node_ready():
		var body := get_node_or_null("Body") as MeshInstance3D
		if body and body.material_override is StandardMaterial3D:
			(body.material_override as StandardMaterial3D).albedo_color = p.colour


func attach_camera(cam: Camera3D) -> void:
	_cam = cam


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var mp := MultiplayerInputSystem.instance
	if profile and mp and mp.is_action_just_pressed(device, &"jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var stick := Vector2.ZERO
	if profile and mp:
		stick = mp.get_vector(device, &"move_left", &"move_right", &"move_fwd", &"move_back")

	# Camera-relative movement using the camera's yaw only.
	var basis_yaw := Basis(Vector3.UP, _cam_yaw)
	var wish := basis_yaw * Vector3(stick.x, 0.0, stick.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	var target := wish * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)

	if wish.length_squared() > 0.01:
		var want_yaw := atan2(-wish.x, -wish.z)
		rotation.y = lerp_angle(rotation.y, want_yaw, 12.0 * delta)

	move_and_slide()
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if not is_instance_valid(_cam):
		return
	var focus := global_position + Vector3.UP * 1.2
	var offset := Basis(Vector3.UP, _cam_yaw) * Vector3(0, cam_height, cam_distance)
	_cam.global_position = _cam.global_position.lerp(focus + offset, clampf(10.0 * delta, 0.0, 1.0))
	_cam.look_at(focus, Vector3.UP)
