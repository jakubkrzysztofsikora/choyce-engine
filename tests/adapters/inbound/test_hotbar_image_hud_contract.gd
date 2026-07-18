## Picture-first HUD contract for the Adventure hotbar.
extends SceneTree

const GameplayRuntime = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
const GameplayRuntimeScene = preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")

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
	var source := FileAccess.get_file_as_string("res://src/adapters/inbound/gameplay/gameplay_runtime.gd")
	_assert(source.contains("func _rebuild_hotbar_panel(active_slot: int)")
		and source.contains("icon.texture = _hotbar_texture_for")
		and source.contains("slot.tooltip_text = String(entry[\"name\"])")
		and not source.contains("var num_label := Label.new()")
		and not source.contains("num_label.text = \"%d\" % (i + 1)"),
		"Adventure hotbar is icon-led with no visible numeric legend")
	var runtime := GameplayRuntimeScene.instantiate() as GameplayRuntime
	runtime.name = "HotbarContractRuntime"
	get_root().add_child(runtime)
	runtime._build_hud()
	var hotbar := runtime.get_node_or_null("HUD/Hotbar") as HBoxContainer
	_assert(hotbar != null and hotbar.get_child_count() == 5,
		"live HUD builds five picture-first hotbar slots")
	if hotbar != null:
		var active_border_ok := false
		for i in hotbar.get_child_count():
			var slot := hotbar.get_child(i) as Control
			var icons := slot.find_children("*", "TextureRect", false, false) if slot != null else []
			var panels := slot.find_children("*", "PanelContainer", false, false) if slot != null else []
			var icon := icons[0] as TextureRect if not icons.is_empty() else null
			var panel := panels[0] as PanelContainer if not panels.is_empty() else null
			var labels := slot.find_children("*", "Label", true, false) if slot != null else []
			_assert(icon != null and icon.texture != null and labels.is_empty(),
				"live slot %d has an image and no visible text label" % i)
			if i == 0 and panel != null:
				var active_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
				active_border_ok = active_style != null and active_style.border_color.r > 0.70 and active_style.bg_color.a > 0.85
		_assert(active_border_ok, "active hotbar slot has a high-contrast non-text border state")
	var menu := runtime.get_node_or_null("HUD/AdventureMenuBtn") as MenuButton
	var menu_style := menu.get_theme_stylebox("normal") as StyleBoxFlat if menu != null else null
	_assert(menu != null and menu.size.x <= 40.0 and menu.size.y <= 40.0
		and menu_style != null and menu_style.bg_color.a <= 0.65,
		"first-frame utility menu is compact and visually quieter than the game world")
	var stats := runtime.get_node_or_null("HUD/StatsPanel") as PanelContainer
	var vitality := runtime.get_node_or_null("HUD/StatsPanel/PictorialVitalityMeter") as Control
	var stat_labels := stats.find_children("*", "Label", true, false) if stats != null else []
	_assert(stats != null and not stats.visible and vitality != null and stat_labels.is_empty(),
		"damage-only combat status is a compact pictorial meter with no visible text dashboard")
	runtime._on_player_hp_changed(20, 100)
	_assert(stats != null and stats.visible and vitality != null
		and is_equal_approx(float(vitality.get("_vitality")), 0.2),
		"taking damage reveals the pictorial vitality meter at the correct health fraction")
	var prompt := runtime.get_node_or_null("HUD/InteractionPrompt") as PanelContainer
	var prompt_icon := prompt.find_child("InteractionIcon", true, false) as TextureRect if prompt != null else null
	var prompt_label := prompt.find_child("InteractionPromptLabel", true, false) as Label if prompt != null else null
	_assert(prompt != null and (prompt.offset_right - prompt.offset_left) <= 120.0
		and (prompt.offset_bottom - prompt.offset_top) <= 110.0
		and prompt_icon != null and prompt_icon.texture != null
		and prompt_label != null and not prompt_label.visible,
		"context actions render as a compact image badge rather than a text instruction")
	runtime.queue_free()
	quit(_exit_code)
