extends SceneTree
## SandboxKitE2E — deep integration suite for the couch co-op sandbox kit
## (migrated from rpg-asserts) wired into the choyce engine.
##
## Covers the bidirectional integration contract:
##   S1  autoload boot + input-map contract (kit actions, per-device copies)
##   S2  kit level mounts and registers its palette into the kit autoloads
##   S3  bridge: Build edits -> WorldEditedEvent on DomainEventBus,
##       snapshot/restore cell mapping (floor pos / cell+0.5 centre),
##       debounced persistence through FilesystemSandboxStore
##   S4  GameplayRuntime "sandbox_kit" session flow: stage mount, registry
##       auto-join, Wróć overlay, save-on-exit, clean teardown, standard
##       stage restored
##   S5  safety policy: block budget, roster cap, join gating
##   S6  template seed: sandbox_kit.json produces a playable kit world
##
## Exit code 0 iff every check passes.

const SUITE_NAME := "SandboxKitE2E"

const GameplayRuntimeScene := preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")
const SandboxKitBridgeScript := preload("res://src/adapters/inbound/gameplay/sandbox_kit_bridge.gd")
const SandboxLevelScene := preload("res://levels/sandbox_level.tscn")

var _checks_run := 0
var _failures: Array[String] = []
var _cleanup_nodes: Array[Node] = []


func _init() -> void:
	_run_async.call_deferred()


func _run_async() -> void:
	await process_frame
	_check_boot_contract()
	await _check_level_palette()
	await _check_bridge_roundtrip_events_persistence()
	await _check_runtime_kit_session_flow()
	await _check_safety_policy()
	_check_dispose_flushes_pending_save()
	_check_template_seed()
	for node in _cleanup_nodes:
		node.queue_free()

	var passed := _failures.is_empty()
	for failure in _failures:
		print("[FAIL] %s" % failure)
	print("SANDBOX_KIT_SUITE: %d checks, %d failures -> %s" % [
		_checks_run, _failures.size(), "PASS" if passed else "FAIL"])
	quit(0 if passed else 1)


func _check(condition: bool, label: String) -> void:
	_checks_run += 1
	if not condition:
		_failures.append(label)
		print("  [x] %s" % label)


## --- S1 ---------------------------------------------------------------------

func _check_boot_contract() -> void:
	_check(BuildSystem.instance != null, "S1 BuildSystem autoload present")
	_check(PlayerRegistrySystem.instance != null, "S1 PlayerRegistry autoload present")
	_check(SaveSystem.instance != null, "S1 SaveSystem autoload present")
	_check(MultiplayerInputSystem.instance != null, "S1 MultiplayerInput autoload present")
	# The MCP game-side helper must be editor-only; it must NOT ship in the
	# runtime autoloads (review MAJOR: kid-safety surface).
	_check(root.get_node_or_null("_mcp_game_helper") == null,
		"S1 MCP helper not registered as runtime autoload")
	for action in ["move_fwd", "move_left", "move_back", "jump", "interact", "attack",
			"join", "grab", "look_left", "look_right", "look_up", "look_down",
			"build_toggle", "build_place", "build_next", "build_rotate",
			"build_mode", "build_remove"]:
		_check(InputMap.has_action(action), "S1 InputMap has '%s'" % action)
	# Shared "attack" must NOT have leaked the kit's Q key into choyce bindings
	# (review MAJOR: input leak into non-kit sessions).
	for existing in InputMap.action_get_events("attack"):
		if existing is InputEventKey and existing.keycode == KEY_Q:
			_failures.append("S1 'attack' must not bind KEY_Q")
			print("  [x] S1 'attack' must not bind KEY_Q")
			_checks_run += 1
			break
	MultiplayerInputSystem.instance.ensure_device(0)
	_check(InputMap.has_action("-1move_fwd"), "S1 namespaced keyboard action -1move_fwd")
	_check(InputMap.has_action("0move_fwd"), "S1 namespaced joypad action 0move_fwd")


## --- S2 ---------------------------------------------------------------------

func _check_level_palette() -> void:
	BuildSystem.instance.clear_all()
	var level: Node3D = SandboxLevelScene.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	_check(BuildSystem.instance.world_root == level, "S2 level registered itself as Build world root")
	_check(not BuildSystem.instance.palette.is_empty(), "S2 palette registered (%d blocks)" % BuildSystem.instance.palette.size())
	# Clear BEFORE freeing so hot/cold ticking never sees freed chunks.
	BuildSystem.instance.clear_all()
	BuildSystem.instance.world_root = null
	level.queue_free()
	await process_frame
	await process_frame


