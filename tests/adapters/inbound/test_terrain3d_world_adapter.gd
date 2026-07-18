## Heightfield contract for the composed opening riverbank.
## Runs without requiring Terrain3D's runtime extension: the bank profile is
## deterministic pure terrain math, while the live capture remains the visual
## acceptance authority.
extends SceneTree

const Terrain3DWorldAdapter = preload("res://src/adapters/inbound/gameplay/terrain3d_world_adapter.gd")
const WorldRenderer = preload("res://src/adapters/inbound/gameplay/world_renderer.gd")

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
	var adapter := Terrain3DWorldAdapter.new()
	var channel := adapter._opening_riverbank_relief(Vector2(0.0, -24.0 / adapter.WORLD_SIZE_M))
	var bridge_south_ramp := adapter._opening_riverbank_relief(Vector2(0.0, -12.0 / adapter.WORLD_SIZE_M))
	var spawn := adapter._opening_riverbank_relief(Vector2(0.0, 0.0))
	var north_bank := adapter._opening_riverbank_relief(Vector2(0.0, -46.0 / adapter.WORLD_SIZE_M))
	var far_river := adapter._opening_riverbank_relief(Vector2(280.0 / adapter.WORLD_SIZE_M, -24.0 / adapter.WORLD_SIZE_M))
	var bridge_corridor_hill := adapter._opening_flank_hill_relief(Vector2(0.0, -46.0 / adapter.WORLD_SIZE_M))
	var west_flank_hill := adapter._opening_flank_hill_relief(Vector2(-78.0 / adapter.WORLD_SIZE_M, -76.0 / adapter.WORLD_SIZE_M))
	var east_flank_hill := adapter._opening_flank_hill_relief(Vector2(82.0 / adapter.WORLD_SIZE_M, -84.0 / adapter.WORLD_SIZE_M))
	_assert(is_zero_approx(channel) and is_zero_approx(bridge_south_ramp) and is_zero_approx(spawn),
		"river channel, bridge ramp and spawn stay at their established flat contact")
	_assert(north_bank > 0.005 and north_bank <= adapter.OPENING_RIVERBANK_RELIEF_NORMALIZED,
		"north riverbank gains a shallow readable Terrain3D shoulder")
	_assert(is_zero_approx(far_river),
		"opening-specific bank relief ends before it can create a full-river ridge")
	_assert(north_bank > bridge_south_ramp and north_bank - bridge_south_ramp <= adapter.OPENING_RIVERBANK_RELIEF_NORMALIZED,
		"bridge ramp to north-bank relief stays bounded without a terrain step")
	_assert(is_zero_approx(bridge_corridor_hill) and west_flank_hill > 0.055 and east_flank_hill > 0.050,
		"broad opening flank hills add real terrain scale while the bridge corridor stays flat")
	adapter.queue_free()
	await _test_runtime_terrain_collision()
	quit(_exit_code)


## Terrain3D's height formula is useful but insufficient: the rendered mesh
## only becomes playable when its asynchronous dynamic collision can be hit in
## Godot physics. This intentionally exercises the installed extension in the
## same root viewport that gameplay uses.
func _test_runtime_terrain_collision() -> void:
	_assert(ClassDB.class_exists(&"Terrain3D"), "Terrain3D extension is registered for the playable demo")
	if not ClassDB.class_exists(&"Terrain3D"):
		return
	var camera := Camera3D.new()
	camera.name = "TerrainCollisionTestCamera"
	camera.position = Vector3(0.0, 5.0, 6.0)
	get_root().add_child(camera)
	camera.make_current()
	var renderer := WorldRenderer.new()
	renderer.name = "TerrainCollisionTestRenderer"
	get_root().add_child(renderer)
	renderer._build_terrain3d_surface("terrain_collision_contract")
	for _frame in 4:
		await physics_frame
	_assert(renderer.has_runtime_terrain_surface(), "Terrain3D heightfield imports into the renderer")
	_assert(renderer.has_runtime_terrain_collision(), "Terrain3D requests dynamic collision after import")
	var contacts: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -46.0), Vector3(14.0, 0.0, -43.0)]
	_assert(renderer.verify_runtime_terrain_contacts(contacts),
		"Terrain3D physics rays hit spawn and both composed north-bank samples")
	var current_token := renderer.get_terrain_import_session_token()
	_assert(current_token > 0, "terrain import produces a positive session token")
	_assert(renderer.verify_runtime_terrain_contacts(contacts, [], null, current_token),
		"verify accepts the matching current session token")
	# Simulate a later session importing fresh terrain; a probe from the earlier
	# session must no longer be able to disable the legacy safety floor.
	renderer._build_terrain3d_surface("terrain_collision_contract_next_session")
	for _frame in 4:
		await physics_frame
	_assert(renderer.get_terrain_import_session_token() == current_token + 1,
		"a second terrain import increments the session token")
	_assert(not renderer.verify_runtime_terrain_contacts(contacts, [], null, current_token),
		"verify rejects a stale session token so an old probe cannot disable a later session's safety floor")
	renderer._build_opening_riverbank_habitat()
	var terrain_adapter := renderer.get_runtime_terrain_adapter()
	var terrain: Object = terrain_adapter.get("terrain") as Object if terrain_adapter != null else null
	var terrain_data: Object = terrain.get("data") as Object if terrain != null else null
	var all_visual_bank_layers_grounded := terrain_data != null
	for child_variant in renderer.get_children():
		var child := child_variant as Node3D
		if child == null:
			continue
		var key := String(child.name)
		if not (key.begins_with("OpeningRiverbankLowBush_")
			or key.begins_with("OpeningRiverbankThicketMidBush_")
			or key.begins_with("OpeningRiverbankThicketLowBush_")):
			continue
		var authored_y := float(child.get_meta("authored_ground_y", NAN))
		var sampled_height := float(terrain_data.call("get_height", Vector3(child.position.x, 0.0, child.position.z)))
		if not bool(child.get_meta("terrain_grounded", false)) \
			or is_nan(authored_y) \
			or not is_equal_approx(child.position.y, authored_y + sampled_height):
			all_visual_bank_layers_grounded = false
			break
	_assert(all_visual_bank_layers_grounded,
		"visual-only riverbank layers follow imported Terrain3D height instead of a y=0 waterline")
	renderer.queue_free()
	camera.queue_free()
