class_name TeamComponent
extends SandboxComponent
## Who owns / who placed / who may hurt whom.

@export var team_id: int = 0
@export var owner_player_id: int = -1


func _component_key() -> StringName:
	return Components.TEAM


static func team_of(entity: Node) -> int:
	var t := Components.get_comp(entity, Components.TEAM)
	return t.team_id if t else -1


static func owner_of(entity: Node) -> int:
	var t := Components.get_comp(entity, Components.TEAM)
	return t.owner_player_id if t else -1
