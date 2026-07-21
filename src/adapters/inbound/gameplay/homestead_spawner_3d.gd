## Adapter node responsible for instantiating compound homestead assets (house, car,
## animals, NPC) in the 3D scene tree with terrain height snapping and collision checking.
class_name HomesteadSpawner3D
extends Node3D

const DYNAMIC_TRAITS := preload("res://src/domain/world_authoring/dynamic_npc_traits.gd")
const HOMESTEAD_SPEC := preload("res://src/domain/world_authoring/homestead_spec.gd")
const PLACEMENT_SERVICE := preload("res://src/adapters/inbound/gameplay/settlement_placement_service.gd")

const DEFAULT_HOUSE_MODELS := [
	"res://data/models/kaykit/builder/objects/house.gltf.glb",
	"res://data/models/kaykit/builder/objects/watchtower.gltf.glb"
]

## Friendly villager look pool (Kenney mini characters). A NPC's model is
## picked deterministically from its npc_id hash so every spawn is stable.
const NPC_CHARACTER_MODELS := [
	"res://data/models/kenney/mini_characters/GLB/character-male-a.glb",
	"res://data/models/kenney/mini_characters/GLB/character-male-b.glb",
	"res://data/models/kenney/mini_characters/GLB/character-male-c.glb",
	"res://data/models/kenney/mini_characters/GLB/character-male-d.glb",
	"res://data/models/kenney/mini_characters/GLB/character-female-a.glb",
	"res://data/models/kenney/mini_characters/GLB/character-female-b.glb",
	"res://data/models/kenney/mini_characters/GLB/character-female-c.glb",
	"res://data/models/kenney/mini_characters/GLB/character-female-d.glb"
]

## Animal kind -> model path. Empty string means "no model in the packs" —
## the spawner warns and skips that kind instead of spawning nothing silently.
const ANIMAL_MODELS := {
	"cow": "res://data/models/third_party/styloo_animals/Cow.glb",
	"sheep": "",
	"chicken": "res://data/models/props/chicken.gltf",
	"dog": "res://data/models/third_party/styloo_animals/dog.glb"
}

## Realistic shoulder heights (m) used to normalize each animal GLB.
const ANIMAL_TARGET_HEIGHTS := {
	"cow": 1.4,
	"sheep": 1.0,
	"chicken": 0.4,
	"dog": 0.6
}

const _TARGET_NPC_HEIGHT := 1.7

var _placement_service := PLACEMENT_SERVICE.new()
var _spawned_homesteads: Array = []


