## Adapter node responsible for instantiating compound homestead assets (house, car,
## animals, NPC) in the 3D scene tree with terrain height snapping and collision checking.
class_name HomesteadSpawner3D
extends Node3D

const DYNAMIC_TRAITS := preload("res://src/domain/world_authoring/dynamic_npc_traits.gd")
const HOMESTEAD_SPEC := preload("res://src/domain/world_authoring/homestead_spec.gd")
const PLACEMENT_SERVICE := preload("res://src/adapters/inbound/gameplay/settlement_placement_service.gd")

const DEFAULT_HOUSE_MODELS := [
	"res://data/models/quaternius/medieval_village/house.glb",
	"res://data/models/quaternius/medieval_village/tower.glb"
]

var _placement_service := PLACEMENT_SERVICE.new()
var _spawned_homesteads: Array = []


## Spawns a complete compound homestead with NPC, house, car, and animals.
func spawn_random_homestead(
	center: Vector3,
	role: int = 0, # DynamicNPCTraits.JobRole.CIVILIAN
	rng: RandomNumberGenerator = null
) -> Node3D:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var npc_id := "npc_dyn_%d" % rng.randi()
	var homestead_id := "home_dyn_%d" % rng.randi()

	# Generate traits
	var traits: Variant = DYNAMIC_TRAITS.create_randomized(npc_id, role, rng)

	# Calculate spatial placement
	var pos: Vector3 = _placement_service.find_valid_placement(center, _spawned_homesteads, 12.0, 40.0, 6.0, rng)
	var rot_y := rng.randf_range(0.0, TAU)

	# Select house model
	var house_path: String = DEFAULT_HOUSE_MODELS[rng.randi() % DEFAULT_HOUSE_MODELS.size()]
	if not ResourceLoader.exists(house_path):
		house_path = ""

	# Animals
	var animal_set: Array[String] = []
	if role == 1: # FARMER
		animal_set = ["cow", "sheep", "chicken"]
	elif role == 0: # CIVILIAN
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

	# 1. House Mesh
	if not house_path.is_empty() and ResourceLoader.exists(house_path):
		var packed := load(house_path) as PackedScene
		if packed != null:
			var house := packed.instantiate() as Node3D
			if house != null:
				house.name = "HouseStructure"
				compound.add_child(house)

	# 2. Vehicle (Parked beside house)
	if not traits.vehicle_model_path.is_empty() and ResourceLoader.exists(traits.vehicle_model_path):
		var car_packed := load(traits.vehicle_model_path) as PackedScene
		if car_packed != null:
			var car := car_packed.instantiate() as Node3D
			if car != null:
				car.name = "ParkedVehicle"
				car.position = Vector3(4.5, 0.0, 2.0) # Driveway offset
				compound.add_child(car)

	# 3. Dynamic NPC Mesh & Metadata Anchor
	var npc_anchor := Node3D.new()
	npc_anchor.name = "NPC_%s" % npc_id
	npc_anchor.position = Vector3(0.0, 0.0, 3.0) # Porch offset
	npc_anchor.set_meta("npc_id", npc_id)
	npc_anchor.set_meta("display_name", traits.display_name)
	npc_anchor.set_meta("job_role", int(traits.job_role))
	npc_anchor.set_meta("weapon_visual_id", traits.weapon_visual_id)
	compound.add_child(npc_anchor)

	return compound


func get_spawned_specs() -> Array:
	return _spawned_homesteads
