extends SceneTree

## "Actually play" the game as a kid profile in the sandbox kit world, exercising
## real input, real co-op join, real build/remove, real persistence, and a
## deliberate exit. Logs every observable state change so the human can read
## what the game actually does — bugs, rough edges, surprises — without a
## display server.

const PROFILE_KID := {
	"role": "kid",
	"id": "obs_kid_1",
	"name": "Oliwka",
}

# ── Goal list the test is trying to achieve ──────────────────────────────────
const OBJECTIVES := [
	"01_boot_as_kid",
	"02_launch_piaskownica",
	"03_kit_stage_mounts",
	"04_join_two_pads",
	"05_build_place_block",
	"06_build_remove_block",
	"07_save_roundtrip",
	"08_esc_releases_capture",
	"09_esc_second_press_ends_session",
	"10_return_to_library_clean",
	"11_relaunch_state_restores",
]

var _bus: DomainEventBus
var _persistence: SandboxPersistenceService
var _events: Array = []
var _signals_fired: Dictionary = {}
var _start_ticks: int = 0
var _findings: Array[String] = []
var _world_after_session: Dictionary = {}
var _phase_log: Array[String] = []


func _initialize() -> void:
	_start_ticks = Time.get_ticks_msec()
	# Configure env BEFORE main.gd reads _build_default_profile() in its _ready.
	OS.set_environment("CHOYCE_PROFILE_ROLE", PROFILE_KID.role)
	OS.set_environment("CHOYCE_PROFILE_ID", PROFILE_KID.id)
	OS.set_environment("CHOYCE_PROFILE_NAME", PROFILE_KID.name)
	OS.set_environment("CHOYCE_AUTOPLAY", "%s_starter_sandbox_kit" % PROFILE_KID.id)
	print("=== PLAY OBSERVATION: profile=%s ===" % PROFILE_KID.id)
	# --script bypasses project.godot's run/main_scene; load it manually so the
	# composition root (main.gd) actually boots and the autoloads wire up.
	var main_scene := load("res://src/adapters/inbound/main.tscn") as PackedScene
	if main_scene == null:
		push_error("PLAY: failed to load res://src/adapters/inbound/main.tscn")
		quit(1)
		return
	root.add_child(main_scene.instantiate())
	# Schedule the rest after the scene tree has had a few frames to settle.
	create_timer(0.5).timeout.connect(_on_boot_settled, CONNECT_ONE_SHOT)


func _on_boot_settled() -> void:
	# Give main.gd a few frames to run call_deferred("_build_default_ports_phase_2")
	await process_frame
	await process_frame
	var inbound := root.get_node_or_null("Main")
	if inbound == null:
		_findings.append("BUG: Main not present after boot")
		_finish()
		return
	# Subscribe to the bus before we trigger any kit activity.
	_bus = inbound.get("_phase1_event_bus")
	_persistence = inbound.get("_phase1_sandbox_persistence")
	if _bus == null:
		_findings.append("BUG: DomainEventBus not exposed on InboundMain")
	if _persistence == null:
		_findings.append("BUG: SandboxPersistenceService not exposed on InboundMain")
	if _bus != null:
		_bus.subscribe_all(_on_bus_event)
	_observe_signal(root.get_node_or_null("GameplayRuntime"), "session_started")
	_observe_signal(root.get_node_or_null("GameplayRuntime"), "session_ended")
	_observe_signal(root.get_node_or_null("GameplayRuntime"), "session_save_requested")
	# Wait for ports_ready (signals shells may also be unlocked). The signal may
	# have already fired during the 0.5 s boot timer above, so only await when
	# phase 2 has not completed yet — otherwise the await blocks forever.
	if inbound.has_signal("ports_ready") and not bool(inbound.get("_ports_phase_2_done")):
		await inbound.ports_ready
	_log("01_boot_as_kid", "ports_ready fired in %d ms" % [Time.get_ticks_msec() - _start_ticks])
	# Now play shell auto-launched by autoplay env; give it time to settle.
	await _wait_ms(1500)
	_log_phase("after autoplay")
	await _check_kit_mounted()