## Spawns a complete compound homestead with NPC, house, car, and animals.
func spawn_random_homestead(
	center: Vector3,
	role: int = 0, # DynamicNPCTraits.JobRole.FARMER
	rng: RandomNumberGenerator = null
) -> Node3D:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var npc_id := "npc_dyn_%d" % rng.randi()
	var homestead_id := "home_dyn_%d" % rng.randi()

	# Generate traits
	var traits: Variant = DYNAMIC_TRAITS.create_randomized(npc_id, role, rng)

	# Calculate spatial placement. The placement service owns XZ layout only and
	# returns y = UNGROUNDED_Y (-INF); a live node must never receive a
	# non-finite transform, so fall back to the caller's ground height here.
	# WorldRenderer re-grounds every compound exactly at its final XZ.
	var pos: Vector3 = _placement_service.find_valid_placement(center, _spawned_homesteads, 12.0, 40.0, 6.0, rng)
	if not is_finite(pos.y):
		pos.y = center.y
	var rot_y := rng.randf_range(0.0, TAU)

	# Select house model
	var house_path: String = DEFAULT_HOUSE_MODELS[rng.randi() % DEFAULT_HOUSE_MODELS.size()]
	if not ResourceLoader.exists(house_path):
		push_warning("HomesteadSpawner3D: house model missing: %s" % house_path)
		house_path = ""

	# Animals (friendly farm / pet sets per village role)
	var animal_set: Array[String] = []
	if role == DYNAMIC_TRAITS.JobRole.FARMER:
		animal_set = ["cow", "sheep", "chicken"]
	elif role == DYNAMIC_TRAITS.JobRole.SHEPHERD:
		animal_set = ["sheep", "dog"]
	else:
		animal_set = ["dog"]

	var spec: Variant = HOMESTEAD_SPEC.new(
		homestead_id,
		npc_id,
		house_path,
		traits.vehicle_model_path,
		animal_set,
		pos,
		rot_y,
		6.0
	)
	_spawned_homesteads.append(spec)

	# Build container node
	var compound := Node3D.new()
	compound.name = "Homestead_%s" % homestead_id
	compound.position = pos
	compound.rotation.y = rot_y
	add_child(compound)

	# 1. House Mesh (scaled to a family-home footprint, grounded, solid walls)
	if not house_path.is_empty():
		var packed := load(house_path) as PackedScene
		if packed != null:
			var house := packed.instantiate() as Node3D
			if house != null:
				house.name = "HouseStructure"
				compound.add_child(house)
				# KayKit pieces are small modular kits — normalize so the longest
				# horizontal axis reads as a real house (~7-9 m).
				_normalize_node_size(house, rng.randf_range(7.0, 9.0))
				_add_house_collision(house)

	# 2. Vehicle (Parked beside house)
	if not traits.vehicle_model_path.is_empty() and ResourceLoader.exists(traits.vehicle_model_path):
		var car_packed := load(traits.vehicle_model_path) as PackedScene
		if car_packed != null:
			var car := car_packed.instantiate() as Node3D
			if car != null:
				car.name = "ParkedVehicle"
				car.position = Vector3(4.5, 0.0, 2.0) # Driveway offset
				compound.add_child(car)
				_normalize_vehicle_size(car)

	# 3. Dynamic NPC Mesh & Metadata Anchor
	var npc_anchor := Node3D.new()
	npc_anchor.name = "NPC_%s" % npc_id
	npc_anchor.position = Vector3(0.0, 0.0, 3.0) # Porch offset
	npc_anchor.set_meta("npc_id", npc_id)
	npc_anchor.set_meta("display_name", traits.display_name)
	npc_anchor.set_meta("job_role", int(traits.job_role))
	npc_anchor.set_meta("weapon_visual_id", traits.weapon_visual_id)
	compound.add_child(npc_anchor)
	_attach_npc_visual(npc_anchor, npc_id)

	# 4. Animals in a small pasture pocket beside the house (1-3, seeded)
	_spawn_animals(compound, animal_set, rng)

	return compound


func get_spawned_specs() -> Array:
	return _spawned_homesteads


## Attaches a friendly Kenney mini-character mesh to the NPC anchor.
## The model comes from a deterministic pick (npc_id hash) so the same
## NPC always looks the same. The visual joins group "npc_visual" so other
## systems (portrait capture, name tags) can find it.
func _attach_npc_visual(npc_anchor: Node3D, npc_id: String) -> void:
	if NPC_CHARACTER_MODELS.is_empty():
		push_warning("HomesteadSpawner3D: NPC character model pool is empty")
		return
	var model_path: String = NPC_CHARACTER_MODELS[absi(npc_id.hash()) % NPC_CHARACTER_MODELS.size()]
	if not ResourceLoader.exists(model_path):
		push_warning("HomesteadSpawner3D: NPC character model missing: %s" % model_path)
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_warning("HomesteadSpawner3D: NPC character model failed to load: %s" % model_path)
		return
	var visual := packed.instantiate() as Node3D
	if visual == null:
		push_warning("HomesteadSpawner3D: NPC character model is not a Node3D scene: %s" % model_path)
		return
	visual.name = "NPCVisual"
	npc_anchor.add_child(visual)
	_normalize_node_size(visual, _TARGET_NPC_HEIGHT, true)
	visual.add_to_group("npc_visual")
	for mesh_variant in visual.find_children("*", "MeshInstance3D", true, false):
		(mesh_variant as MeshInstance3D).add_to_group("npc_visual")
	# Face the villager toward the compound center (local -offset direction).
	var to_center := -npc_anchor.position
	if to_center.length_squared() > 0.0001:
		npc_anchor.rotation.y = atan2(to_center.x, to_center.z)


