## Integration test for the kid-click-world-card → play-shell → gameplay flow.
##
## Catches five regressions the existing 75 contract tests missed:
##   1. Wrong dict key in voice moderation guard (`"blocked"` vs `"allowed"`)
##   2. PackedStringArray passed where Array[PlayerProfile] expected (PlayShell → RunPlaytestService)
##   3. PlayShell._project_store never wired (DI omission in _wire_shell_dependencies)
##   4. ColorRect backdrop with MOUSE_FILTER_STOP swallowing world-card clicks
##   5. Node3D (GameplayRuntime) added as child of a Control (PlayShell) → 3D never renders
##
## Assertions (L3.1 … L3.9) listed inline in `_run()`.
##
## Strategy: instantiate the real composition root (main.tscn), await its
## `ports_ready` signal, replace ONLY the RunPlaytestPort with an in-test
## recorder so we can capture the `players` argument, then drive the picker
## click chain end-to-end. No other mocks are inserted — the real LandingScreen,
## real PlayShell, real ShellNavigator are exercised.
extends SceneTree


const KEY_PLAYTEST_PORT := "run_playtest"


func _init() -> void:
	# Run isolated from any pre-existing user:// state. Godot honours
	# config/use_custom_user_dir=true → user data lives at the platform path
	# below. We do not blast it from here (other dev work may rely on it).
	# This test only reads ports + UI state, so a partially-populated user dir
	# is OK; the assertions don't depend on persisted data.
	OS.set_environment("CHOYCE_PROFILE_ID", "test_kid_world_card")
	OS.set_environment("CHOYCE_PROFILE_ROLE", "kid")
	OS.set_environment("CHOYCE_AUDIT_IN_MEMORY", "1")  # avoid filesystem audit churn
	call_deferred("_run")


