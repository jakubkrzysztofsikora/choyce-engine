## Tests for LandingScreen — boot shell replacing CreateShell as landing.
##
## MUST criteria:
##   M1 - LandingScreen emits play_pressed when BtnPlay pressed
##   M2 - LandingScreen emits create_pressed when BtnCreate pressed
##   M3 - LandingScreen emits parent_pressed when BtnParent pressed
##   M4 - setup() accepts profile + project_store + localization without error
##   M5 - _show_world_picker makes PickerLayer visible
##   M6 - _show_world_picker populates CardRow with cards for profile's projects
##   M7 - world_card_pressed emits correct project_id and world_id
##   M8 - PolishLocalizationPolicy has all landing.* keys
##   M9 - InboundMain has SHELL_LANDING constant
##   M10 - _start_cloud_drift creates tweens for Cloud1-3 without error
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_play_pressed_signal()
	await _test_create_pressed_signal()
	await _test_parent_pressed_signal()
	await _test_setup_no_error()
	await _test_show_world_picker_visible()
	await _test_show_world_picker_populates_cards()
	await _test_world_card_pressed_signal()
	_test_polish_localization_has_landing_keys()
	_test_inbound_main_has_shell_landing()
	await _test_cloud_drift_no_error()
	print("ALL_LANDING_SCREEN_TESTS: PASS")
	quit(0)


## M1 - _on_play_pressed() emits play_pressed signal
## Note: GDScript 4 lambdas capture primitives by value; use Array wrapper for mutable capture.
func _test_play_pressed_signal() -> void:
	var screen := LandingScreen.new()
	get_root().add_child(screen)
	await process_frame
	var fired := [false]
	screen.play_pressed.connect(func(): fired[0] = true)
	screen._on_play_pressed()
	if not fired[0]:
		print("FAIL M1: play_pressed not emitted")
		screen.queue_free()
		quit(1)
		return
	print("PASS M1: play_pressed emitted")
	screen.queue_free()


## M2 - _on_create_pressed() emits create_pressed signal
func _test_create_pressed_signal() -> void:
	var screen := LandingScreen.new()
	get_root().add_child(screen)
	await process_frame
	var fired := [false]
	screen.create_pressed.connect(func(): fired[0] = true)
	screen._on_create_pressed()
	if not fired[0]:
		print("FAIL M2: create_pressed not emitted")
		screen.queue_free()
		quit(1)
		return
	print("PASS M2: create_pressed emitted")
	screen.queue_free()


## M3 - _on_parent_pressed() emits parent_pressed signal
func _test_parent_pressed_signal() -> void:
	var screen := LandingScreen.new()
	get_root().add_child(screen)
	await process_frame
	var fired := [false]
	screen.parent_pressed.connect(func(): fired[0] = true)
	screen._on_parent_pressed()
	if not fired[0]:
		print("FAIL M3: parent_pressed not emitted")
		screen.queue_free()
		quit(1)
		return
	print("PASS M3: parent_pressed emitted")
	screen.queue_free()


## M4 - setup() with all dependencies completes without error
func _test_setup_no_error() -> void:
	var screen := LandingScreen.new()
	get_root().add_child(screen)
	await process_frame
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var store := MockProjectStore.new()
	var loc := MockLocalizationPolicy.new()
	var result = screen.setup(profile, store, loc)
	if result == null:
		print("FAIL M4: setup() returned null")
		screen.queue_free()
		quit(1)
		return
	print("PASS M4: setup() completed without error")
	screen.queue_free()


## M5 - _show_world_picker makes PickerLayer visible
func _test_show_world_picker_visible() -> void:
	var screen := LandingScreen.new()
	get_root().add_child(screen)
	await process_frame
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var store := MockProjectStore.new()
	screen.setup(profile, store, null)
	var picker := screen.get_node("PickerLayer")
	if picker.visible:
		print("FAIL M5: PickerLayer should start hidden")
		screen.queue_free()
		quit(1)
		return
	screen._show_world_picker()
	if not picker.visible:
		print("FAIL M5: PickerLayer not visible after _show_world_picker()")
		screen.queue_free()
		quit(1)
		return
	print("PASS M5: PickerLayer visible after _show_world_picker()")
	screen.queue_free()


