## Adapter: Represents a forageable food item in the world.
## Part of the Nutrition sandbox loop for VS-025.
##
## Design notes:
## - Extends Area3D for proximity detection with player
## - References a FoodItem from the FoodDatabase
## - Connects to NutritionManager for consumption
## - Auto-rotates + bobs for visibility (similar to LootPickup pattern)
## - Child-safe: all foods are age-appropriate, uses child-safe terminology
class_name FoodPickup
extends Area3D


## Signals
signal food_picked_up(food_item: FoodItem)


# Reference to the FoodItem this pickup represents
@export var food_item: FoodItem = null

# Reference to the NutritionManager (injected or found)
var _nutrition_manager: NutritionManager = null

# Reference to the player
var _player_ref: Node3D = null

# Visual feedback
const ROT_SPEED := TAU
const BOB_AMPLITUDE := 0.1
const BOB_FREQUENCY := 1.2
const MAGNET_RADIUS := 1.5
const MAGNET_SPEED := 6.0

var _bob_time: float = 0.0
var _base_y: float = 0.0
var _mesh: MeshInstance3D
var _already_collected: bool = false


## Called when the node enters the scene tree for the first time
func _ready() -> void:
	_base_y = global_transform.origin.y
	_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _mesh == null and get_child_count() > 0:
		_mesh = get_child(0) as MeshInstance3D
	
	## Try to find NutritionManager
	_nutrition_manager = get_node_or_null("/root/Main/World/GameplayRuntime/NutritionManager") as NutritionManager
	if _nutrition_manager == null:
		push_warning("FoodPickup: NutritionManager not found in scene")
	
	## Find player reference
	var player := get_node_or_null("/root/Main/World/GameplayRuntime/PlayerController") as Node3D
	if player != null:
		_player_ref = player


## Called every frame
func _process(delta: float) -> void:
	## Bobbing animation
	_bob_time += delta
	var bob_offset := sin(_bob_time * BOB_FREQUENCY) * BOB_AMPLITUDE
	
	## Magnet effect when player is near
	if _player_ref != null and global_transform.origin.distance_to(_player_ref.global_transform.origin) < MAGNET_RADIUS:
		var direction := (_player_ref.global_transform.origin - global_transform.origin).normalized()
		var magnet_offset := direction * MAGNET_SPEED * delta
		global_transform.origin += magnet_offset
	
	## Apply combined transform
	global_transform.origin.y = _base_y + bob_offset
	
	## Rotation
	if _mesh != null:
		_mesh.rotate_y(ROT_SPEED * delta)


## Handle player entering the area
func _on_body_entered(body: Node3D) -> void:
	if _already_collected:
		return
	
	if body.is_in_group("player") or body.name == "PlayerController":
		_collect_food(body)


## Collect the food and consume it via NutritionManager
func _collect_food(player: Node3D) -> void:
	if _already_collected or _nutrition_manager == null or food_item == null:
		return
	
	_already_collected = true
	
	## Consume the food via NutritionManager
	_nutrition_manager.eat_food(food_item)
	
	## Emit signal
	food_picked_up.emit(food_item)
	
	## Despawn with feedback
	if _mesh != null:
		## Play pickup effect (TODO: use effect spawner)
		pass
	
	## Queue for deletion
	queue_free()


## Setup the food pickup with a specific FoodItem
func setup(p_food_item: FoodItem, p_player: Node3D = null) -> FoodPickup:
	food_item = p_food_item
	_player_ref = p_player
	
	## Set up visual based on food category
	_update_visual()
	
	return self


## Update visual representation based on food category
func _update_visual() -> void:
	if food_item == null:
		return
	
	## TODO: Set mesh/material based on food category
	## For now, just ensure we have a visible mesh
	if _mesh == null and get_child_count() > 0:
		_mesh = get_child(0) as MeshInstance3D