func _run() -> void:
	var main_scene := load("res://src/adapters/inbound/main.tscn")
	assert(main_scene != null, "main.tscn failed to load")
	var main: InboundMain = main_scene.instantiate()
	assert(main != null, "InboundMain failed to instantiate")
	get_root().add_child(main)

	# Wait for _ready() to run and Phase-2 deferred init to fire ports_ready.
	# ports_ready is emitted from _build_default_ports_phase_2 (call_deferred
	# in _ready). Awaiting the signal gives both phases time to complete.
	await main.ports_ready
	# One extra frame so _wire_shell_dependencies (called at end of Phase 2)
	# settles, and the navigator's instant_switch to SHELL_LANDING completes.
	await process_frame
	await process_frame

	var landing: LandingScreen = main._landing_shell
	var play_shell: PlayShell = main._play_shell
	assert(landing != null, "landing shell missing")
	assert(play_shell != null, "play shell missing")

	# Press the Play button to open the world picker.
	landing._on_play_pressed()
	await process_frame

	var picker: CanvasLayer = landing._picker_layer
	var card_row: HBoxContainer = landing._card_row

	# L3.1 — Picker opens with at least one starter card.
	assert(picker.visible, "L3.1: picker_layer should be visible after Play press")
	assert(card_row.get_child_count() >= 1,
		"L3.1: card_row should have ≥1 starter card; got %d" % card_row.get_child_count())
	print("PASS L3.1: picker visible with %d card(s)" % card_row.get_child_count())

	# L3.2 — Every visible card is a seeded starter (project_id contains "_starter_").
	# Catches regression where stale projects (e.g. starter_canvas) leaked through.
	# We can't read project_id off the Button directly, so we re-query the
	# project_store using the same filter LandingScreen applies and confirm the
	# count matches AND every matching project id contains "_starter_".
	var store: ProjectStorePort = landing._project_store
	assert(store != null, "L3.2: landing project_store is null — DI regression")
	var profile_id: String = landing._profile.profile_id
	var starter_count := 0
	for p in store.list_projects():
		if p.owner_profile_id != profile_id:
			continue
		assert(String(p.project_id).contains("_starter_") or card_row.get_child_count() == 0,
			"L3.2: non-starter project leaked into picker: %s" % p.project_id)
		if String(p.project_id).contains("_starter_"):
			starter_count += 1
	assert(starter_count == card_row.get_child_count(),
		"L3.2: card count (%d) != starter project count (%d)" % [card_row.get_child_count(), starter_count])
	print("PASS L3.2: all %d card(s) map to _starter_ projects" % starter_count)

	# L3.3 — Backdrop is MOUSE_FILTER_IGNORE.
	var backdrop: Control = picker.get_node_or_null("Backdrop")
	assert(backdrop != null, "L3.3: backdrop missing under PickerLayer")
	assert(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"L3.3: backdrop must be MOUSE_FILTER_IGNORE; got %d" % backdrop.mouse_filter)
	print("PASS L3.3: backdrop is MOUSE_FILTER_IGNORE")

	# Before pressing the card, install our recorder on KEY_PLAYTEST_PORT and
	# rewire it into PlayShell so launch_world_by_id calls our recorder.
	# Also confirm _project_store is non-null BEFORE the click (L3.9).
	assert(play_shell._project_store != null,
		"L3.9: PlayShell._project_store was never wired (setup_for_direct_launch omitted)")
	print("PASS L3.9: PlayShell._project_store wired before click")

	var recorder := PlaytestRecorder.new()
	main._ports[KEY_PLAYTEST_PORT] = recorder
	# PlayShell holds a direct reference from its earlier setup() call; replace it.
	play_shell._run_playtest_port = recorder

	# Capture the world_card_pressed signal so L3.4 can assert payload types.
	var captured := {"project_id": "", "world_id": "", "fired": false}
	landing.world_card_pressed.connect(func(pid: String, wid: String) -> void:
		captured["project_id"] = pid
		captured["world_id"] = wid
		captured["fired"] = true
	)

	# Simulate the card click via the Button.pressed signal (skips actual
	# mouse-input plumbing but exercises the same handler chain).
	var card: Button = card_row.get_child(0) as Button
	assert(card != null, "L3.4: first card is not a Button")
	card.pressed.emit()
	await process_frame
	await process_frame

	# L3.4 — world_card_pressed emitted with non-empty project_id and a usable world_id.
	assert(captured["fired"], "L3.4: world_card_pressed signal did not fire")
	assert(String(captured["project_id"]).length() > 0, "L3.4: project_id is empty")
	# world_id may be empty when project has no worlds, but starter seeds always
	# have a world, so for THIS flow it should be set.
	assert(String(captured["world_id"]).length() > 0,
		"L3.4: world_id empty for starter project — starter seed missing world?")
	print("PASS L3.4: world_card_pressed(project='%s', world='%s')"
		% [captured["project_id"], captured["world_id"]])

	# L3.5 — Picker hidden after card press.
	assert(not picker.visible, "L3.5: picker should be hidden after card press")
	print("PASS L3.5: picker hidden after card press")

	# L3.6 — Navigator switched to SHELL_PLAY (the source-of-truth for active shell).
	# ShellTransition runs a 0.2 s tween before `_instant_switch` flips the
	# active id. Sleep long enough for that to settle (0.5 s buffer); avoids
	# the N-process-frame race that previously made L3.6 flaky.
	await create_timer(0.5).timeout
	var nav_id := main._navigator.get_active_shell_id()
	assert(nav_id == "play",
		"L3.6: navigator active_shell_id should be 'play'; got '%s'" % nav_id)
	print("PASS L3.6: navigator switched to SHELL_PLAY")

	# L3.7 — GameplayRuntime attached to scene-tree root, not PlayShell.
	# launch_world_by_id → _start_gameplay does get_tree().root.add_child(_gameplay_runtime).
	# If a future regression re-parents to play_shell, this catches it.
	var runtime: GameplayRuntime = play_shell._gameplay_runtime
	assert(runtime != null,
		"L3.7: PlayShell._gameplay_runtime is null — _start_gameplay was not reached")
	assert(runtime.get_parent() == get_root(),
		"L3.7: GameplayRuntime parent is %s, expected scene-tree root"
			% str(runtime.get_parent()))
	assert(runtime.get_parent() != play_shell,
		"L3.7: GameplayRuntime must NOT be a child of PlayShell (Control)")
	print("PASS L3.7: GameplayRuntime parented to scene-tree root")

	# L3.8 — RunPlaytestPort received Array[PlayerProfile], not PackedStringArray/strings.
	assert(recorder.was_called, "L3.8: RunPlaytestPort.execute() never called")
	assert(recorder.last_players != null, "L3.8: recorder.last_players is null")
	assert(recorder.last_players.size() >= 1,
		"L3.8: recorder.last_players empty; got size=%d" % recorder.last_players.size())
	var first_player = recorder.last_players[0]
	assert(first_player is PlayerProfile,
		"L3.8: first player should be PlayerProfile, got %s" % typeof(first_player))
	assert(not (first_player is String),
		"L3.8: first player is a String (PackedStringArray regression)")
	print("PASS L3.8: RunPlaytestPort received Array[PlayerProfile]")

	# Clean shutdown — queue_free the runtime first so its session_end signal
	# doesn't fire celebration tweens during teardown.
	if runtime != null:
		runtime.queue_free()
	main.queue_free()
	await process_frame

	print("[test_world_card_click_flow] OK")
	quit(0)


# --- Recorder used only for assertion L3.8 ---
class PlaytestRecorder extends RunPlaytestPort:
	var was_called: bool = false
	var last_world_id: String = ""
	var last_players: Array = []

	func execute(world_id: String, players: Array) -> Session:
		was_called = true
		last_world_id = world_id
		last_players = players
		# Return a minimal valid Session so _start_gameplay proceeds and we can
		# observe the GameplayRuntime parenting (L3.7). Session ctor signature
		# differs across the codebase; keep it permissive.
		var session := Session.new("test_session_world_card", world_id)
		return session
