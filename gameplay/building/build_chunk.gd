class_name BuildChunk
extends Node3D
## A fixed spatial cube of player-placed blocks with two representations.
##
## HOT  : one node per block. Full collision, health, interaction. Expensive.
## COLD : blocks merged into one MultiMeshInstance3D per block type, plus one
##        StaticBody3D carrying merged box collision. Individual nodes freed.
##
## Spike A measured 3,230 draw calls for 200 individually-instanced boxes across
## 4 panes. Draw calls scale linearly with viewport count, so in split-screen the
## hot/cold transition is not an optimisation you add later — it is the system
## that decides whether the game runs at all. Build it early.

const CHUNK_SIZE := 32.0

var coord: Vector3i = Vector3i.ZERO
var records: Array[Dictionary] = []
var is_hot: bool = false

var _hot_root: Node3D
var _cold_root: Node3D
var _cold_body: StaticBody3D
var _multimeshes: Dictionary = {}   # block_id String -> MultiMeshInstance3D


static func coord_for(pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(pos.x / CHUNK_SIZE),
		floori(pos.y / CHUNK_SIZE),
		floori(pos.z / CHUNK_SIZE))


func setup(p_coord: Vector3i) -> void:
	coord = p_coord
	name = "Chunk_%d_%d_%d" % [coord.x, coord.y, coord.z]
	_hot_root = Node3D.new()
	_hot_root.name = "Hot"
	add_child(_hot_root)
	_cold_root = Node3D.new()
	_cold_root.name = "Cold"
	add_child(_cold_root)


var _cold_dirty: bool = false


func add_record(rec: Dictionary) -> void:
	records.append(rec)
	if is_hot:
		_instance_one(rec)
	else:
		_mark_dirty()


## Bulk insert. The loader MUST use this.
## Per-record _rebuild_cold() is O(n^2) in node allocations, and because
## queue_free() is deferred to end of frame, a single-frame load holds every
## intermediate node resident at once. ~10k records in one chunk is ~50M live
## CollisionShape3D nodes: OOM from a ~1 MB save file.
func add_records(recs: Array) -> void:
	for rec in recs:
		records.append(rec)
	if is_hot:
		for rec in recs:
			_instance_one(rec)
	else:
		_mark_dirty()


func remove_record(index: int) -> void:
	if index < 0 or index >= records.size():
		return
	records.remove_at(index)
	if is_hot:
		_remove_hot_node_at(index)
	else:
		_mark_dirty()


## Free the one node instead of rebuilding the chunk. go_hot(true) used to
## destroy and re-instantiate every block in a 32 m chunk to delete one, which
## also discarded the runtime state of every survivor.
func _remove_hot_node_at(index: int) -> void:
	if _hot_root == null:
		return
	if index < _hot_root.get_child_count():
		var node := _hot_root.get_child(index)
		_hot_root.remove_child(node)
		node.queue_free()
	else:
		go_hot(true)


## Coalesce cold rebuilds to one per frame instead of one per edit.
func _mark_dirty() -> void:
	if _cold_dirty:
		return
	_cold_dirty = true
	_deferred_rebuild.call_deferred()


func _deferred_rebuild() -> void:
	_cold_dirty = false
	if not is_hot:
		_rebuild_cold()


## Rebuild now, ignoring the dirty flag. Used at the end of a bulk load.
func flush_cold() -> void:
	_cold_dirty = false
	if not is_hot:
		_rebuild_cold()


func block_count() -> int:
	return records.size()


func go_hot(force: bool = false) -> void:
	if is_hot and not force:
		return
	is_hot = true
	_clear(_cold_root)
	_multimeshes.clear()
	_cold_body = null
	_clear(_hot_root)
	for rec in records:
		_instance_one(rec)


func go_cold(force: bool = false) -> void:
	if not is_hot and not force:
		return
	is_hot = false
	_clear(_hot_root)
	_rebuild_cold()


func _clear(root: Node) -> void:
	if root == null:
		return
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()


func _instance_one(rec: Dictionary) -> void:
	var sys := BuildSystem.instance
	if sys == null:
		return
	var scene := sys.scene_for(StringName(rec["id"]))
	if scene == null:
		return
	var node := scene.instantiate() as Node3D
	if node == null:
		return
	_hot_root.add_child(node)
	node.global_position = rec["pos"]
	node.global_rotation = rec["rot"]

	var pb := Components.get_comp(node, Components.PLACED_BLOCK) as PlacedBlockComponent
	if pb:
		pb.block_id = StringName(rec["id"])
		pb.placed_by_player = rec.get("by", -1)
		pb.chunk_coord = coord
		pb.tint = rec.get("tint", Color.WHITE)


## Cold bake: N draw calls where N = distinct block types in this chunk,
## instead of one per block. Collision merges into a single StaticBody3D.
func _rebuild_cold() -> void:
	_clear(_cold_root)
	_multimeshes.clear()

	var sys := BuildSystem.instance
	if sys == null or records.is_empty():
		return

	var by_type: Dictionary = {}
	for rec in records:
		var id: String = rec["id"]
		if not by_type.has(id):
			by_type[id] = []
		by_type[id].append(rec)

	_cold_body = StaticBody3D.new()
	_cold_body.name = "ColdCollision"
	_cold_body.collision_layer = Layers.BUILD_PLACED
	_cold_body.collision_mask = 0
	_cold_root.add_child(_cold_body)

	for id in by_type:
		var list: Array = by_type[id]
		var mesh := sys.mesh_for(StringName(id))
		var shape := sys.shape_for(StringName(id))
		if mesh == null:
			continue

		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var rec: Dictionary = list[i]
			var xform := Transform3D(Basis.from_euler(rec["rot"]), rec["pos"])
			mm.set_instance_transform(i, xform)
			mm.set_instance_color(i, rec.get("tint", Color.WHITE))

			if shape:
				var cs := CollisionShape3D.new()
				cs.shape = shape
				cs.transform = xform
				_cold_body.add_child(cs)

		mmi.multimesh = mm
		# MultiMesh instance colours only reach ALBEDO if the material opts in.
		# Without this the tint applies while a chunk is HOT and silently
		# vanishes the moment it goes COLD — a visible pop at the hot radius.
		var cold_mat := sys.material_for(StringName(id))
		if cold_mat is StandardMaterial3D:
			(cold_mat as StandardMaterial3D).vertex_color_use_as_albedo = true
		mmi.material_override = cold_mat
		_cold_root.add_child(mmi)
		_multimeshes[id] = mmi


func stats() -> Dictionary:
	return {
		"coord": coord,
		"blocks": records.size(),
		"hot": is_hot,
		"hot_nodes": _hot_root.get_child_count() if _hot_root else 0,
		"cold_multimeshes": _multimeshes.size(),
	}
