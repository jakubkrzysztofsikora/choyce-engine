extends SceneTree

const BuildGrid = preload("res://src/adapters/inbound/gameplay/build_grid.gd")
const BlockKind = preload("res://src/domain/build/block_kind.gd")

func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		quit(1)
	else:
		print("PASS: %s" % message)


func _run_tests() -> void:
	print("=== BuildGrid: Undo/Redo Voxel Placement Tests ===")
	
	var grid := BuildGrid.new()
	get_root().add_child(grid)
	
	# Initial state
	_assert(grid.block_count() == 0, "BuildGrid should start empty")
	
	# Test 1: Place blocks and undo them
	var p1 := Vector3i(1, 2, 3)
	var p2 := Vector3i(2, 2, 3)
	
	_assert(grid.place_block(p1, "wood_oak"), "Should place first block")
	_assert(grid.block_count() == 1, "Block count should be 1")
	_assert(grid.kind_at(p1) == "wood_oak", "Block at p1 should be wood_oak")
	
	_assert(grid.place_block(p2, "glow"), "Should place second block")
	_assert(grid.block_count() == 2, "Block count should be 2")
	_assert(grid.kind_at(p2) == "glow", "Block at p2 should be glow")
	
	# Undo second block
	_assert(grid.undo_last_action(), "Undo should succeed")
	_assert(grid.block_count() == 1, "Block count should return to 1")
	_assert(grid.kind_at(p2) == "", "Block at p2 should be removed")
	_assert(grid.kind_at(p1) == "wood_oak", "Block at p1 should remain")
	
	# Undo first block
	_assert(grid.undo_last_action(), "Undo should succeed again")
	_assert(grid.block_count() == 0, "Block count should return to 0")
	_assert(grid.kind_at(p1) == "", "Block at p1 should be removed")
	
	# Undo empty stack
	_assert(not grid.undo_last_action(), "Undo on empty history should return false")
	
	# Test 2: Break block and undo break
	_assert(grid.place_block(p1, "stone"), "Should place stone block")
	_assert(grid.block_count() == 1, "Block count should be 1")
	
	var broken_kind := grid.break_block(p1)
	_assert(broken_kind == "stone", "Should break block and return correct kind")
	_assert(grid.block_count() == 0, "Block count should be 0")
	
	# Undo break
	_assert(grid.undo_last_action(), "Undo break should succeed")
	_assert(grid.block_count() == 1, "Block count should return to 1")
	_assert(grid.kind_at(p1) == "stone", "Stone block should return to p1")
	
	# Clean up
	grid.queue_free()
	print("BUILD_GRID_UNDO_TEST: PASS")
	quit(0)
