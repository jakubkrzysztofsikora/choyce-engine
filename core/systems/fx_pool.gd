class_name FXPool
extends Node
## Autoload "FX". Reach via FXPool.instance.
##
## Pools GPUParticles3D emitter scenes by PackedScene. A sandbox generates FX in
## bursts (a structure collapsing is 40 impacts in 200 ms); instantiating per
## event is a guaranteed frame spike, so instances are recycled instead.

static var instance: FXPool

@export var per_scene_pool_size: int = 12
## Emitters older than this are recycled even if still emitting.
@export var max_lifetime: float = 6.0

var _pools: Dictionary = {}    # PackedScene -> Array[Node3D]
var _cursor: Dictionary = {}   # PackedScene -> int
var _spawned_total: int = 0
var _recycled_total: int = 0
var _host: Node3D


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE


## FX must live in the same World3D as the gameplay. In split-screen the world
## is NOT the main window's world, so the host has to be handed to us.
func set_host(host: Node3D) -> void:
	_host = host


func spawn(scene: PackedScene, at: Vector3, normal: Vector3 = Vector3.UP) -> Node3D:
	if scene == null or _host == null or not is_instance_valid(_host):
		return null

	if not _pools.has(scene):
		_pools[scene] = []
		_cursor[scene] = 0

	var pool: Array = _pools[scene]
	var node: Node3D = null

	if pool.size() < per_scene_pool_size:
		node = scene.instantiate() as Node3D
		if node == null:
			return null
		_host.add_child(node)
		pool.append(node)
		_spawned_total += 1
	else:
		var i: int = _cursor[scene]
		node = pool[i]
		_cursor[scene] = (i + 1) % pool.size()
		_recycled_total += 1
		if not is_instance_valid(node):
			node = scene.instantiate() as Node3D
			_host.add_child(node)
			pool[i] = node

	node.global_position = at
	if normal.length_squared() > 0.001 and absf(normal.dot(Vector3.UP)) < 0.999:
		node.look_at(at + normal, Vector3.UP)
	_restart(node)
	return node


func _restart(node: Node) -> void:
	if node is GPUParticles3D:
		var p := node as GPUParticles3D
		p.emitting = false
		p.restart()
		p.emitting = true
	for child in node.get_children():
		_restart(child)


func stats() -> Dictionary:
	return {
		"pools": _pools.size(),
		"instantiated": _spawned_total,
		"recycled": _recycled_total,
		"host_valid": is_instance_valid(_host),
	}
