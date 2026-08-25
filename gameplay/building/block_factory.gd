class_name BlockFactory
extends RefCounted
## Builds placeable block prefabs procedurally so the whole building system is
## exercisable with ZERO imported art.
##
## When KayKit/Kenney assets land, replace these with authored .tscn files that
## carry the same components. Nothing else in the kit changes — that is the
## entire point of the component contract.

static func make_block(id: StringName, display: String, size: Vector3,
		colour: Color, health: float = 40.0) -> PackedScene:
	var root := StaticBody3D.new()
	root.name = String(id).to_pascal_case()
	root.collision_layer = Layers.BUILD_PLACED
	root.collision_mask = 0

	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	root.add_child(cs)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.8
	mi.material_override = mat
	root.add_child(mi)

	var placeable := PlaceableComponent.new()
	placeable.name = "PlaceableComponent"
	placeable.block_id = id
	placeable.display_name = display
	placeable.footprint = Vector3i(maxi(1, int(size.x)), maxi(1, int(size.y)), maxi(1, int(size.z)))
	root.add_child(placeable)

	var placed := PlacedBlockComponent.new()
	placed.name = "PlacedBlockComponent"
	placed.block_id = id
	root.add_child(placed)

	var hp := HealthComponent.new()
	hp.name = "HealthComponent"
	var cfg := HealthConfig.new()
	cfg.max_health = health
	hp.config = cfg
	root.add_child(hp)

	var dest := DestructibleComponent.new()
	dest.name = "DestructibleComponent"
	dest.fallback_shard_count = 6
	root.add_child(dest)

	var team := TeamComponent.new()
	team.name = "TeamComponent"
	root.add_child(team)

	_own_all(root, root)

	var packed := PackedScene.new()
	packed.pack(root)
	root.queue_free()
	return packed


## Every node must have `owner` set to the root or PackedScene.pack() silently
## drops it and you get a prefab containing only its root.
static func _own_all(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own_all(child, root)


static func default_palette() -> Array[PackedScene]:
	return [
		make_block(&"block_wood", "Wood Block", Vector3.ONE, Color("#c98b4b"), 40.0),
		make_block(&"block_stone", "Stone Block", Vector3.ONE, Color("#9aa3ad"), 90.0),
		make_block(&"block_glass", "Glass Panel", Vector3(1, 1, 0.2), Color("#8fd8ff"), 15.0),
		make_block(&"beam_long", "Long Beam", Vector3(3, 0.4, 0.4), Color("#b06a3a"), 55.0),
	]