## --- S3 ---------------------------------------------------------------------

func _check_bridge_roundtrip_events_persistence() -> void:
	var bus := DomainEventBus.new()
	var world_edited: Array[Dictionary] = []
	bus.subscribe("WorldEdited", func(ev: DomainEvent) -> void:
		world_edited.append({
			"type": ev.event_type,
			"edit_type": (ev as WorldEditedEvent).edit_type,
			"actor": ev.actor_id,
		}))

	var store_dir := "user://sandbox_kit_test_saves"
	var store: FilesystemSandboxStore = load("res://src/adapters/outbound/filesystem_sandbox_store.gd").new().setup(store_dir)
	var persistence: SandboxPersistenceService = load("res://src/application/sandbox_persistence_service.gd").new().setup(store)

	# Dedicated LIVE world root for chunk creation (S2's level is gone).
	var world_root := Node3D.new()
	root.add_child(world_root)
	BuildSystem.instance.clear_all()
	BuildSystem.instance.world_root = world_root

	var bridge: Node = SandboxKitBridgeScript.new()
	root.add_child(bridge)
	bridge.setup_services(bus, persistence)
	bridge.set_world_id("kit_world_e2e")

	var block_id: StringName = BuildSystem.instance.palette[0]
	var pos := Vector3(3.5, 1.5, -2.5)
	var placed: bool = BuildSystem.instance.place(block_id, Transform3D(Basis.IDENTITY, pos), 2,
		Color.WHITE, false)
	_check(placed, "S3 place() accepted a validated=false block")

	# Snapshot mapping: cell = floor(world pos).
	var snap: SandboxState = bridge.snapshot_state()
	_check(snap != null and snap.placed_blocks.size() == 1, "S3 snapshot has 1 block")
	if snap != null and snap.placed_blocks.size() == 1:
		var entry: Dictionary = snap.placed_blocks[0]
		_check(entry.get("cell") == Vector3i(3, 1, -3),
			"S3 cell uses floor(pos), got %s" % str(entry.get("cell")))
		_check(String(entry.get("kind")) == String(block_id), "S3 snapshot keeps kind string")

	# Event fan-out.
	_check(world_edited.size() == 1, "S3 one WorldEdited event after place")
	if world_edited.size() == 1:
		_check(world_edited[0]["edit_type"] == "node_added", "S3 edit_type node_added")
		_check(world_edited[0]["actor"] == "sandbox_player_2", "S3 actor maps device to player id")

	# Removal path.
	var removed: bool = BuildSystem.instance.remove_at(pos, 2)
	_check(removed, "S3 remove_at removed the block")
	_check(world_edited.size() == 2 and world_edited[1]["edit_type"] == "node_removed",
		"S3 node_removed event after remove_at")
	_check(bridge.snapshot_state().placed_blocks.is_empty(), "S3 snapshot empty after removal")

	# Debounced persistence: place again, wait out SAVE_DEBOUNCE_SEC (0.5 s).
	BuildSystem.instance.place(block_id, Transform3D(Basis.IDENTITY, Vector3(7.5, 0.5, 7.5)), 0,
		Color.WHITE, false)
	persistence.clear_sandbox()
	await create_timer(1.2).timeout
	_check(persistence.has_saved_sandbox(), "S3 debounced save reached persistence")
	var loaded: SandboxState = persistence.load_sandbox()
	_check(loaded != null and loaded.placed_blocks.size() == 1,
		"S3 persisted state round-trips through store")
	if loaded != null and loaded.placed_blocks.size() == 1:
		_check(loaded.placed_blocks[0].get("cell") == Vector3i(7, 0, 7),
			"S3 persisted cell matches floor mapping")

	# Restore mapping: clear, then restore from the persisted snapshot;
	# positions come back at cell + 0.5 centres and budget goes to player 0.
	BuildSystem.instance.clear_all()
	var restored_count: int = bridge.restore_snapshot(persistence.load_sandbox())
	_check(restored_count == 1, "S3 restore placed 1 record")
	var recs := BuildSystem.instance.all_records()
	if recs.size() == 1:
		var back_pos: Vector3 = recs[0]["pos"]
		_check(back_pos.distance_to(Vector3(7, 0, 7) + Vector3.ONE * 0.5) < 0.001,
			"S3 restored position is cell + 0.5 centre")

	bridge.dispose()
	bridge.queue_free()
	BuildSystem.instance.clear_all()
	BuildSystem.instance.world_root = null
	world_root.queue_free()
	await process_frame


