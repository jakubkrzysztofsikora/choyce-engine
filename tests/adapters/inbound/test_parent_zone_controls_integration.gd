extends SceneTree


class StubLocalization:
	extends LocalizationPolicyPort

	func get_locale() -> String:
		return "pl-PL"

	func translate(key: String) -> String:
		return key

	func is_term_safe(_term: String) -> bool:
		return true


class StubSetParentalControls:
	extends SetParentalControlsPort

	var call_count: int = 0
	var last_parent_id: String = ""
	var last_settings: Dictionary = {}

	func execute(parent: PlayerProfile, settings: Dictionary) -> bool:
		call_count += 1
		last_parent_id = parent.profile_id if parent != null else ""
		last_settings = settings.duplicate(true)
		return parent != null and parent.is_parent()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://src/adapters/inbound/scenes/parent/parent_zone_shell.tscn")
	if not (scene is PackedScene):
		_fail("ParentZoneShell scene failed to load")
		return

	var shell: ParentZoneShell = (scene as PackedScene).instantiate()
	var set_controls_stub := StubSetParentalControls.new()
	var navigator := ShellNavigator.new()
	get_root().add_child(shell)

	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)
	shell.setup(navigator, parent, StubLocalization.new(), set_controls_stub)
	await process_frame

	var daily_spin: SpinBox = shell.get_node("Layout/ControlsPanel/Controls/SettingsGrid/DailyLimitSpin")
	var session_spin: SpinBox = shell.get_node("Layout/ControlsPanel/Controls/SettingsGrid/SessionLimitSpin")
	var ai_option: OptionButton = shell.get_node("Layout/ControlsPanel/Controls/SettingsGrid/AIAccessOption")
	var sharing_toggle: CheckBox = shell.get_node("Layout/ControlsPanel/Controls/SettingsGrid/SharingToggle")
	var language_toggle: CheckBox = shell.get_node("Layout/ControlsPanel/Controls/SettingsGrid/LanguageOverrideToggle")
	var cloud_toggle: CheckBox = shell.get_node("Layout/ControlsPanel/Controls/SettingsGrid/CloudSyncToggle")
	var apply_button: Button = shell.get_node("Layout/ControlsPanel/Controls/ApplyPolicyButton")

	daily_spin.value = 95
	session_spin.value = 35
	ai_option.select(2) # AI_FULL
	sharing_toggle.button_pressed = true
	language_toggle.button_pressed = true
	cloud_toggle.button_pressed = true
	apply_button.emit_signal("pressed")

	if set_controls_stub.call_count != 1:
		_fail("Expected one policy submit call from parent shell")
		return
	if set_controls_stub.last_parent_id != "parent-1":
		_fail("Parent profile attribution missing from settings submit")
		return
	if int(set_controls_stub.last_settings.get("playtime_limit", {}).get("daily", -1)) != 95:
		_fail("Daily playtime limit was not submitted")
		return
	if str(set_controls_stub.last_settings.get("ai_access", "")) != "full":
		_fail("AI access selection was not submitted as expected")
		return
	if not bool(set_controls_stub.last_settings.get("sharing_permissions", false)):
		_fail("Sharing permission toggle was not submitted")
		return

	# Kid profile should not be able to apply controls.
	var kid_shell: ParentZoneShell = (scene as PackedScene).instantiate()
	get_root().add_child(kid_shell)
	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	kid_shell.setup(navigator, kid, StubLocalization.new(), set_controls_stub)
	await process_frame
	if kid_shell.visible:
		_fail("Kid profile should not see ParentZoneShell controls")
		return

	print("PARENT_ZONE_CONTROLS_TEST: PASS")
	shell.queue_free()
	kid_shell.queue_free()
	quit(0)


func _fail(message: String) -> void:
	print("FAIL: %s" % message)
	quit(1)
