## VS-039 Contract Test: Creative hotbar properly represents tools and block materials
## 
## Acceptance Criteria:
## - Creative hotbar equips, stows, selects, and visibly represents tools and block materials
## - Axe and pickaxe use visible tool-specific swing animation
## - Tool harvesting gives physical feedback and inventory rewards without a forced grind loop

extends SceneTree

const PlayerControllerScript = preload("res://src/adapters/inbound/gameplay/player_controller.gd")
const GameplayRuntimeScript = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")

var _exit_code := 0


func _init() -> void:
	call_deferred("_run")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_exit_code = 1


func _run() -> void:
	# Test 1: PlayerController hotbar initializes with tools and blocks
	var player := PlayerControllerScript.new()
	player.position = Vector3.ZERO
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.7, 4.2)
	player.add_child(camera)
	get_root().add_child(player)
	
	# Setup build grid
	var BuildGridScript = preload("res://src/adapters/inbound/gameplay/build_grid.gd")
	var grid := BuildGridScript.new()
	get_root().add_child(grid)
	player.setup_build_grid(grid)
	
	await physics_frame
	
	# Check hotbar initialization
	var hotbar_items := player.get_hotbar_items()
	_assert(hotbar_items.size() == 5, "Hotbar should have 5 slots")
	_assert(hotbar_items[0] == "tool_axe", "Slot 0 should be tool_axe")
	_assert(hotbar_items[1] == "tool_pickaxe", "Slot 1 should be tool_pickaxe")
	_assert(hotbar_items[2] == "grass", "Slot 2 should be grass")
	_assert(hotbar_items[3] == "wood_oak", "Slot 3 should be wood_oak")
	_assert(hotbar_items[4] == "stone", "Slot 4 should be stone")
	
	# Test 2: Hotbar selection works
	player._select_hotbar_slot(0)
	_assert(player.get_active_hotbar_item() == "tool_axe", "Should select tool_axe at slot 0")
	
	player._select_hotbar_slot(1)
	_assert(player.get_active_hotbar_item() == "tool_pickaxe", "Should select tool_pickaxe at slot 1")
	
	player._select_hotbar_slot(2)
	_assert(player.get_active_hotbar_item() == "grass", "Should select grass at slot 2")
	
	# Test 3: Tool equip/stow works
	player._select_hotbar_slot(0)
	assert_true(player.has_equipped_tool("tool_axe"), "Should have tool_axe equipped")
	
	player._select_hotbar_slot(2)  # Select grass (not a tool)
	assert_false(player.has_equipped_tool("tool_axe"), "Should stow tool_axe when selecting grass")
	
	# Test 4: equip_tool adds tool to hotbar
	player.equip_tool("tool_axe")
	var updated_hotbar := player.get_hotbar_items()
	_assert(updated_hotbar.has("tool_axe"), "Hotbar should contain tool_axe after equip_tool")
	
	# Cleanup
	player.queue_free()
	grid.queue_free()
	
	# Test 5: GameplayRuntime hotbar texture mapping
	# This tests the fix for tool_pickaxe returning HUD_ICON_PICKAXE instead of HUD_ICON_STONE
	var GameplayRuntime := GameplayRuntimeScript.new()
	# We can't easily test the texture directly without a full scene, 
	# but we can verify the function doesn't crash and returns a Texture2D
	var axe_texture := GameplayRuntime._hotbar_texture_for("tool_axe", 0)
	_assert(axe_texture != null, "Should return texture for tool_axe")
	_assert(axe_texture is Texture2D, "Should return Texture2D for tool_axe")
	
	var pickaxe_texture := GameplayRuntime._hotbar_texture_for("tool_pickaxe", 0)
	_assert(pickaxe_texture != null, "Should return texture for tool_pickaxe")
	_assert(pickaxe_texture is Texture2D, "Should return Texture2D for tool_pickaxe")
	
	# Verify they're different textures
	_assert(axe_texture != pickaxe_texture, "Axe and pickaxe should have different icons")
	
	GameplayRuntime.queue_free()
	
	quit(_exit_code)


func assert_true(condition: bool, message: String = "") -> void:
	_assert(condition, message if message != "" else "Expected true")


func assert_false(condition: bool, message: String = "") -> void:
	_assert(not condition, message if message != "" else "Expected false")
