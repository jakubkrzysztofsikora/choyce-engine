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
var _history_stack: Array = []       ## Array of Dictionary {"action": "place"|"break", "cell": Vector3i, "block_id": String}


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
func place_block(cell: Vector3i, block_id: String, record_history: bool = true) -> bool:
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
	box.uv2_padding = 0.0
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = kind.color
	mat.roughness = 0.85
	# Per-block procedural noise texture. The kid sees distinct grass / dirt /
	# wood / brick / stone / sand surfaces instead of flat-colored cubes.
	mat.albedo_texture = _make_block_texture(block_id, kind)
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	if record_history:
		_history_stack.append({"action": "place", "cell": cell, "block_id": block_id})
	block_placed.emit(cell, block_id)
	return true


## Remove a block at cell. Returns the block_id that was removed, or
## empty string if no block present. Also emits block_dropped_item so
## the gameplay runtime can credit the kid's inventory with the
## block's drop_id (or block_id if drop_id is empty). Closes the
## "wood_oak has no producer" loop-broken finding (Adv 4).
func break_block(cell: Vector3i, record_history: bool = true) -> String:
	if not _cells.has(cell):
		return ""
	var body: Node = _cells[cell]
	var id := String(_kind_for_cell.get(cell, ""))
	_cells.erase(cell)
	_kind_for_cell.erase(cell)
	if body != null and is_instance_valid(body):
		body.queue_free()
	if record_history:
		_history_stack.append({"action": "break", "cell": cell, "block_id": id})
	block_removed.emit(cell, id)
	# Drop a material item so mining feeds the gear loop.
	var kind: BlockKind = _kind_lookup.get(id, null)
	if kind != null:
		var drop_item := kind.drop_id if kind.drop_id != "" else id
		block_dropped_item.emit(drop_item, cell_to_world(cell))
	return id


## Undo the last block placement or break action. Returns true if successful.
func undo_last_action() -> bool:
	if _history_stack.is_empty():
		return false
	var last_act: Dictionary = _history_stack.pop_back()
	match last_act["action"]:
		"place":
			var cell: Vector3i = last_act["cell"]
			break_block(cell, false)
			return true
		"break":
			var cell: Vector3i = last_act["cell"]
			var block_id: String = last_act["block_id"]
			place_block(cell, block_id, false)
			return true
	return false


## Clear all blocks. Called on session end.
func clear_all() -> void:
	_history_stack.clear()
	for cell in _cells.keys():
		var body: Node = _cells[cell]
		if body != null and is_instance_valid(body):
			body.queue_free()
	_cells.clear()
	_kind_for_cell.clear()


var _block_textures: Dictionary = {}

## Generate (and cache) a 64×64 procedural noise texture for a block kind.
## The noise is keyed off the block_id so grass / dirt / wood / brick / stone
## / sand each get a distinct surface pattern, eliminating the "every block is
## just a color cube" complaint. Procedural means no asset files required.
func _make_block_texture(block_id: String, kind: BlockKind) -> ImageTexture:
	if _block_textures.has(block_id):
		return _block_textures[block_id]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(kind.color)
	var noise := FastNoiseLite.new()
	# Seed noise from the block_id so different kinds get different patterns.
	var seed_val: int = 0
	for i in range(block_id.length()):
		seed_val = (seed_val * 31 + block_id.unicode_at(i)) & 0x7FFFFFFF
	noise.seed = seed_val
	# Per-family noise tuning so wood looks like wood-grain and stone looks
	# like stone-speckle, not all the same swirly blob.
	match kind.family:
		BlockKind.Family.WOOD:
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
			noise.frequency = 0.08
			noise.fractal_octaves = 3
		BlockKind.Family.BRICK:
			noise.noise_type = FastNoiseLite.TYPE_VALUE
			noise.frequency = 0.06
			noise.fractal_octaves = 2
		BlockKind.Family.NATURAL:
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
			noise.frequency = 0.12
			noise.fractal_octaves = 2
		BlockKind.Family.GLOW:
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			noise.frequency = 0.20
			noise.fractal_octaves = 1
		_:
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
			noise.frequency = 0.10
			noise.fractal_octaves = 2
	# Tile the texture across the 1m box face for a Minecraft-style surface.
	var tiles := 4
	var step := 1.0 / float(tiles)
	for y in range(64):
		for x in range(64):
			# Sample at tile-grid coordinates so the texture tiles seamlessly.
			var nx := float(x) / 64.0 * tiles
			var ny := float(y) / 64.0 * tiles
			var n: float = noise.get_noise_2d(nx * 64.0, ny * 64.0)
			# Map noise [-1, 1] -> brightness multiplier [0.75, 1.25]
			var mult: float = 1.0 + n * 0.25
			var base: Color = kind.color
			# Special: wood gets horizontal grain lines on top of noise.
			if kind.family == BlockKind.Family.WOOD:
				var grain: float = sin(ny * 16.0) * 0.06
				mult += grain
			var darkened: Color = Color(
				base.r * mult,
				base.g * mult,
				base.b * mult,
				1.0)
			img.set_pixel(x, y, darkened)
	var tex := ImageTexture.create_from_image(img)
	_block_textures[block_id] = tex
	return tex
