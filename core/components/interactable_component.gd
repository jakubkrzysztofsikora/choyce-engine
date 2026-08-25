class_name InteractableComponent
extends SandboxComponent
## Makes any mesh a thing players can look at and press interact on.
## Self-registers with InteractionSystem; the system does the per-player
## raycasting so N players cost N rays, not N x M overlap checks.

signal interacted(player_id: int)
signal focus_gained(player_id: int)
signal focus_lost(player_id: int)

@export var prompt_text: String = "Use"
@export var interaction_range: float = 3.0
@export var enabled: bool = true
## If true, only the player who owns this entity may interact.
@export var owner_only: bool = false

var _focused_by: Dictionary = {}   # player_id -> true


func _component_key() -> StringName:
	return Components.INTERACTABLE


func _on_registered() -> void:
	InteractionSystem.instance.register(self)


func _exit_tree() -> void:
	if InteractionSystem.instance:
		InteractionSystem.instance.unregister(self)
	super._exit_tree()


func can_interact(player_id: int) -> bool:
	if not enabled:
		return false
	if owner_only and TeamComponent.owner_of(entity) != player_id:
		return false
	return true


func do_interact(player_id: int) -> void:
	if can_interact(player_id):
		interacted.emit(player_id)


func set_focus(player_id: int, focused: bool) -> void:
	var was: bool = _focused_by.has(player_id)
	if focused and not was:
		_focused_by[player_id] = true
		focus_gained.emit(player_id)
	elif not focused and was:
		_focused_by.erase(player_id)
		focus_lost.emit(player_id)


func is_focused() -> bool:
	return not _focused_by.is_empty()


func focused_by() -> Array:
	return _focused_by.keys()
