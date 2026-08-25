class_name BuildSystem
extends Node
## Autoload "Build". Reach via BuildSystem.instance.
##
## Owns the block palette, the chunk grid, placement validation, and the
## hot/cold transition. Per-player build cursors live in BuildController and
## call into here; this node is the single authority on what exists.

static var instance: BuildSystem

signal block_placed(block_id: StringName, pos: Vector3, player_id: int)
signal block_removed(block_id: StringName, pos: Vector3, player_id: int)
signal palette_changed()

## Distance from any player at which a chunk becomes HOT.
@export var hot_radius: float = 40.0
## Chunks stay hot for this long after their last edit, regardless of distance.
@export var hot_grace_seconds: float = 5.0
@export var max_blocks_per_player: int = 2000

## Single source of truth for kid-safety block budget. main.gd and
## GameplayRuntime both reference this so the two callers cannot drift.
## Parent sessions override at the GameplayRuntime level.
const DEFAULT_KID_BLOCK_BUDGET := 800
## Hard cap on records in a single 32 m chunk. A crafted save with 10k blocks
## stacked at one coordinate is what turns a ~1 MB file into an OOM.
const MAX_BLOCKS_PER_CHUNK := 4096
## Hard cap on live chunks. pos is clamped to +/-100000 and CHUNK_SIZE is 32,
## so an unbounded save could create ~10^11 chunk coords; _update_chunk_states
## then scans every one of them at 120 Hz, forever.
const MAX_CHUNKS := 4096

var world_root: Node3D
var palette: Array[StringName] = []

var _scenes: Dictionary = {}      # block_id -> PackedScene
var _meshes: Dictionary = {}      # block_id -> Mesh          (for cold bake)
var _shapes: Dictionary = {}      # block_id -> Shape3D       (for cold bake)
## Slightly smaller copies used ONLY for placement validation. Godot's
## PhysicsShapeQueryParameters3D.margin is a solver inflation value, not a
## shrink, and a negative margin is undefined — under Jolt it is effectively
## ignored. Without a genuinely smaller query shape, a block placed flush
## against its neighbour reports a touching contact and placement is refused,
## which breaks the core verb of a building game.
var _query_shapes: Dictionary = {}
var _materials: Dictionary = {}   # block_id -> Material
## block_id -> plain metadata Dictionary.
## NOT the PlaceableComponent node: that node belongs to the throwaway probe
## instance and is freed right after registration. Caching the node gives you
## "Trying to assign invalid previously freed instance" the first time anything
## validates a placement. Copy the data out, drop the node.
var _placeables: Dictionary = {}

var _chunks: Dictionary = {}      # Vector3i -> BuildChunk
var _edit_time: Dictionary = {}   # Vector3i -> float (msec)
var _per_player_count: Dictionary = {}

var _blocks_total: int = 0

## Authoritative occupancy index, independent of the physics world.
## Two reasons this exists rather than relying on intersect_shape alone:
##   1. cold chunks rebuild deferred, so a block placed earlier THIS FRAME has
##      no collider yet and a physics query cannot see it.
##   2. two players running can_place in the same _physics_process both pass,
##      then both place — the classic shared-world double-place race.
var _occupied: Dictionary = {}
const OCCUPANCY_CELL := 0.5


static func _occ_key(pos: Vector3) -> Vector3i:
	return Vector3i(
		roundi(pos.x / OCCUPANCY_CELL),
		roundi(pos.y / OCCUPANCY_CELL),
		roundi(pos.z / OCCUPANCY_CELL))


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE


func set_world_root(root: Node3D) -> void:
	world_root = root


## Registers one placeable prefab. Extracts the mesh/shape once so the cold bake
## never has to instantiate the scene again.
func register_block(scene: PackedScene) -> bool:
	if scene == null:
		return false
	var probe := scene.instantiate()
	if probe == null:
		return false

	var placeable := _find_placeable(probe)
	if placeable == null or placeable.block_id == &"":
		push_error("BuildSystem.register_block: scene has no PlaceableComponent with a block_id")
		probe.queue_free()
		return false

	var id := placeable.block_id
	if _scenes.has(id):
		push_warning("BuildSystem: duplicate block_id '%s' ignored" % id)
		probe.queue_free()
		return false

	_scenes[id] = scene
	_placeables[id] = {
		"block_id": id,
		"display_name": placeable.display_name,
		"category": placeable.category,
		"footprint": placeable.footprint,
		"default_snap": int(placeable.default_snap),
		"yaw_step_degrees": placeable.yaw_step_degrees,
		"cost": placeable.cost,
		"requires_clear_space": placeable.requires_clear_space,
	}

	var mi := _find_node_of_type(probe, "MeshInstance3D") as MeshInstance3D
	if mi:
		_meshes[id] = mi.mesh
		# material_override is null on most authored meshes — the material
		# normally lives on the mesh surface. Falling back is what stops cold
		# chunks rendering untextured.
		var src_mat: Material = mi.material_override
		if src_mat == null:
			src_mat = mi.get_active_material(0)
		if src_mat:
			src_mat = src_mat.duplicate()
		_materials[id] = src_mat
	var cs := _find_node_of_type(probe, "CollisionShape3D") as CollisionShape3D
	if cs:
		_shapes[id] = cs.shape
		_query_shapes[id] = _shrunk(cs.shape)

	palette.append(id)
	probe.queue_free()
	palette_changed.emit()
	return true


