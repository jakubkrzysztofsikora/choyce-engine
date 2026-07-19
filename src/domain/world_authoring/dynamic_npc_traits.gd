## Domain value object representing a dynamically generated NPC's personality,
## role, drives, and equipment.
class_name DynamicNPCTraits
extends RefCounted

enum JobRole {
	CIVILIAN,
	FARMER,
	SHOPKEEPER,
	POLICE_OFFICER,
	MILITARY_SOLDIER,
	BANDIT,
	THIEF,
	MURDERER
}

const ALL_ROLES := [
	JobRole.CIVILIAN,
	JobRole.FARMER,
	JobRole.SHOPKEEPER,
	JobRole.POLICE_OFFICER,
	JobRole.MILITARY_SOLDIER,
	JobRole.BANDIT,
	JobRole.THIEF,
	JobRole.MURDERER
]

var npc_id: String
var display_name: String
var job_role: JobRole
var weapon_visual_id: String
var vehicle_model_path: String

# Big Five / OCEAN (0.0 to 1.0)
var openness: float = 0.5
var conscientiousness: float = 0.5
var extraversion: float = 0.5
var agreeableness: float = 0.5
var neuroticism: float = 0.5

# Dark Triad (0.0 to 1.0)
var machiavellianism: float = 0.0
var narcissism: float = 0.0
var psychopathy: float = 0.0

# Dynamic Needs / Drives (0.0 to 1.0)
var hunger: float = 0.0
var energy: float = 1.0
var morale: float = 0.8
var duty: float = 0.5

# Decay Rates
var hunger_decay_rate: float = 0.01
var energy_decay_rate: float = 0.005


func _init(
	p_npc_id: String = "",
	p_display_name: String = "",
	p_job_role: JobRole = JobRole.CIVILIAN,
	p_weapon_id: String = "",
	p_vehicle_path: String = "",
	p_openness: float = 0.5,
	p_conscientiousness: float = 0.5,
	p_extraversion: float = 0.5,
	p_agreeableness: float = 0.5,
	p_neuroticism: float = 0.5,
	p_machiavellianism: float = 0.0,
	p_narcissism: float = 0.0,
	p_psychopathy: float = 0.0
) -> void:
	npc_id = p_npc_id
	display_name = p_display_name
	job_role = p_job_role
	weapon_visual_id = p_weapon_id
	vehicle_model_path = p_vehicle_path

	openness = clampf(p_openness, 0.0, 1.0)
	conscientiousness = clampf(p_conscientiousness, 0.0, 1.0)
	extraversion = clampf(p_extraversion, 0.0, 1.0)
	agreeableness = clampf(p_agreeableness, 0.0, 1.0)
	neuroticism = clampf(p_neuroticism, 0.0, 1.0)

	machiavellianism = clampf(p_machiavellianism, 0.0, 1.0)
	narcissism = clampf(p_narcissism, 0.0, 1.0)
	psychopathy = clampf(p_psychopathy, 0.0, 1.0)


