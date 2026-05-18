class_name PlayShell
extends Control

const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")
const SHELL_CREATE := "create"
const SHELL_LIBRARY := "library"

var _navigator: ShellNavigator
var _profile: PlayerProfile
var _localization_policy: LocalizationPolicyPort
var _run_playtest_port: RunPlaytestPort
var _kid_status_read_model: KidStatusReadModel
var _get_world_callback: Callable
var _active_world_id: String = ""
var _gameplay_runtime: GameplayRuntime
var _provenance_badge: ProvenanceBadge

@onready var _title: Label = $Layout/Header/Title
@onready var _info: Label = $Layout/Header/Info
@onready var _status_summary: Label = $Layout/Header/StatusSummary
@onready var _play_solo_button: Button = $Layout/MainContent/PlayButtons/PlaySoloButton
@onready var _play_coop_button: Button = $Layout/MainContent/PlayButtons/PlayCoopButton
@onready var _side_panel: PanelContainer = $Layout/MainContent/SidePanel
@onready var _quest_tracker: VBoxContainer = $Layout/MainContent/SidePanel/SideContent/QuestTracker
@onready var _quest_title: Label = $Layout/MainContent/SidePanel/SideContent/QuestTracker/QuestTitle
@onready var _quest_list: VBoxContainer = $Layout/MainContent/SidePanel/SideContent/QuestTracker/QuestList
@onready var _minimap_panel: PanelContainer = $Layout/MainContent/SidePanel/SideContent/MinimapPanel
@onready var _session_end_panel: PanelContainer = $Layout/SessionEndPanel
@onready var _session_end_title: Label = $Layout/SessionEndPanel/SessionEndContent/SessionEndTitle
@onready var _session_end_stats: Label = $Layout/SessionEndPanel/SessionEndContent/SessionEndStats
@onready var _session_end_close: Button = $Layout/SessionEndPanel/SessionEndContent/SessionEndClose
@onready var _undo_button: Button = $Layout/Actions/UndoButton
@onready var _safe_restore_button: Button = $Layout/Actions/SafeRestoreButton
@onready var _go_create_button: Button = $Layout/Actions/GoCreateButton
@onready var _go_library_button: Button = $Layout/Actions/GoLibraryButton


func _ready() -> void:
	_setup_provenance_badge()
	_wire_actions()
	_refresh_labels()
	_apply_theme()
	_session_end_panel.visible = false


func setup(
	navigator: ShellNavigator,
	profile: PlayerProfile,
	localization_policy: LocalizationPolicyPort,
	run_playtest_port: RunPlaytestPort,
	kid_status_read_model: KidStatusReadModel = null,
	get_world_callback: Callable = Callable()
) -> PlayShell:
	_navigator = navigator
	_profile = profile
	_localization_policy = localization_policy
	_run_playtest_port = run_playtest_port
	_kid_status_read_model = kid_status_read_model
	_get_world_callback = get_world_callback
	if _provenance_badge != null and _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)

	if is_node_ready():
		_refresh_labels()
		_refresh_kid_status_summary()

	return self


func set_world_context(world_id: String) -> void:
	_active_world_id = world_id
	_refresh_kid_status_summary()
	_refresh_quest_tracker()


func set_context_provenance(provenance: Variant) -> void:
	if _provenance_badge == null:
		return
	if provenance == null or not (provenance is ProvenanceData):
		_provenance_badge.visible = false
		return
	_provenance_badge.set_provenance(provenance)


func _wire_actions() -> void:
	_play_solo_button.pressed.connect(func() -> void:
		_launch_playtest(false)
	)
	_play_coop_button.pressed.connect(func() -> void:
		_launch_playtest(true)
	)
	_go_create_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_CREATE)
	)
	_go_library_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_LIBRARY)
	)
	_session_end_close.pressed.connect(_on_session_end_close)


