## Minecraft-lite block-grid manager. Lives under GameplayRuntime as
## a Node3D. Places and removes voxel cubes snapped to a 1m integer
## grid in world space.
##
## Per-cell map: Dictionary[Vector3i, MeshInstance3D]. Each placed
## block is its own StaticBody3D + BoxMesh + BoxShape3D — fine up
## to ~500 blocks per world (kid-friendly cap; bigger maps would
## need MultiMeshInstance3D + chunked StaticBody, deferred).
##
## Player input flow (PlayerController handles raycast + intent,
## then calls into this grid):
##   - place_block: snap to cell adjacent to hit, ground-up filling
##   - break_block: remove cell at the hit's collision point
class_name BuildGrid
extends Node3D


signal block_placed(cell: Vector3i, kind_id: String)
signal block_removed(cell: Vector3i, kind_id: String)
## Emitted when place_block fails. reason: "occupied" | "capacity" | "unknown_kind"
signal block_place_failed(reason: String)
## Mined block dropped an item the player can pick up.
## drop_item_id is BlockKind.drop_id (or block_id if drop_id empty); position
## is the world-space cell center the kid stood next to.
signal block_dropped_item(drop_item_id: String, position: Vector3)


const CELL_SIZE := 1.0
const MAX_BLOCKS_PER_WORLD := 500   ## kid-friendly cap per adversary review


var _cells: Dictionary = {}          ## Vector3i -> MeshInstance3D
var _kind_lookup: Dictionary = {}    ## block_id -> BlockKind
var _kind_for_cell: Dictionary = {}  ## Vector3i -> block_id (for events)


func _ready() -> void:
	for k in BlockKind.default_catalog():
		_kind_lookup[(k as BlockKind).block_id] = k


func block_count() -> int:
	return _cells.size()


func at_capacity() -> bool:
	return _cells.size() >= MAX_BLOCKS_PER_WORLD


## Snap an arbitrary world position to its cell coordinate.
func world_to_cell(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(world_pos.x / CELL_SIZE)),
		int(floor(world_pos.y / CELL_SIZE)),
		int(floor(world_pos.z / CELL_SIZE)),
	)


## Convert a cell back to the world-space center of that cell.
func cell_to_world(cell: Vector3i) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5) * CELL_SIZE,
		(float(cell.y) + 0.5) * CELL_SIZE,
		(float(cell.z) + 0.5) * CELL_SIZE,
	)


func has_block_at(cell: Vector3i) -> bool:
	return _cells.has(cell)


## Return the block_id at cell, or "" if empty. Used by spring-block
## launch detection in PlayerController.
func kind_at(cell: Vector3i) -> String:
	return String(_kind_for_cell.get(cell, ""))


## Place a block of the given kind at cell. Returns true on success.
## Fails if: cell occupied, capacity reached, or block_id unknown.
func place_block(cell: Vector3i, block_id: String) -> bool:
	if _cells.has(cell):
		block_place_failed.emit("occupied")
		return false
	if at_capacity():
		block_place_failed.emit("capacity")
		return false
	if not _kind_lookup.has(block_id):
		push_warning("BuildGrid: unknown block_id '%s'" % block_id)
		block_place_failed.emit("unknown_kind")
		return false

	var kind: BlockKind = _kind_lookup[block_id]
	var body := StaticBody3D.new()
	body.position = cell_to_world(cell)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = kind.color
	mat.roughness = 0.85
	if kind.emission > 0.0:
		mat.emission_enabled = true
		mat.emission = kind.color
		mat.emission_energy_multiplier = kind.emission
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
	col.shape = shape
	body.add_child(col)

	add_child(body)
	_cells[cell] = body
	_kind_for_cell[cell] = block_id
	block_placed.emit(cell, block_id)
	return true


## Remove a block at cell. Returns the block_id that was removed, or
## empty string if no block present. Also emits block_dropped_item so
## the gameplay runtime can credit the kid's inventory with the
## block's drop_id (or block_id if drop_id is empty). Closes the
## "wood_oak has no producer" loop-broken finding (Adv 4).
func break_block(cell: Vector3i) -> String:
	if not _cells.has(cell):
		return ""
	var body: Node = _cells[cell]
	var id := String(_kind_for_cell.get(cell, ""))
	_cells.erase(cell)
	_kind_for_cell.erase(cell)
	if body != null and is_instance_valid(body):
		body.queue_free()
	block_removed.emit(cell, id)
	# Drop a material item so mining feeds the gear loop.
	var kind: BlockKind = _kind_lookup.get(id, null)
	if kind != null:
		var drop_item := kind.drop_id if kind.drop_id != "" else id
		block_dropped_item.emit(drop_item, cell_to_world(cell))
	return id


## Clear all blocks. Called on session end.
func clear_all() -> void:
	for cell in _cells.keys():
		var body: Node = _cells[cell]
		if body != null and is_instance_valid(body):
			body.queue_free()
	_cells.clear()
	_kind_for_cell.clear()
