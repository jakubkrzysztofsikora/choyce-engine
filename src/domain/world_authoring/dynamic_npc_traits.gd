## Domain value object representing a dynamically generated NPC's personality,
## role, drives, and equipment.
##
## Kid-safe by design (AGENTS.md mission): only friendly village roles, harmless
## handheld tools instead of weapons, civilian vehicles only, and prosocial
## personality dimensions instead of hostile/antagonist psychology.
class_name DynamicNPCTraits
extends RefCounted

enum JobRole {
	FARMER,
	BAKER,
	GARDENER,
	FISHER,
	CARPENTER,
	TEACHER,
	ARTIST,
	SHEPHERD
}

const ALL_ROLES := [
	JobRole.FARMER,
	JobRole.BAKER,
	JobRole.GARDENER,
	JobRole.FISHER,
	JobRole.CARPENTER,
	JobRole.TEACHER,
	JobRole.ARTIST,
	JobRole.SHEPHERD
]

var npc_id: String
var display_name: String
var job_role: JobRole
## Harmless handheld tool id ("fishing_rod", "watering_can", ...).
## Never a GLB path and never a weapon — the visual adapter maps these ids
## to kid-safe props. Field name kept for save/meta compatibility.
var weapon_visual_id: String
## Civilian vehicles only — the family-friendly world has no other kind.
var vehicle_model_path: String

# Big Five / OCEAN (0.0 to 1.0)
var openness: float = 0.5
var conscientiousness: float = 0.5
var extraversion: float = 0.5
var agreeableness: float = 0.5
var neuroticism: float = 0.5

# Friendly prosocial dimensions (0.0 to 1.0)
var kindness: float = 0.5
var playfulness: float = 0.5
var helpfulness: float = 0.5

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
	p_job_role: JobRole = JobRole.FARMER,
	p_weapon_id: String = "",
	p_vehicle_path: String = "",
	p_openness: float = 0.5,
	p_conscientiousness: float = 0.5,
	p_extraversion: float = 0.5,
	p_agreeableness: float = 0.5,
	p_neuroticism: float = 0.5,
	p_kindness: float = 0.5,
	p_playfulness: float = 0.5,
	p_helpfulness: float = 0.5
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

	kindness = clampf(p_kindness, 0.0, 1.0)
	playfulness = clampf(p_playfulness, 0.0, 1.0)
	helpfulness = clampf(p_helpfulness, 0.0, 1.0)


static func create_randomized(p_npc_id: String, p_role: JobRole, rng: RandomNumberGenerator = null) -> DynamicNPCTraits:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var first_names := ["Jan", "Piotr", "Marek", "Ewa", "Anna", "Zofia", "Kamil", "Michał", "Tomasz", "Agata"]
	var npc_name: String = first_names[rng.randi_range(0, first_names.size() - 1)]

	var tool_id := ""
	var vehicle_path := "res://data/models/vehicles/civilian_car.glb"

	var kindness := rng.randf_range(0.4, 0.95)
	var playfulness := rng.randf_range(0.3, 0.9)
	var helpfulness := rng.randf_range(0.4, 0.95)

	match p_role:
		JobRole.FARMER:
			npc_name = "Rolnik " + npc_name
			tool_id = "pitchfork"
			vehicle_path = "res://data/models/vehicles/suv.glb"
		JobRole.BAKER:
			npc_name = "Piekarz " + npc_name
			tool_id = "rolling_pin"
			vehicle_path = "res://data/models/vehicles/civilian_car.glb"
		JobRole.GARDENER:
			npc_name = "Ogrodnik " + npc_name
			tool_id = "watering_can"
			vehicle_path = "res://data/models/vehicles/civilian_car.glb"
		JobRole.FISHER:
			npc_name = "Rybak " + npc_name
			tool_id = "fishing_rod"
			vehicle_path = "res://data/models/vehicles/civilian_car.glb"
		JobRole.CARPENTER:
			npc_name = "Stolarz " + npc_name
			tool_id = "hammer"
			vehicle_path = "res://data/models/vehicles/suv.glb"
		JobRole.TEACHER:
			npc_name = "Nauczyciel " + npc_name
			tool_id = "book"
			vehicle_path = "res://data/models/vehicles/civilian_car.glb"
			helpfulness = rng.randf_range(0.7, 0.95)
		JobRole.ARTIST:
			npc_name = "Artysta " + npc_name
			tool_id = "paintbrush"
			vehicle_path = "res://data/models/vehicles/civilian_car.glb"
			playfulness = rng.randf_range(0.6, 0.95)
		JobRole.SHEPHERD:
			npc_name = "Pasterz " + npc_name
			tool_id = "shepherd_crook"
			vehicle_path = "res://data/models/vehicles/suv.glb"
			kindness = rng.randf_range(0.6, 0.95)
		_:
			tool_id = ""
			vehicle_path = "res://data/models/vehicles/civilian_car.glb"

	var script := load("res://src/domain/world_authoring/dynamic_npc_traits.gd") as GDScript
	var traits: DynamicNPCTraits = script.new(
		p_npc_id,
		npc_name,
		p_role,
		tool_id,
		vehicle_path,
		rng.randf_range(0.2, 0.9),
		rng.randf_range(0.3, 0.95),
		rng.randf_range(0.1, 0.9),
		rng.randf_range(0.2, 0.95),
		rng.randf_range(0.1, 0.7),
		kindness,
		playfulness,
		helpfulness
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
		"kindness": kindness,
		"playfulness": playfulness,
		"helpfulness": helpfulness,
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
		d.get("job_role", JobRole.FARMER) as JobRole,
		str(d.get("weapon_visual_id", "")),
		str(d.get("vehicle_model_path", "")),
		float(d.get("openness", 0.5)),
		float(d.get("conscientiousness", 0.5)),
		float(d.get("extraversion", 0.5)),
		float(d.get("agreeableness", 0.5)),
		float(d.get("neuroticism", 0.5)),
		float(d.get("kindness", 0.5)),
		float(d.get("playfulness", 0.5)),
		float(d.get("helpfulness", 0.5))
	)
	t.hunger = float(d.get("hunger", 0.0))
	t.energy = float(d.get("energy", 1.0))
	t.morale = float(d.get("morale", 0.8))
	t.duty = float(d.get("duty", 0.5))
	return t