## Spawns 1-3 animals from the homestead's animal set around the compound.
## Placement is deterministic for the given rng; kinds without a model on
## disk are skipped with a warning instead of failing the whole spawn.
func _spawn_animals(compound: Node3D, animal_set: Array[String], rng: RandomNumberGenerator) -> void:
	if animal_set.is_empty():
		return
	var count := rng.randi_range(1, 3)
	var start := rng.randi() % animal_set.size()
	for i in range(count):
		var kind: String = animal_set[(start + i) % animal_set.size()]
		var model_path: String = ANIMAL_MODELS.get(kind, "")
		if model_path.is_empty() or not ResourceLoader.exists(model_path):
			push_warning("HomesteadSpawner3D: no model for animal '%s' — skipping" % kind)
			continue
		var packed := load(model_path) as PackedScene
		if packed == null:
			push_warning("HomesteadSpawner3D: animal model failed to load: %s" % model_path)
			continue
		var animal := packed.instantiate() as Node3D
		if animal == null:
			push_warning("HomesteadSpawner3D: animal model is not a Node3D scene: %s" % model_path)
			continue
		animal.name = "Animal_%s_%d" % [kind, i]
		# Pasture pocket on the opposite side of the driveway.
		animal.position = Vector3(
			-4.5 - rng.randf_range(0.0, 2.0),
			0.0,
			-2.0 + float(i) * 2.0 + rng.randf_range(-0.5, 0.5)
		)
		compound.add_child(animal)
		_normalize_node_size(animal, float(ANIMAL_TARGET_HEIGHTS.get(kind, 1.0)), true)


## Trimesh collision on the house only, so the player can't walk through
## walls. NPCs and animals stay collision-free (kids can walk up to them).
func _add_house_collision(house: Node3D) -> void:
	for mesh_variant in house.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_variant as MeshInstance3D
		if mesh_instance.mesh != null:
			mesh_instance.create_trimesh_collision()


# Source GLBs ship at wildly different scales (some ~489 units long,
# some ~0.2). Measure the merged mesh AABB and rescale so the longest axis
# matches a real-world target, fixing both giant and invisible models.
const _TARGET_VEHICLE_LENGTH := 4.5

func _normalize_vehicle_size(car: Node3D) -> void:
	_normalize_node_size(car, _TARGET_VEHICLE_LENGTH)


## Generic normalizer: scales `node` so its merged mesh AABB longest axis
## (horizontal x/z by default, or height y when use_height is true) matches
## target_longest_m, then grounds the mesh base at the node's local y=0.
func _normalize_node_size(node: Node3D, target_longest_m: float, use_height := false) -> void:
	var merged := _merged_mesh_aabb(node)
	var longest := merged.size.y if use_height else maxf(merged.size.x, merged.size.z)
	if longest <= 0.001:
		return
	# ponytail: clamp guards against a bad measurement scaling the node to camp size.
	var factor := clampf(target_longest_m / longest, 0.01, 25.0)
	node.scale *= factor
	# Ground the mesh: after scaling, the AABB min.y sits at
	# position.y + merged.position.y * scale.y — lift so the base touches 0.
	node.position.y -= merged.position.y * node.scale.y


func _merged_mesh_aabb(node: Node3D) -> AABB:
	var merged := AABB()
	var has_bounds := false
	for mesh_variant in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_variant as MeshInstance3D
		# global_transform is unreliable while the compound is off-tree; walk
		# local transforms up to `node` instead so the measure is tree-independent.
		var to_root := _relative_transform(mesh_instance, node)
		var local := to_root * mesh_instance.get_aabb()
		if not has_bounds:
			merged = local
			has_bounds = true
		else:
			merged = merged.merge(local)
	return merged


func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var cur := node
	while cur != null and cur != ancestor:
		xform = cur.transform * xform
		cur = cur.get_parent() as Node3D
	return xform
