class_name DebrisBudget
extends Node
## Autoload "Debris". Reach via DebrisBudget.instance.
##
## A global ring buffer of live debris bodies. Without this, one enthusiastic
## player with a rocket launcher ends the frame budget for the other three.
##
## Two rules that matter more than the cap itself:
##   - debris collides with the STATIC world only (Layers.DEBRIS_MASK).
##     Debris-vs-debris is quadratic and it is what actually kills framerate.
##   - debris despawns on a timer, fading out, and is never allowed to persist.

static var instance: DebrisBudget

@export var max_live: int = 50
@export var lifetime_seconds: float = 4.0
@export var fade_seconds: float = 0.8

var _live: Array[RigidBody3D] = []
var _spawned_total: int = 0
var _culled_total: int = 0


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Configures and adopts a body as debris. Caller owns parenting.
func adopt(body: RigidBody3D, impulse: Vector3 = Vector3.ZERO) -> void:
	body.collision_layer = Layers.DEBRIS
	body.collision_mask = Layers.DEBRIS_MASK
	body.can_sleep = true
	body.contact_monitor = false
	if impulse != Vector3.ZERO:
		body.apply_central_impulse(impulse)

	_live.append(body)
	_spawned_total += 1
	_enforce_cap()

	var tree := get_tree()
	if tree:
		var t := tree.create_timer(lifetime_seconds)
		t.timeout.connect(_retire.bind(body))


func _enforce_cap() -> void:
	while _live.size() > max_live:
		var oldest: RigidBody3D = _live[0]
		_live.remove_at(0)
		_culled_total += 1
		if is_instance_valid(oldest):
			oldest.queue_free()


func _retire(body: RigidBody3D) -> void:
	_live.erase(body)
	if not is_instance_valid(body):
		return
	# DO NOT tween the body's scale. Scaling a physics body re-bakes its
	# collision shape every frame of the tween (96 times at a 120 Hz tick), and
	# as the scale approaches zero Jolt emits degenerate-shape errors and can
	# produce NaN transforms that propagate into contacts.
	# Freeze the body, then shrink only the visual child.
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	var visual := _first_mesh(body)
	if visual:
		var tw := body.create_tween()
		tw.tween_property(visual, "scale", Vector3.ZERO, fade_seconds)
		tw.tween_callback(body.queue_free)
	else:
		body.queue_free()


static func _first_mesh(n: Node) -> Node3D:
	for child in n.get_children():
		if child is MeshInstance3D:
			return child as Node3D
		var found := _first_mesh(child)
		if found:
			return found
	return null


func live_count() -> int:
	_live = _live.filter(func(b): return is_instance_valid(b))
	return _live.size()


func stats() -> Dictionary:
	return {
		"live": live_count(),
		"cap": max_live,
		"spawned_total": _spawned_total,
		"culled_total": _culled_total,
	}