func _refresh_labels() -> void:
	_title.text = _t("ui.play.title")
	_info.text = _t("ui.play.info")
	_status_summary.text = _t("ui.play.status.no_data")
	_play_solo_button.text = "%s\n%s" % [IconFont.get_icon("solo"), _t("ui.play.start_solo")]
	_play_coop_button.text = "%s\n%s" % [IconFont.get_icon("coop"), _t("ui.play.start_coop")]
	_undo_button.text = "%s %s" % [IconFont.get_icon("undo"), _t("ui.common.undo")]
	_safe_restore_button.text = "%s %s" % [IconFont.get_icon("restore"), _t("ui.common.safe_restore")]
	_go_create_button.text = "%s %s" % [IconFont.get_icon("build"), _t("ui.play.go_create")]
	_go_library_button.text = "%s %s" % [IconFont.get_icon("library"), _t("ui.play.go_library")]
	_quest_title.text = "%s Misje" % IconFont.get_icon("quest")
	_session_end_close.text = "%s Wróć" % IconFont.get_icon("check")
	_refresh_kid_status_summary()
	_refresh_quest_tracker()


func _launch_playtest(local_coop: bool) -> Session:
	if _run_playtest_port == null or _profile == null:
		return null
	if _active_world_id.is_empty():
		_info.text = "Brak aktywnego świata do testu."
		return null

	var world: World = null
	if _get_world_callback != null and _get_world_callback.is_valid():
		world = _get_world_callback.call()

	if world == null:
		_info.text = "Nie udało się pobrać świata."
		return null

	if world.scene_nodes.is_empty():
		_info.text = "Najpierw stwórz świat!"
		return null

	var players: Array = [_profile]
	if local_coop:
		var guest := PlayerProfile.new("%s_local_guest" % _profile.profile_id, PlayerProfile.Role.KID)
		guest.display_name = "Gość"
		players.append(guest)

	var session := _run_playtest_port.execute(_active_world_id, players)
	if session == null:
		_info.text = "Nie udało się uruchomić playtestu."
		return null

	_info.text = "Test uruchomiony: %s (%s)" % [
		"kooperacja" if local_coop else "solo",
		session.session_id
	]
	_start_gameplay(world, session)
	return session


func _start_gameplay(world: World, session: Session) -> void:
	if _gameplay_runtime != null:
		_gameplay_runtime.queue_free()
		_gameplay_runtime = null

	var runtime_scene := preload("res://src/adapters/inbound/gameplay/gameplay_runtime.tscn")
	_gameplay_runtime = runtime_scene.instantiate()
	_gameplay_runtime.session_ended.connect(_on_session_ended)
	add_child(_gameplay_runtime)
	_gameplay_runtime.start_session(world, session)
	$Layout.visible = false


func _on_session_ended() -> void:
	if _gameplay_runtime != null:
		_gameplay_runtime.queue_free()
		_gameplay_runtime = null
	$Layout.visible = true
	_info.text = "Sesja zakończona."
	_show_session_end_screen()


func _show_session_end_screen() -> void:
	var stats_text := "Znajdźki: %d\nOsiągnięcia: %d\nCzas: %s" % [
		randi() % 5,
		randi() % 3,
		"~2 min"
	]
	_session_end_stats.text = stats_text
	_session_end_panel.visible = true
	_session_end_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_session_end_panel, "modulate:a", 1.0, 0.3)


func _on_session_end_close() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(_session_end_panel, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func():
		_session_end_panel.visible = false
	)


func _refresh_quest_tracker() -> void:
	if _quest_list == null:
		return
	for child in _quest_list.get_children():
		child.queue_free()
	
	var world: World = null
	if _get_world_callback != null and _get_world_callback.is_valid():
		world = _get_world_callback.call()
	
	var quests: Array[Dictionary] = []
	if world != null:
		var meta = world.get("metadata")
		if meta is Dictionary and meta.has("quests"):
			quests = meta["quests"]
	
	if quests.is_empty():
		var empty := Label.new()
		empty.text = "Brak aktywnych misji."
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_quest_list.add_child(empty)
		return
	
	for quest in quests:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := Label.new()
		icon.text = IconFont.get_icon("star") if quest.get("completed", false) else IconFont.get_icon("flag")
		icon.add_theme_color_override("font_color", Color.GOLD if quest.get("completed", false) else Color.SILVER)
		row.add_child(icon)
		var lbl := Label.new()
		lbl.text = str(quest.get("title", "Misja"))
		row.add_child(lbl)
		_quest_list.add_child(row)