func _find_placeable(n: Node) -> PlaceableComponent:
	if n is PlaceableComponent:
		return n
	for child in n.get_children():
		var found := _find_placeable(child)
		if found:
			return found
	return null


func _find_node_of_type(n: Node, type_name: String) -> Node:
	if n.is_class(type_name):
		return n
	for child in n.get_children():
		var found := _find_node_of_type(child, type_name)
		if found:
			return found
	return null


## Returns a copy of the shape ~4 cm smaller in every direction, so two blocks
## sharing a face do not register as overlapping during validation.
static func _shrunk(shape: Shape3D, amount: float = 0.04) -> Shape3D:
	if shape is BoxShape3D:
		var b := (shape as BoxShape3D).duplicate() as BoxShape3D
		b.size = Vector3(
			maxf(0.01, b.size.x - amount),
			maxf(0.01, b.size.y - amount),
			maxf(0.01, b.size.z - amount))
		return b
	if shape is SphereShape3D:
		var s := (shape as SphereShape3D).duplicate() as SphereShape3D
		s.radius = maxf(0.01, s.radius - amount * 0.5)
		return s
	if shape is CapsuleShape3D:
		var c := (shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		c.radius = maxf(0.01, c.radius - amount * 0.5)
		c.height = maxf(0.02, c.height - amount)
		return c
	if shape is CylinderShape3D:
		var cy := (shape as CylinderShape3D).duplicate() as CylinderShape3D
		cy.radius = maxf(0.01, cy.radius - amount * 0.5)
		cy.height = maxf(0.02, cy.height - amount)
		return cy
	# Unknown shape type: fall back to the real shape. Placement will be
	# conservative (flush placement refused) rather than silently permissive.
	return shape


func scene_for(id: StringName) -> PackedScene:
	return _scenes.get(id, null)


func mesh_for(id: StringName) -> Mesh:
	return _meshes.get(id, null)


func shape_for(id: StringName) -> Shape3D:
	return _shapes.get(id, null)


func material_for(id: StringName) -> Material:
	return _materials.get(id, null)


## Plain metadata Dictionary, never a live node. See _placeables above.
func placeable_for(id: StringName) -> Dictionary:
	return _placeables.get(id, {})


func knows(id: StringName) -> bool:
	return _scenes.has(id)


## --- Placement --------------------------------------------------------------

## Shape query, NOT a persistent Area3D. One-shot, no frame of lag, no extra
## node in the tree, and it returns an immediate boolean.
func can_place(id: StringName, xform: Transform3D) -> bool:
	if not knows(id):
		return false
	var meta: Dictionary = _placeables[id]
	if not meta.get("requires_clear_space", true):
		return true

	# Occupancy first: catches same-frame placements the physics world has not
	# rebuilt collision for yet, and catches the same-tick double-place race.
	if _occupied.has(_occ_key(xform.origin)):
		return false
	# FAIL CLOSED. This used to `return true` when the shape or world_root was
	# missing, which meant a mis-authored block or an unwired world validated
	# every placement unconditionally — you could build inside players and
	# terrain and nothing would complain.
	var shape: Shape3D = _query_shapes.get(id, null)
	if shape == null:
		push_error("BuildSystem.can_place: no query shape for '%s' — refusing" % id)
		return false
	if world_root == null:
		push_error("BuildSystem.can_place: world_root unset — refusing")
		return false

	var space := world_root.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape          # already shrunk; see _query_shapes
	params.transform = xform
	params.collision_mask = Layers.BUILD_BLOCKERS
	params.collide_with_bodies = true
	params.collide_with_areas = false

	return space.intersect_shape(params, 1).is_empty()


func place(id: StringName, xform: Transform3D, player_id: int,
		tint: Color = Color.WHITE, validate: bool = true) -> bool:
	if validate and not can_place(id, xform):
		return false
	if _count_for(player_id) >= max_blocks_per_player:
		push_warning("BuildSystem: player %d hit the block budget" % player_id)
		return false

	var rec := {
		"id": String(id),
		"by": player_id,
		"pos": xform.origin,
		"rot": xform.basis.get_euler(),
		"tint": tint,
	}
	var c := _chunk_at(xform.origin, true)
	if c == null:
		return false
	if c.records.size() >= MAX_BLOCKS_PER_CHUNK:
		push_warning("BuildSystem: chunk %s is full (%d)" % [c.coord, MAX_BLOCKS_PER_CHUNK])
		return false
	c.add_record(rec)
	_occupied[_occ_key(xform.origin)] = true
	_edit_time[c.coord] = float(Time.get_ticks_msec())
	_per_player_count[player_id] = _count_for(player_id) + 1
	_blocks_total += 1
	block_placed.emit(id, xform.origin, player_id)
	return true


## Bulk placement for the loader. Groups records by chunk and bakes each chunk
## ONCE. Never call place() in a loop for a whole save file.
## `credit_player` is the player charged for the whole batch — the per-record
## "by" field is display attribution only and is NOT trusted for budget, because
## a crafted save can otherwise pin every other player at their block cap and
## lock them out of building for the rest of the session.
func place_bulk(records: Array, credit_player: int) -> int:
	if world_root == null:
		return 0
	var by_chunk: Dictionary = {}
	for rec in records:
		var coord := BuildChunk.coord_for(rec["pos"])
		if not by_chunk.has(coord):
			by_chunk[coord] = []
		by_chunk[coord].append(rec)

	var placed := 0
	for coord in by_chunk:
		var batch: Array = by_chunk[coord]
		if batch.size() > MAX_BLOCKS_PER_CHUNK:
			push_error("BuildSystem.place_bulk: chunk %s has %d records (cap %d) — truncating"
				% [coord, batch.size(), MAX_BLOCKS_PER_CHUNK])
			batch = batch.slice(0, MAX_BLOCKS_PER_CHUNK)
		var c := _chunk_at(Vector3(coord) * BuildChunk.CHUNK_SIZE + Vector3.ONE, true)
		if c == null:
			continue
		c.add_records(batch)
		c.flush_cold()
		for rec in batch:
			_occupied[_occ_key(rec["pos"])] = true
		_edit_time[c.coord] = float(Time.get_ticks_msec())
		placed += batch.size()

	_per_player_count[credit_player] = _count_for(credit_player) + placed
	_blocks_total += placed
	return placed


func remove_at(pos: Vector3, player_id: int, radius: float = 0.6) -> bool:
	var c := _chunk_at(pos, false)
	if c == null:
		return false
	for i in range(c.records.size() - 1, -1, -1):
		var rec: Dictionary = c.records[i]
		if (rec["pos"] as Vector3).distance_to(pos) <= radius:
			var id := StringName(rec["id"])
			var owner_id: int = rec.get("by", -1)
			_occupied.erase(_occ_key(rec["pos"]))
			c.remove_record(i)
			_edit_time[c.coord] = float(Time.get_ticks_msec())
			_per_player_count[owner_id] = maxi(0, _count_for(owner_id) - 1)
			_blocks_total -= 1
			block_removed.emit(id, pos, player_id)
			return true
	return false


func _count_for(player_id: int) -> int:
	return _per_player_count.get(player_id, 0)


func _chunk_at(pos: Vector3, create: bool) -> BuildChunk:
	var coord := BuildChunk.coord_for(pos)
	if _chunks.has(coord):
		return _chunks[coord]
	if not create or world_root == null:
		return null
	if _chunks.size() >= MAX_CHUNKS:
		push_error("BuildSystem: chunk cap %d reached, refusing new chunk at %s"
			% [MAX_CHUNKS, coord])
		return null
	var c := BuildChunk.new()
	world_root.add_child(c)
	c.setup(coord)
	_chunks[coord] = c
	return c


## --- Hot / cold -------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	_update_chunk_states()


func _update_chunk_states() -> void:
	var reg := PlayerRegistrySystem.instance
	if reg == null:
		return
	var positions: Array[Vector3] = []
	for p in reg.profiles():
		if is_instance_valid(p.body):
			positions.append((p.body as Node3D).global_position)

	var now := float(Time.get_ticks_msec())
	for coord in _chunks:
		var c: BuildChunk = _chunks[coord]
		var centre := Vector3(coord) * BuildChunk.CHUNK_SIZE \
			+ Vector3.ONE * (BuildChunk.CHUNK_SIZE * 0.5)

		var near := false
		for pos in positions:
			if pos.distance_to(centre) < hot_radius:
				near = true
				break

		var recently_edited: bool = (now - float(_edit_time.get(coord, 0.0))) \
			< hot_grace_seconds * 1000.0

		# NOTE: the load radius is the UNION of all players' radii. Four players
		# in four corners means four resident hot sets, not one. That is the
		# fundamental difference from a single-player streamer.
		if near or recently_edited:
			c.go_hot()
		else:
			c.go_cold()


## --- Serialisation ----------------------------------------------------------

func all_records() -> Array:
	var out: Array = []
	for coord in _chunks:
		out.append_array((_chunks[coord] as BuildChunk).records)
	return out


func clear_all() -> void:
	for coord in _chunks:
		var c: BuildChunk = _chunks[coord]
		c.records.clear()
		c.go_hot(true)
		if is_instance_valid(c):
			c.queue_free()
	_chunks.clear()
	_edit_time.clear()
	_per_player_count.clear()
	_occupied.clear()
	_blocks_total = 0


func stats() -> Dictionary:
	var hot := 0
	for coord in _chunks:
		if (_chunks[coord] as BuildChunk).is_hot:
			hot += 1
	return {
		"palette": palette.size(),
		"chunks": _chunks.size(),
		"chunks_hot": hot,
		"blocks": _blocks_total,
	}
