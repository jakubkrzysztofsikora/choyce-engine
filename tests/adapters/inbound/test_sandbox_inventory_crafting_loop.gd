## The sandbox loop must work in a direct Godot session too, where no compiled
## rules runtime has been injected. It covers one shared local inventory, the
## intentional inventory panel, and material-gated recipes.
extends SceneTree

const GAMEPLAY_SCENE := preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		printerr("FAIL: %s" % message)
		_failures += 1


func _run() -> void:
	var runtime := GAMEPLAY_SCENE.instantiate()
	get_root().add_child(runtime)
	await process_frame
	runtime._build_hud()
	runtime._add_inventory_item("wood_oak", 6)
	runtime._add_inventory_item("ore_iron", 2)
	runtime._add_inventory_item("food_apple", 1)
	var inventory := runtime._get_inventory()
	_assert(int(inventory.get("wood_oak", 0)) == 6 and int(inventory.get("ore_iron", 0)) == 2,
		"direct session keeps collected materials in one local inventory")
	_assert(runtime._inventory_overlay != null and not runtime._inventory_overlay.visible,
		"full backpack is present but closed during exploration")
	runtime._toggle_inventory_overlay()
	_assert(runtime._inventory_overlay.visible and runtime._player_controller.is_input_disabled(),
		"explicit inventory open pauses world input instead of stealing keys at rest")
	runtime._toggle_inventory_overlay()
	_assert(not runtime._inventory_overlay.visible and not runtime._player_controller.is_input_disabled(),
		"closing inventory restores third-person controls")
	runtime._craft_inventory_recipe("stick")
	inventory = runtime._get_inventory()
	_assert(int(inventory.get("wood_oak", 0)) == 3 and int(inventory.get("stick", 0)) == 1,
		"stick craft consumes exactly its wood recipe and creates the output")
	runtime._craft_inventory_recipe("sword_iron")
	inventory = runtime._get_inventory()
	_assert(int(inventory.get("wood_oak", 0)) == 0 and int(inventory.get("ore_iron", 0)) == 0
		and int(inventory.get("sword_iron", 0)) == 1,
		"iron sword craft consumes shared materials and records the crafted item")
	_assert(runtime._current_weapon_index == 2,
		"crafted iron sword equips the existing held-weapon progression tier")
	runtime._craft_inventory_recipe("meal")
	inventory = runtime._get_inventory()
	_assert(int(inventory.get("food_apple", 0)) == 0 and int(inventory.get("meal", 0)) == 1,
		"meal craft consumes food and grants a usable meal item")
	runtime.queue_free()
	await process_frame
	quit(_failures)
