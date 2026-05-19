## Enemy archetype descriptor. Pure data. Spawned by World templates
## or enemy spawner zones. Kid-safe by design (CLAUDE.md):
##   - Fantasy/cartoon, no realistic violence, no blood
##   - Defeated enemies poof to sparkles + drop loot
##   - "Aggressive" behaviour = bouncing toward player, not hunting
class_name EnemyDefinition
extends RefCounted

enum Archetype {
	SLIME,          ## bouncing blob, melee bonk on touch, 2-hit defeat
	BOUNCER,        ## springy mob that hops in arcs, knocks player back
	SHOOTER,        ## stationary mob that lobs slow projectiles
	BIG_SLIME,      ## mini-boss; spawns 2 SLIMEs on defeat
}

enum Disposition {
	PASSIVE,        ## ignores player (decorative critter)
	WANDER,         ## random walk; aggros within 6m
	CHASE,          ## targets player when within aggro_radius
	GUARD,          ## stays in spawn zone; chases inside, returns outside
}

var enemy_id: String
var display_name: String
var archetype: Archetype
var disposition: Disposition
var max_hp: int
var contact_damage: int               ## damage dealt on touch / hit
var move_speed: float                 ## m/s for chase/wander
var aggro_radius: float               ## meters
var mesh_asset_id: String             ## Kenney glb path (kid-safe allowlisted)
var tint: Color                       ## body tint for variation
## Loot table — dropped on defeat. Each entry:
##   { "item_id": String, "min": int, "max": int, "chance": float (0..1) }
## Items roll independently. Defeat always rolls every entry.
var loot_table: Array


func _init(p_id: String = "") -> void:
	enemy_id = p_id
	display_name = ""
	archetype = Archetype.SLIME
	disposition = Disposition.WANDER
	max_hp = 10
	contact_damage = 5
	move_speed = 2.5
	aggro_radius = 6.0
	mesh_asset_id = ""
	tint = Color(1, 1, 1, 1)
	loot_table = []


## Default kid-friendly archetypes — built-in catalog entries used by
## the starter "Las grzybów" / "Wyspa skarbów" / new combat arenas.
static func slime_green() -> EnemyDefinition:
	var d := EnemyDefinition.new("slime_green")
	d.display_name = "Zielony glutek"
	d.archetype = Archetype.SLIME
	d.disposition = Disposition.WANDER
	d.max_hp = 10
	d.contact_damage = 5
	d.move_speed = 2.0
	d.aggro_radius = 5.0
	## Slimes are procedural spheres — adapter generates SphereMesh + tint.
	## No glb needed (and no kid-trauma-risk asset like orc/zombie used).
	d.mesh_asset_id = ""
	d.tint = Color(0.4, 0.85, 0.4)
	d.loot_table = [
		{"item_id": "slime_gel", "min": 1, "max": 2, "chance": 1.0},
		{"item_id": "coin", "min": 1, "max": 3, "chance": 0.8},
	]
	return d


static func slime_blue() -> EnemyDefinition:
	var d := slime_green()
	d.enemy_id = "slime_blue"
	d.display_name = "Niebieski glutek"
	d.max_hp = 18
	d.contact_damage = 7
	d.move_speed = 2.5
	d.tint = Color(0.35, 0.55, 0.95)
	d.loot_table = [
		{"item_id": "slime_gel", "min": 1, "max": 3, "chance": 1.0},
		{"item_id": "coin", "min": 2, "max": 5, "chance": 0.9},
		{"item_id": "ore_iron", "min": 1, "max": 1, "chance": 0.3},
	]
	return d


static func bouncer() -> EnemyDefinition:
	var d := EnemyDefinition.new("bouncer_pink")
	d.display_name = "Skoczek"
	d.archetype = Archetype.BOUNCER
	d.disposition = Disposition.CHASE
	d.max_hp = 14
	d.contact_damage = 6
	d.move_speed = 3.5
	d.aggro_radius = 8.0
	## Bouncers are also procedural — capsule mesh, springy tint.
	d.mesh_asset_id = ""
	d.tint = Color(0.95, 0.55, 0.75)
	d.loot_table = [
		{"item_id": "spring_coil", "min": 1, "max": 1, "chance": 1.0},
		{"item_id": "coin", "min": 1, "max": 4, "chance": 1.0},
	]
	return d
