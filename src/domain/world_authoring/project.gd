## Aggregate root for the World Authoring context.
## A Project groups one or more Worlds created from a template,
## tracks ownership, and serves as the unit of persistence and publishing.
class_name Project
extends RefCounted

var project_id: String
var title: String
var description: String
var template_id: String
var owner_profile_id: String
var created_at: String  # ISO 8601
var updated_at: String
var worlds: Array  # of World


func _init(p_id: String = "", p_title: String = "") -> void:
	project_id = p_id
	title = p_title
	description = ""
	template_id = ""
	owner_profile_id = ""
	created_at = ""
	updated_at = ""
	worlds = []


func add_world(world: World) -> void:
	worlds.append(world)


func get_world(world_id: String) -> World:
	for w in worlds:
		if w.world_id == world_id:
			return w
	return null