static func create_randomized(p_npc_id: String, p_role: JobRole, rng: RandomNumberGenerator = null) -> DynamicNPCTraits:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var first_names := ["Jan", "Piotr", "Marek", "Ewa", "Anna", "Zofia", "Kamil", "Michał", "Tomasz", "Agata"]
	var npc_name: String = first_names[rng.randi_range(0, first_names.size() - 1)]

	var weapon_id := ""
	var vehicle_path := "res://data/models/vehicles/police_car.glb"

	var dark_mach := rng.randf_range(0.0, 0.4)
	var dark_narc := rng.randf_range(0.0, 0.4)
	var dark_psych := rng.randf_range(0.0, 0.3)

	match p_role:
		JobRole.POLICE_OFFICER:
			npc_name = "Posterunkowy " + npc_name
			weapon_id = "res://data/models/weapons/pistol.glb"
			vehicle_path = "res://data/models/vehicles/police_car.glb"
		JobRole.MILITARY_SOLDIER:
			npc_name = "Szeregowy " + npc_name
			weapon_id = "res://data/models/weapons/assault_rifle.glb"
			vehicle_path = "res://data/models/vehicles/military_tank.glb"
		JobRole.FARMER:
			npc_name = "Gospodarz " + npc_name
			weapon_id = "pitchfork"
			vehicle_path = "res://data/models/vehicles/suv.glb"
		JobRole.BANDIT:
			npc_name = "Bandyta " + npc_name
			weapon_id = "res://data/models/weapons/assault_rifle.glb"
			vehicle_path = "res://data/models/vehicles/suv.glb"
			dark_mach = rng.randf_range(0.6, 0.95)
			dark_psych = rng.randf_range(0.6, 0.9)
		JobRole.THIEF:
			npc_name = "Złodziej " + npc_name
			weapon_id = "res://data/models/weapons/pistol.glb"
			vehicle_path = "res://data/models/vehicles/civilian_car.glb"
			dark_mach = rng.randf_range(0.7, 0.95)
			dark_narc = rng.randf_range(0.5, 0.8)
		JobRole.MURDERER:
			npc_name = "Zabójca " + npc_name
			weapon_id = "heavy_axe"
			vehicle_path = "res://data/models/vehicles/suv.glb"
			dark_psych = rng.randf_range(0.8, 1.0)
			dark_mach = rng.randf_range(0.5, 0.9)
		_:
			weapon_id = ""
			vehicle_path = "res://data/models/vehicles/civilian_car.glb"

	var script := load("res://src/domain/world_authoring/dynamic_npc_traits.gd") as GDScript
	var traits: DynamicNPCTraits = script.new(
		p_npc_id,
		npc_name,
		p_role,
		weapon_id,
		vehicle_path,
		rng.randf_range(0.2, 0.9),
		rng.randf_range(0.3, 0.95),
		rng.randf_range(0.1, 0.9),
		rng.randf_range(0.2, 0.95),
		rng.randf_range(0.1, 0.7),
		dark_mach,
		dark_narc,
		dark_psych
	)

	return traits


func to_dict() -> Dictionary:
	return {
		"npc_id": npc_id,
		"display_name": display_name,
		"job_role": int(job_role),
		"weapon_visual_id": weapon_visual_id,
		"vehicle_model_path": vehicle_model_path,
		"openness": openness,
		"conscientiousness": conscientiousness,
		"extraversion": extraversion,
		"agreeableness": agreeableness,
		"neuroticism": neuroticism,
		"machiavellianism": machiavellianism,
		"narcissism": narcissism,
		"psychopathy": psychopathy,
		"hunger": hunger,
		"energy": energy,
		"morale": morale,
		"duty": duty
	}


static func from_dict(d: Dictionary) -> DynamicNPCTraits:
	if not d.has("npc_id"):
		return null

	var t: DynamicNPCTraits = (load("res://src/domain/world_authoring/dynamic_npc_traits.gd") as GDScript).new(
		str(d.get("npc_id", "")),
		str(d.get("display_name", "")),
		d.get("job_role", JobRole.CIVILIAN) as JobRole,
		str(d.get("weapon_visual_id", "")),
		str(d.get("vehicle_model_path", "")),
		float(d.get("openness", 0.5)),
		float(d.get("conscientiousness", 0.5)),
		float(d.get("extraversion", 0.5)),
		float(d.get("agreeableness", 0.5)),
		float(d.get("neuroticism", 0.5)),
		float(d.get("machiavellianism", 0.0)),
		float(d.get("narcissism", 0.0)),
		float(d.get("psychopathy", 0.0))
	)
	t.hunger = float(d.get("hunger", 0.0))
	t.energy = float(d.get("energy", 1.0))
	t.morale = float(d.get("morale", 0.8))
	t.duty = float(d.get("duty", 0.5))
	return t