## --- S4 ---------------------------------------------------------------------

func _check_runtime_kit_session_flow() -> void:
	BuildSystem.instance.clear_all()
	BuildSystem.instance.world_root = null
	var bus := DomainEventBus.new()
	var store: FilesystemSandboxStore = load("res://src/adapters/outbound/filesystem_sandbox_store.gd").new().setup(
		"user://sandbox_kit_runtime_saves")
	var persistence: SandboxPersistenceService = load("res://src/application/sandbox_persistence_service.gd").new().setup(store)

	var runtime: GameplayRuntime = GameplayRuntimeScene.instantiate()
	root.add_child(runtime)
	runtime.setup_sandbox_kit(bus, persistence)

	var saved_states: Array[SandboxState] = []
	runtime.session_save_requested.connect(func(state: SandboxState) -> void:
		saved_states.append(state))
	var ended_count := [0]
	runtime.session_ended.connect(func() -> void: ended_count[0] += 1)

	var world := World.new("kit_world_flow", "Piaskownica")
	world.theme = "sandbox_kit"
	world.is_playable = true
	var session := Session.new("sess_kit_1", "kit_world_flow")
	session.add_player("kid_profile_1")

	runtime.start_session(world, session, null)
	await create_timer(0.3).timeout

	_check(runtime._sandbox_kit_active, "S4 runtime entered kit mode")
	_check(runtime._sandbox_kit_stage != null
		and runtime._sandbox_kit_stage.name == "SandboxKitStage", "S4 kit stage mounted")
	_check(runtime._world_renderer.visible == false, "S4 adventure renderer hidden")
	_check(runtime._player_controller.process_mode == Node.PROCESS_MODE_DISABLED,
		"S4 adventure player disabled")
	_check(PlayerRegistrySystem.instance.count() >= 1, "S4 P1 auto-joined registry")
	var p1 := PlayerRegistrySystem.instance.get_profile(0)
	_check(p1 != null and p1.device_id == -1, "S4 P1 bound to keyboard device -1")
	_check(p1 != null and is_instance_valid(p1.body), "S4 split-screen body spawned for P1")

	var overlay_btn := runtime.get_node_or_null("SandboxKitOverlay/ExitBar/ExitButton")
	_check(overlay_btn != null and overlay_btn.text == "Wróć", "S4 Wróć exit button present")

	# Kid builds something so exit has state to persist.
	var placed: bool = BuildSystem.instance.place(BuildSystem.instance.palette[0],
		Transform3D(Basis.IDENTITY, Vector3(1.5, 0.5, 1.5)), 0, Color.WHITE, false)
	_check(placed, "S4 block placed during kit session")

	runtime.end_session()
	await process_frame
	await process_frame

	_check(ended_count[0] == 1, "S4 session_ended emitted once")
	# Snapshot carries the built block PLUS the level's seeded starter structure.
	var carried := false
	if saved_states.size() == 1:
		for entry in saved_states[0].placed_blocks:
			if entry.get("cell") == Vector3i(1, 0, 1) \
					and String(entry.get("kind")) == String(BuildSystem.instance.palette[0]):
				carried = true
	_check(carried, "S4 save-on-exit carried the built block")
	_check(runtime._sandbox_kit_active == false, "S4 kit mode cleared on exit")
	_check(PlayerRegistrySystem.instance.count() == 0, "S4 registry emptied on teardown")
	_check(BuildSystem.instance.all_records().is_empty(), "S4 chunk grid cleared on teardown")
	_check(runtime._world_renderer.visible and
		runtime._world_renderer.process_mode == Node.PROCESS_MODE_INHERIT,
		"S4 adventure renderer restored for next session")
	_check(runtime._sandbox_kit_stage == null or
		not is_instance_valid(runtime._sandbox_kit_stage), "S4 stage freed")

	runtime.queue_free()
	await process_frame


## --- S5 ---------------------------------------------------------------------