func _check_kit_mounted() -> void:
	var runtime := root.get_node_or_null("GameplayRuntime")
	if runtime == null:
		_findings.append("BUG: GameplayRuntime never mounted under autoplay")
		_finish()
		return
	_log("02_launch_piaskownica", "runtime present, theme=%s active=%s" % [
		runtime.get("_sandbox_kit_active"), runtime.get("_session")])
	if not bool(runtime.get("_sandbox_kit_active")):
		# Could be the autoplay fired for a non-kit project. Confirm world.
		var world: World = runtime.get("_session").world if runtime.get("_session") else null
		_findings.append("BUG: autoplay did not enter sandbox_kit (world=%s)" % world)
		_finish()
		return
	# Autoplay uses adventure by default — we overrode to sandbox_kit starter.
	_log("03_kit_stage_mounts", "stage=%s bridge=%s overlay=%s" % [
		runtime.get("_sandbox_kit_stage"),
		runtime.get("_sandbox_kit_bridge"),
		runtime.get("_sandbox_kit_overlay")])
	if runtime.get("_sandbox_kit_stage") == null:
		_findings.append("BUG: sandbox kit stage failed to mount")
	if runtime.get("_sandbox_kit_bridge") == null:
		_findings.append("BUG: sandbox kit bridge failed to instantiate")
	await _join_pads_and_build(runtime)


func _join_pads_and_build(runtime: Node) -> void:
	var reg := PlayerRegistrySystem.instance
	if reg == null:
		_findings.append("BUG: PlayerRegistry autoload missing")
		_finish()
		return
	var initial_count := reg.count()
	# Headless registers only the keyboard device (-1); simulate two gamepads by
	# registering devices 0 + 1 first, then pulsing each namespaced "<d>join".
	# PlayerRegistry._process polls first_device_pressing() once per frame, so
	# each press must span at least one full frame before release.
	var mp := MultiplayerInputSystem.instance
	if mp == null:
		_findings.append("BUG: MultiplayerInput autoload missing")
		_finish()
		return
	for d in [0, 1]:
		mp.ensure_device(d)
		var act := "%djoin" % d
		if not InputMap.has_action(act):
			_findings.append("BUG: missing %s action" % act)
			continue
		# The registry polls first_device_pressing() (edge-triggered
		# is_action_just_pressed) once per frame, so drive a real InputEvent edge
		# and hold it across a frame boundary for the poll to observe.
		await _pulse_action(act)
	# Kit launch auto-joins the keyboard (-1), so initial_count already includes
	# one player; the two synthetic pads should add two more.
	_log("04_join_two_pads", "registry count: %d → %d (expect +2)" % [initial_count, reg.count()])
	if reg.count() - initial_count != 2:
		_findings.append("UX: join signal only added %d players (expected 2)" %
			(reg.count() - initial_count))
	# Try placing a block.
	await _wait_ms(300)
	var build := BuildSystem.instance
	if build == null:
		_findings.append("BUG: BuildSystem autoload missing in kit session")
		await _exit_session(runtime)
		return
	# sandbox_level._ready already called BuildSystem.set_world_root(level); the
	# kit stage is a SplitScreenManager Control, not the Node3D build root, so we
	# must not overwrite world_root here.
	if build.palette.is_empty():
		_findings.append("BUG: BuildSystem palette empty in kit")
		await _exit_session(runtime)
		return
	var target_pos := Vector3(3.5, 0.5, 3.5)
	var ok := build.place(build.palette[0], Transform3D(Basis.IDENTITY, target_pos), 0, Color.WHITE, false)
	_log("05_build_place_block", "place ok=%s blocks_after=%d" % [ok, _block_count(build)])
	if not ok:
		_findings.append("BUG: failed to place a block at empty cell")
	await _wait_ms(700)  # let grace window tick
	# Remove it.
	var ok_remove := build.remove_at(target_pos, 0)
	_log("06_build_remove_block", "remove ok=%s blocks_after=%d" % [ok_remove, _block_count(build)])
	if not ok_remove:
		_findings.append("BUG: failed to remove block we just placed")
	# Save round-trip: persistence should write at least once during debounce.
	var bridge := runtime.get("_sandbox_kit_bridge") as Node
	var world_id := String(bridge.get("_world_id")) if bridge else ""
	if world_id.is_empty():
		world_id = "%s_starter_sandbox_kit" % PROFILE_KID.id
	await _wait_ms(800)  # debounce = 0.5 s
	var saved := _persistence.has_saved_sandbox() if _persistence else false
	_log("07_save_roundtrip", "persistence.has_saved_sandbox=%s world_id=%s" % [saved, world_id])
	if not saved:
		_findings.append("BUG: debounced save never fired after a place+remove cycle")
	# ESC twice: release capture, then end session. GameplayRuntime._input reacts
	# to a real InputEvent, so parse_input_event (not action_press, which only
	# sets polled state) is required to reach the handler.
	await _press_esc()
	await _wait_ms(150)
	var mode_after_esc := Input.get_mouse_mode()
	_log("08_esc_releases_capture", "mouse_mode after first ESC = %d" % mode_after_esc)
	if mode_after_esc != Input.MOUSE_MODE_VISIBLE:
		_findings.append("UX: first ESC did not release mouse capture in kit mode (got %d)" % mode_after_esc)
	await _press_esc()
	await _wait_ms(500)
	# Ending the kit session emits session_ended, which PlayShell handles by
	# queue_free()-ing the GameplayRuntime — so `runtime` may already be freed.
	var runtime_freed := not is_instance_valid(runtime)
	_log("09_esc_second_press_ends_session", "runtime freed? %s active? %s" % [
		runtime_freed,
		runtime.get("_sandbox_kit_active") if not runtime_freed else "n/a"])
	if not runtime_freed and bool(runtime.get("_sandbox_kit_active")):
		_findings.append("UX: second ESC did not end kit session")
	# Should now be back in play shell with the runtime torn down.
	await _wait_ms(400)
	_log("10_return_to_library_clean",
		"runtime node present=%s freed=%s" % [
			root.get_node_or_null("GameplayRuntime"),
			not is_instance_valid(runtime)])
	if is_instance_valid(runtime):
		_findings.append("BUG: GameplayRuntime not freed after kit session end")
	# Relaunch and verify state. The old runtime was freed on teardown, so
	# re-fetch the fresh GameplayRuntime after the relaunch settles.
	var inbound := root.get_node_or_null("Main")
	inbound._on_world_card_pressed("%s_starter_sandbox_kit" % PROFILE_KID.id, "")
	await _wait_ms(2000)
	var runtime2 := root.get_node_or_null("GameplayRuntime")
	var bridge2 := runtime2.get("_sandbox_kit_bridge") as Node if runtime2 else null
	_log("11_relaunch_state_restores", "after relaunch, _sandbox_kit_active=%s world_id=%s" % [
		runtime2.get("_sandbox_kit_active") if runtime2 else "no runtime",
		String(bridge2.get("_world_id")) if bridge2 else ""])
	_finish()