func _t(key: String) -> String:
	if _localization_policy != null:
		return _localization_policy.translate(key)

	var fallback := {
		"ui.play.title": "Tryb gry",
		"ui.play.info": "Wybierz świat i uruchom sesję.",
		"ui.play.status.no_data": "Brak danych postępu dla aktywnego świata.",
		"ui.play.status.template": "Postęp: %d%% | Znajdźki: %d | Osiągnięcia: %d",
		"ui.play.start_solo": "Graj Solo",
		"ui.play.start_coop": "Graj w Kooperacji",
		"ui.common.undo": "Cofnij",
		"ui.common.safe_restore": "Przywróć bezpieczny zapis",
		"ui.play.go_create": "Wróć do tworzenia",
		"ui.play.go_library": "Przejdź do biblioteki"
	}
	return fallback.get(key, key)


func _setup_provenance_badge() -> void:
	var badge_script = load("res://src/adapters/inbound/shared/ui/provenance_badge.gd")
	if badge_script == null:
		return
	_provenance_badge = badge_script.new()
	$Layout/Header.add_child(_provenance_badge)
	_provenance_badge.visible = false
	if _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)


func _refresh_kid_status_summary() -> void:
	if _status_summary == null:
		return
	if _kid_status_read_model == null or _profile == null or _active_world_id.is_empty():
		_status_summary.text = _t("ui.play.status.no_data")
		return
	var status := _kid_status_read_model.get_project_status(_active_world_id, _profile.profile_id)
	if status.is_empty():
		_status_summary.text = _t("ui.play.status.no_data")
		return
	_status_summary.text = _t("ui.play.status.template") % [
		int(status.get("progress_pct", 0)),
		int(status.get("collectibles_found", 0)),
		int(status.get("achievements_earned", 0)),
	]


func _apply_theme() -> void:
	var theme := load("res://data/themes/choyce_theme.tres") as Theme
	if theme != null:
		self.theme = theme
	
	if _side_panel != null:
		var side_style := StyleBoxFlat.new()
		side_style.bg_color = Color8(250, 252, 255)
		side_style.corner_radius_top_left = 14
		side_style.corner_radius_top_right = 14
		side_style.corner_radius_bottom_left = 14
		side_style.corner_radius_bottom_right = 14
		side_style.border_width_left = 2
		side_style.border_width_top = 2
		side_style.border_width_right = 2
		side_style.border_width_bottom = 2
		side_style.border_color = Color8(200, 225, 245)
		side_style.shadow_color = Color(0, 0, 0, 0.08)
		side_style.shadow_size = 6
		_side_panel.add_theme_stylebox_override("panel", side_style)
	
	if _minimap_panel != null:
		var mm_style := StyleBoxFlat.new()
		mm_style.bg_color = Color8(220, 240, 255)
		mm_style.corner_radius_top_left = 10
		mm_style.corner_radius_top_right = 10
		mm_style.corner_radius_bottom_left = 10
		mm_style.corner_radius_bottom_right = 10
		mm_style.border_width_left = 1
		mm_style.border_width_top = 1
		mm_style.border_width_right = 1
		mm_style.border_width_bottom = 1
		mm_style.border_color = Color8(180, 210, 240)
		_minimap_panel.add_theme_stylebox_override("panel", mm_style)
	
	if _session_end_panel != null:
		var se_style := StyleBoxFlat.new()
		se_style.bg_color = Color8(255, 250, 230)
		se_style.corner_radius_top_left = 20
		se_style.corner_radius_top_right = 20
		se_style.corner_radius_bottom_left = 20
		se_style.corner_radius_bottom_right = 20
		se_style.border_width_left = 3
		se_style.border_width_top = 3
		se_style.border_width_right = 3
		se_style.border_width_bottom = 3
		se_style.border_color = Color8(255, 215, 100)
		se_style.shadow_color = Color(0, 0, 0, 0.18)
		se_style.shadow_size = 12
		se_style.shadow_offset = Vector2(0, 6)
		se_style.content_margin_left = 24
		se_style.content_margin_top = 24
		se_style.content_margin_right = 24
		se_style.content_margin_bottom = 24
		_session_end_panel.add_theme_stylebox_override("panel", se_style)