func _check_safety_policy() -> void:
	var reg := PlayerRegistrySystem.instance
	var bridge: Node = SandboxKitBridgeScript.new()
	root.add_child(bridge)
	bridge.setup_services(null, null)
	# Default kid budget must come from BuildSystem (single source of truth)
	# so runtime + bridge + main.gd cannot drift apart (review MAJOR).
	_check(BuildSystem.DEFAULT_KID_BLOCK_BUDGET == 800,
		"S5 kid block budget constant = 800")
	bridge.apply_safety_policy(1, BuildSystem.DEFAULT_KID_BLOCK_BUDGET, true)
	_check(BuildSystem.instance.max_blocks_per_player == BuildSystem.DEFAULT_KID_BLOCK_BUDGET,
		"S5 policy clamps block budget to constant")
	# Pass 0 to fail-open guard: must clamp to 1 (deny), not retain previous
	# cap (review MAJOR / safety).
	bridge.apply_safety_policy(1, 999, true)
	bridge.apply_safety_policy(1, 0, true)
	_check(BuildSystem.instance.max_blocks_per_player == 1,
		"S5 policy with max_blocks=0 fails closed to 1")
	reg.join(-1)
	reg.join(0)
	_check(reg.count() == 1, "S5 roster cap leaves only max_players seats")
	bridge.apply_safety_policy(2, BuildSystem.DEFAULT_KID_BLOCK_BUDGET, false)
	_check(reg.accepting_joins == false, "S5 allow_joins=false gates the registry")
	_check(BuildSystem.instance.max_blocks_per_player == BuildSystem.DEFAULT_KID_BLOCK_BUDGET,
		"S5 policy re-applies kid budget constant")
	for profile in reg.profiles():
		reg.leave(profile.player_id)
	BuildSystem.instance.max_blocks_per_player = 2000
	_cleanup_nodes.append(bridge)


## --- S7 ---------------------------------------------------------------------

## Bridge dispose() must flush the debounced save BEFORE disconnecting so the
## last ≤0.5 s of edits aren't silently dropped (review MINOR).
func _check_dispose_flushes_pending_save() -> void:
	BuildSystem.instance.clear_all()
	var store: FilesystemSandboxStore = load("res://src/adapters/outbound/filesystem_sandbox_store.gd").new().setup(
		"user://sandbox_kit_dispose_test")
	var persistence: SandboxPersistenceService = load("res://src/application/sandbox_persistence_service.gd").new().setup(store)
	persistence.clear_sandbox()

	var bridge: Node = SandboxKitBridgeScript.new()
	root.add_child(bridge)
	bridge.setup_services(null, persistence)
	bridge.set_world_id("dispose_world")

	var world_root := Node3D.new()
	root.add_child(world_root)
	BuildSystem.instance.world_root = world_root
	BuildSystem.instance.place(BuildSystem.instance.palette[0],
		Transform3D(Basis.IDENTITY, Vector3(2.5, 0.5, 2.5)), 0, Color.WHITE, false)
	# Pending save scheduled. Dispose immediately — without the sync flush the
	# SceneTreeTimer would never fire (bridge freed before timeout).
	bridge.dispose()
	_check(persistence.has_saved_sandbox(),
		"S7 dispose() flushes the pending debounced save synchronously")
	bridge.queue_free()
	BuildSystem.instance.clear_all()
	BuildSystem.instance.world_root = null
	world_root.queue_free()


## --- S6 ---------------------------------------------------------------------

class InMemoryStore:
	extends ProjectStorePort
	var _projects: Dictionary = {}
	func save_project(project: Project) -> bool:
		_projects[project.project_id] = project
		return true
	func load_project(project_id: String) -> Project:
		return _projects.get(project_id, null)
	func list_projects() -> Array:
		return _projects.values()


class MockClock:
	extends ClockPort
	func now_iso() -> String:
		return "2026-03-05T14:00:00Z"
	func now_msec() -> int:
		return 1772719200000


func _check_template_seed() -> void:
	var loader := TemplateLoader.new().setup(InMemoryStore.new(), MockClock.new())
	var owner := PlayerProfile.new("e2e_kid", PlayerProfile.Role.KID)
	var project := loader.create_project_from_template("sandbox_kit", owner)
	_check(project != null, "S6 template creates project")
	if project != null and not project.worlds.is_empty():
		var world: World = project.worlds[0]
		_check(String(world.theme) == "sandbox_kit", "S6 world theme is sandbox_kit")
		_check(world.scene_nodes.size() >= 1,
			"S6 template world passes RunPlaytestService non-empty gate")