func _exit_session(runtime: Node) -> void:
	runtime.end_session()
	await _wait_ms(400)
	_finish()


func _pulse_action(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _press_esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := InputEventAction.new()
	up.action = "ui_cancel"
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _wait_ms(ms: int) -> void:
	await create_timer(ms / 1000.0).timeout


func _block_count(build: Node) -> int:
	return build.all_records().size()


func _on_bus_event(event) -> void:
	_events.append({
		"t_ms": Time.get_ticks_msec() - _start_ticks,
		"type": event.event_type if "event_type" in event else str(event),
		"actor": event.actor_id if "actor_id" in event else "",
	})


func _observe_signal(emitter: Node, sig_name: String) -> void:
	if emitter == null or not emitter.has_signal(sig_name):
		return
	# Match the signal's declared argument count so the connection is valid for
	# both 0-arg (session_ended) and 1-arg (session_save_requested) signals.
	var argc := 0
	for s in emitter.get_signal_list():
		if s.name == sig_name:
			argc = (s.args as Array).size()
			break
	var bump := func() -> void:
		_signals_fired[sig_name] = int(_signals_fired.get(sig_name, 0)) + 1
	if argc == 0:
		emitter.connect(sig_name, func() -> void: bump.call())
	else:
		emitter.connect(sig_name, func(_a) -> void: bump.call())


func _log(objective: String, detail: String) -> void:
	var line := "[%d ms] %-30s %s" % [Time.get_ticks_msec() - _start_ticks, objective, detail]
	print(line)
	_phase_log.append(line)


func _log_phase(label: String) -> void:
	print("--- %s ---" % label)


func _finish() -> void:
	print("\n========== PLAY OBSERVATION SUMMARY ==========")
	print("Total runtime: %d ms" % (Time.get_ticks_msec() - _start_ticks))
	print("Bus events observed: %d" % _events.size())
	# Bucket by type.
	var by_type: Dictionary = {}
	for e in _events:
		by_type[e["type"]] = int(by_type.get(e["type"], 0)) + 1
	for k in by_type.keys():
		print("  - %s × %d" % [k, by_type[k]])
	print("\nSignal firings:")
	for k in _signals_fired.keys():
		print("  - %s × %d" % [k, _signals_fired[k]])
	print("\nObjectives:")
	for o in OBJECTIVES:
		var hit := _phase_log.filter(func(l): return l.contains(o + " "))
		print("  [%s] %s" % ["✓" if hit.size() > 0 else "·", o])
	print("\nFindings (%d):" % _findings.size())
	for f in _findings:
		print("  - %s" % f)
	quit(0)
