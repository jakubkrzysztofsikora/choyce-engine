## Floating pickup orb. Spawned at defeated-enemy positions for the
## kid to walk into. Auto-rotates + bobs for visibility. On player
## body_entered, emits the picked_up signal with item_id + quantity,
## then despawns.
##
## Kid-friendly behaviour:
## - Bright tinted cube with emission, rotates 1 turn/sec.
## - Bobs ±0.15m at 1.5Hz so the eye catches it.
## - Magnet-style: when player is within 1.5m, pickup glides toward
##   them. (Roblox/Minecraft xp orb pattern.)
class_name LootPickup
extends Area3D


signal picked_up(item_id: String, quantity: int)


const ROT_SPEED := TAU                ## radians per second
const BOB_AMPLITUDE := 0.15
const BOB_FREQUENCY := 1.5
const MAGNET_RADIUS := 1.5
const MAGNET_SPEED := 8.0
const RARITY_COLORS := {
	"coin": Color(1.0, 0.85, 0.25),
	"slime_gel": Color(0.4, 0.85, 0.4),
	"spring_coil": Color(0.95, 0.45, 0.7),
	"ore_iron": Color(0.78, 0.78, 0.85),
	"wood_oak": Color(0.58, 0.38, 0.20),
	"star": Color(1.0, 0.95, 0.6),
}


var item_id: String
var quantity: int
var _bob_time: float = 0.0
var _base_y: float = 0.0
var _mesh: MeshInstance3D
var _player_ref: Node3D


func setup(p_item_id: String, p_quantity: int, p_player: Node3D = null) -> LootPickup:
	item_id = p_item_id
	quantity = maxi(p_quantity, 1)
	_player_ref = p_player
	return self


func _ready() -> void:
	_base_y = global_position.y
	body_entered.connect(_on_body_entered)
	_build_visuals()


func _build_visuals() -> void:
	var color: Color = RARITY_COLORS.get(item_id, Color(0.85, 0.85, 0.95))
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat
	add_child(_mesh)

	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.5
	shape.shape = s
	add_child(shape)


func _process(delta: float) -> void:
	_bob_time += delta
	# Magnet glide toward player when close.
	if _player_ref != null:
		var to_player := _player_ref.global_position - global_position
		var dist := to_player.length()
		if dist < MAGNET_RADIUS:
			var step := to_player.normalized() * MAGNET_SPEED * delta
			global_position += step
			_base_y = global_position.y
	# Rotate + bob the mesh, not the body, so collisions stay stable.
	if _mesh != null:
		_mesh.rotation.y += ROT_SPEED * delta
		_mesh.position.y = sin(_bob_time * TAU * BOB_FREQUENCY) * BOB_AMPLITUDE


func _on_body_entered(body: Node3D) -> void:
	if not (body is PlayerController):
		return
	# Disable monitoring immediately so a second body_entered in the
	# same physics frame can't double-credit (Adv 6 #7 bug fix).
	set_deferred("monitoring", false)
	picked_up.emit(item_id, quantity)
	# Brief shrink + fade then despawn. Guard against the node being
	# freed mid-tween if the runtime tears down (Adv 6 crash class).
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_mesh, "scale", Vector3.ZERO, 0.18)
	tween.tween_property(self, "global_position",
		body.global_position + Vector3(0, 1.4, 0), 0.18)
	await tween.finished
	if is_inside_tree():
		queue_free()