## M6 - _show_world_picker populates cards for profile's projects
func _test_show_world_picker_populates_cards() -> void:
	var screen := LandingScreen.new()
	get_root().add_child(screen)
	await process_frame
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var store := MockProjectStore.new()
	# 2 starter projects for kid_1, 1 for another user — expect 2 cards.
	# Project IDs must contain "_starter_" to pass the picker filter that hides
	# legacy/stale projects (e.g. starter_canvas). See landing_screen.gd
	# _show_world_picker.
	store.projects = [
		_make_project("kid_1_starter_p1", "kid_1", "Wyspa"),
		_make_project("kid_1_starter_p2", "kid_1", "Farma"),
		_make_project("other_kid_starter_p3", "other_kid", "Inne"),
	]
	screen.setup(profile, store, null)
	screen._show_world_picker()
	await process_frame
	var card_row := screen.get_node("PickerLayer/PickerScroll/CardRow")
	var card_count := card_row.get_child_count()
	if card_count != 2:
		print("FAIL M6: expected 2 cards for kid_1, got %d" % card_count)
		screen.queue_free()
		quit(1)
		return
	print("PASS M6: %d cards populated for kid_1" % card_count)
	screen.queue_free()


## M7 - pressing a world card emits world_card_pressed with correct ids
func _test_world_card_pressed_signal() -> void:
	var screen := LandingScreen.new()
	get_root().add_child(screen)
	await process_frame
	var profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var store := MockProjectStore.new()
	var proj := _make_project("kid_1_starter_project_abc", "kid_1", "Test")
	var world := World.new("world_xyz", "Test World")
	proj.add_world(world)
	store.projects = [proj]
	screen.setup(profile, store, null)
	screen._show_world_picker()
	await process_frame
	var captured := ["", ""]
	screen.world_card_pressed.connect(func(pid, wid):
		captured[0] = pid
		captured[1] = wid
	)
	var card_row := screen.get_node("PickerLayer/PickerScroll/CardRow")
	var card := card_row.get_child(0) as Button
	card.pressed.emit()
	if captured[0] != "kid_1_starter_project_abc":
		print("FAIL M7: wrong project_id '%s'" % captured[0])
		screen.queue_free()
		quit(1)
		return
	if captured[1] != "world_xyz":
		print("FAIL M7: wrong world_id '%s'" % captured[1])
		screen.queue_free()
		quit(1)
		return
	print("PASS M7: world_card_pressed emitted with correct ids")
	screen.queue_free()


## M8 - PolishLocalizationPolicy has all landing.* keys
func _test_polish_localization_has_landing_keys() -> void:
	var policy := PolishLocalizationPolicy.new()
	var required_keys: Array[String] = [
		"landing.play",
		"landing.create",
		"landing.parent",
		"landing.title",
		"landing.picker.title",
		"landing.picker.close",
		"landing.world.adventure",
		"landing.world.farm",
		"landing.world.forest",
	]
	for key in required_keys:
		var val := policy.translate(key)
		if val == key:
			print("FAIL M8: PolishLocalizationPolicy missing key '%s'" % key)
			quit(1)
			return
	print("PASS M8: PolishLocalizationPolicy has all landing.* keys")


## M9 - InboundMain has SHELL_LANDING constant
func _test_inbound_main_has_shell_landing() -> void:
	var script := load("res://src/adapters/inbound/main.gd")
	if script == null:
		print("FAIL M9: could not load main.gd")
		quit(1)
		return
	# GDScript 4.x: script constants accessible as properties on the Script object.
	var val = script.get("SHELL_LANDING")
	if val != "landing":
		print("FAIL M9: SHELL_LANDING = '%s', expected 'landing'" % str(val))
		quit(1)
		return
	print("PASS M9: SHELL_LANDING = 'landing'")


## M10 - _start_cloud_drift creates tweens without error
func _test_cloud_drift_no_error() -> void:
	var screen := LandingScreen.new()
	get_root().add_child(screen)
	await process_frame
	var tween_count := screen._cloud_tweens.size()
	if tween_count == 0:
		print("FAIL M10: no cloud tweens created (expected up to 3)")
		screen.queue_free()
		quit(1)
		return
	print("PASS M10: %d cloud tween(s) created" % tween_count)
	screen.queue_free()


# ---------- helpers ----------

func _make_project(pid: String, owner_id: String, title: String) -> Project:
	var p := Project.new(pid, title)
	p.owner_profile_id = owner_id
	p.template_id = "adventure"
	return p


class MockProjectStore extends ProjectStorePort:
	var projects: Array = []

	func list_projects() -> Array:
		return projects

	func load_project(_id: String) -> Project:
		return null

	func save_project(_project: Project) -> bool:
		return true

	func delete_project(_id: String) -> void:
		pass


class MockLocalizationPolicy extends LocalizationPolicyPort:
	var queried_keys: Array[String] = []

	func translate(key: String) -> String:
		queried_keys.append(key)
		return key

	func is_term_safe(_term: String) -> bool:
		return true

	func get_preferred_term(term_key: String) -> String:
		return term_key

	func get_parent_term(term_key: String) -> String:
		return term_key

	func get_locale() -> String:
		return "pl-PL"
