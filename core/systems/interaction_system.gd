class_name InteractionSystem
extends Node
## Autoload "Interaction". Reach via InteractionSystem.instance.
##
## One raycast per player per frame against a registry of interactables.
## Cost is O(players), NOT O(players x interactables) — the naive Area3D-per
## -interactable approach is what makes sandboxes crawl once the world fills up.

static var instance: InteractionSystem

signal focus_changed(player_id: int, interactable: InteractableComponent)

## Actual ray length. It previously said 4.0 and then cast RAY_LENGTH + 8.0.
const RAY_LENGTH := 5.0

var _registry: Array[InteractableComponent] = []
var _focus: Dictionary = {}   # player_id -> InteractableComponent


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE


func register(c: InteractableComponent) -> void:
	if c not in _registry:
		_registry.append(c)


func unregister(c: InteractableComponent) -> void:
	_registry.erase(c)
	for pid in _focus.keys():
		if _focus[pid] == c:
			_focus.erase(pid)


func _physics_process(_delta: float) -> void:
	var reg := PlayerRegistrySystem.instance
	if reg == null:
		return
	var mp := MultiplayerInputSystem.instance
	for profile in reg.profiles():
		var hit := _raycast_for(profile)
		_set_focus(profile.player_id, hit)
		if mp and hit and mp.is_action_just_pressed(profile.device_id, &"interact"):
			hit.do_interact(profile.player_id)


func _raycast_for(profile: SandboxPlayerProfile) -> InteractableComponent:
	if not is_instance_valid(profile.body):
		return null
	# From the player's AIM pivot, not the camera. The camera sits behind the
	# player looking at them, so a camera-origin ray passes through the player's
	# own head and targets whatever is behind them.
	var space := (profile.body as Node3D).get_world_3d().direct_space_state
	var from := profile.aim_origin()
	var to := from + profile.aim_direction() * RAY_LENGTH

	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Layers.INTERACT_TRIGGER | Layers.PROP_DYNAMIC \
		| Layers.BUILD_PLACED | Layers.VEHICLE | Layers.NPC_BODY
	q.collide_with_areas = true
	q.collide_with_bodies = true
	# The camera sits behind the player; excluding the player's own body stops
	# every ray terminating on the back of its owner's head.
	q.exclude = [profile.body.get_rid()] if profile.body is CollisionObject3D else []

	var result := space.intersect_ray(q)
	if result.is_empty():
		return null

	var ent := Components.entity_of(result.collider)
	var c := Components.get_comp(ent, Components.INTERACTABLE) as InteractableComponent
	if c == null or not c.can_interact(profile.player_id):
		return null

	var origin: Node3D = c.entity_3d()
	if origin and origin.global_position.distance_to(profile.body.global_position) > c.interaction_range:
		return null
	return c


func _set_focus(player_id: int, c: InteractableComponent) -> void:
	var prev: InteractableComponent = _focus.get(player_id, null)
	if prev == c:
		return
	if is_instance_valid(prev):
		prev.set_focus(player_id, false)
	if c:
		_focus[player_id] = c
		c.set_focus(player_id, true)
	else:
		_focus.erase(player_id)
	focus_changed.emit(player_id, c)


func focused_for(player_id: int) -> InteractableComponent:
	var c = _focus.get(player_id, null)
	return c if is_instance_valid(c) else null


func registry_size() -> int:
	return _registry.size()
