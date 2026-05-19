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
var _no_world_cta_button: Button = null
var _voice_prompt_port: VoicePromptPort = null
var _cta_voice_timer: Timer = null
var _session_start_time: float = 0.0
var _project_store: ProjectStorePort = null  # injected for direct-launch path

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
@onready var _celebration_layer: CanvasLayer = $CelebrationLayer
@onready var _celebration_panel: PanelContainer = $CelebrationLayer/CelebrationPanel
@onready var _confetti: CPUParticles2D = $CelebrationLayer/ConfettiBurst
@onready var _collectibles_count: Label = $CelebrationLayer/CelebrationPanel/CelebrationContent/StatsRow/Collectibles/Count
@onready var _achievements_count: Label = $CelebrationLayer/CelebrationPanel/CelebrationContent/StatsRow/Achievements/Count
@onready var _time_count: Label = $CelebrationLayer/CelebrationPanel/CelebrationContent/StatsRow/Time/Count
@onready var _celebration_title: Label = $CelebrationLayer/CelebrationPanel/CelebrationContent/TitleLabel
@onready var _celebration_close: Button = $CelebrationLayer/CelebrationPanel/CelebrationContent/CloseButton
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
	_celebration_layer.visible = false


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


func setup_voice_prompt(port: VoicePromptPort) -> void:
	_voice_prompt_port = port


func setup_for_direct_launch(project_store: ProjectStorePort) -> void:
	_project_store = project_store


func set_profile(profile: PlayerProfile) -> void:
	_profile = profile


func launch_world_by_id(project_id: String, world_id: String) -> void:
	if _project_store == null:
		push_warning("PlayShell.launch_world_by_id called before _project_store wired")
		return
	var project: Project = _project_store.load_project(project_id)
	if project == null:
		push_warning("PlayShell.launch_world_by_id: project not found %s" % project_id)
		return
	# Find the world inside the project
	var world: World = null
	for w in project.worlds:
		if w.world_id == world_id or (world_id.is_empty() and w.is_playable):
			world = w
			break
	if world == null and not project.worlds.is_empty():
		world = project.worlds[0]
	if world == null:
		push_warning("PlayShell.launch_world_by_id: no world in project %s" % project_id)
		return
	# Pick music track based on template
	_play_world_music(project.template_id)

	# Set context and start a session directly via _run_playtest_port
	_active_world_id = world.world_id
	if _run_playtest_port == null:
		push_warning("PlayShell.launch_world_by_id: run_playtest_port not ready")
		return
	# RunPlaytestPort contract: players is Array[PlayerProfile], not strings.
	# RunPlaytestService reads players[i].profile_id during session.add_player.
	var players: Array = [_profile] if _profile != null else []
	var session: Session = _run_playtest_port.execute(world.world_id, players)
	if session == null:
		push_warning("PlayShell.launch_world_by_id: session creation failed")
		return
	_start_gameplay(world, session)


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


func get_no_world_cta_button() -> Button:
	return _no_world_cta_button


func _show_no_world_cta() -> void:
	if _no_world_cta_button != null:
		_no_world_cta_button.queue_free()
		_no_world_cta_button = null
	if _cta_voice_timer != null:
		_cta_voice_timer.queue_free()
		_cta_voice_timer = null

	_no_world_cta_button = Button.new()
	_no_world_cta_button.text = "%s %s" % [
		IconFont.get_icon("hammer"),
		_t("play.cta.create_world")
	]
	_no_world_cta_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_CREATE)
	)
	var content_parent: Node = get_node_or_null("Layout/MainContent")
	if content_parent != null:
		content_parent.add_child(_no_world_cta_button)
	else:
		add_child(_no_world_cta_button)

	# Voice prompt after 3s for non-readers (optional port)
	if _voice_prompt_port != null:
		_cta_voice_timer = Timer.new()
		_cta_voice_timer.wait_time = 3.0
		_cta_voice_timer.one_shot = true
		_cta_voice_timer.timeout.connect(func() -> void:
			if _voice_prompt_port != null and _voice_prompt_port.is_available():
				_voice_prompt_port.speak(_t("play.cta.create_world_voice"))
		)
		add_child(_cta_voice_timer)
		_cta_voice_timer.start()


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
	_celebration_close.pressed.connect(hide_celebration)


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
	_quest_title.text = "%s %s" % [IconFont.get_icon("quest"), _t("play.quest.title")]
	_session_end_close.text = "%s %s" % [IconFont.get_icon("check"), _t("play.session.close")]
	_refresh_kid_status_summary()
	_refresh_quest_tracker()


func _launch_playtest(local_coop: bool) -> Session:
	if _run_playtest_port == null or _profile == null:
		return null
	if _active_world_id.is_empty():
		_info.text = _t("play.error.no_world")
		return null

	var world: World = null
	if _get_world_callback != null and _get_world_callback.is_valid():
		world = _get_world_callback.call()

	if world == null:
		_info.text = _t("play.error.load_failed")
		return null

	if world.scene_nodes.is_empty():
		_info.text = _t("play.error.create_first")
		return null

	var players: Array = [_profile]
	if local_coop:
		var guest := PlayerProfile.new("%s_local_guest" % _profile.profile_id, PlayerProfile.Role.KID)
		guest.display_name = _t("play.guest.name")
		players.append(guest)

	var session := _run_playtest_port.execute(_active_world_id, players)
	if session == null:
		_info.text = _t("play.error.start_failed")
		return null

	var mode_label: String = _t("play.mode.coop") if local_coop else _t("play.mode.solo")
	_info.text = "%s: %s (%s)" % [_t("play.session.started"), mode_label, session.session_id]
	_session_start_time = Time.get_ticks_msec() / 1000.0
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
	_info.text = _t("play.session.ended")
	_show_session_end_screen()


func _show_session_end_screen() -> void:
	var elapsed_secs: int = 0
	if _session_start_time > 0.0:
		elapsed_secs = int(Time.get_ticks_msec() / 1000.0 - _session_start_time)
	_session_start_time = 0.0

	var collectibles: int = 0
	var achievements: int = 0

	if _kid_status_read_model != null and _profile != null and not _active_world_id.is_empty():
		var status := _kid_status_read_model.get_project_status(_active_world_id, _profile.profile_id)
		if not status.is_empty():
			collectibles = int(status.get("collectibles_found", 0))
			achievements = int(status.get("achievements_earned", 0))
			# elapsed_seconds from read model if available (richer adapter); else use in-shell timer
			if status.has("elapsed_seconds") and int(status.get("elapsed_seconds", 0)) > 0:
				elapsed_secs = int(status.get("elapsed_seconds", elapsed_secs))

	# Route through celebration overlay; old session_end_panel kept as fallback when nodes absent
	show_celebration({
		"collectibles": collectibles,
		"achievements": achievements,
		"elapsed_seconds": elapsed_secs,
	})


func show_celebration(stats: Dictionary) -> void:
	var collectibles: int = int(stats.get("collectibles", 0))
	var achievements: int = int(stats.get("achievements", 0))
	var elapsed_secs: int = int(stats.get("elapsed_seconds", 0))

	# Set initial counter values
	_collectibles_count.text = "0"
	_achievements_count.text = "0"
	_time_count.text = "0s"

	# Update column labels with localized strings
	var col_node := get_node_or_null("CelebrationLayer/CelebrationPanel/CelebrationContent/StatsRow/Collectibles/CLabel")
	if col_node != null:
		col_node.text = _t("play.session.collectibles_label")
	var ach_node := get_node_or_null("CelebrationLayer/CelebrationPanel/CelebrationContent/StatsRow/Achievements/ALabel")
	if ach_node != null:
		ach_node.text = _t("play.session.achievements_label")
	var time_node := get_node_or_null("CelebrationLayer/CelebrationPanel/CelebrationContent/StatsRow/Time/TLabel")
	if time_node != null:
		time_node.text = _t("play.session.time_label")
	if _celebration_close != null:
		_celebration_close.text = _t("play.celebration.close")

	# Title: kid-positive frame when no stats earned
	if collectibles == 0 and achievements == 0:
		_celebration_title.text = _t("play.session.try_again_friend")
	else:
		_celebration_title.text = _t("play.session.celebration_title")

	_celebration_layer.visible = true

	# Audio feedback on celebration
	var _bank := _audio_bank()
	if _bank != null:
		_bank.play_sfx("victory_fanfare")
		_bank.play_voice("celebrate_win")

	# Position confetti at top-center
	var vp_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1600, 900)
	_confetti.position = Vector2(vp_size.x / 2.0, 80.0)
	_confetti.emitting = false

	# Title bounce-in tween
	_celebration_title.scale = Vector2(0.4, 0.4)
	_celebration_title.modulate.a = 0.0
	var t_tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_tw.tween_property(_celebration_title, "scale", Vector2(1.0, 1.0), 0.4)
	t_tw.parallel().tween_property(_celebration_title, "modulate:a", 1.0, 0.3)

	# Confetti burst after brief delay
	await get_tree().create_timer(0.25).timeout
	_confetti.restart()
	_confetti.emitting = true

	# Tween counters from 0 to final values
	var ctw := create_tween().set_parallel(true)
	ctw.tween_method(
		func(v: float) -> void: _collectibles_count.text = str(int(v)),
		0.0, float(collectibles), 1.2
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ctw.tween_method(
		func(v: float) -> void: _achievements_count.text = str(int(v)),
		0.0, float(achievements), 1.2
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ctw.tween_method(
		func(v: float) -> void: _time_count.text = "%ds" % int(v),
		0.0, float(elapsed_secs), 1.2
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func hide_celebration() -> void:
	_celebration_layer.visible = false
	if _confetti != null:
		_confetti.emitting = false


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
		empty.text = _t("play.quests.empty")
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
		lbl.text = str(quest.get("title", _t("play.quest.default_title")))
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
		"ui.play.go_library": "Przejdź do biblioteki",
		"play.error.no_world": "Najpierw stwórz świat.",
		"play.error.load_failed": "Świat nie wczytał się.",
		"play.error.create_first": "Najpierw stwórz świat!",
		"play.error.start_failed": "Test nie ruszył.",
		"play.session.ended": "Koniec gry!",
		"play.session.close": "Wróć",
		"play.session.started": "Test uruchomiony",
		"play.session.try_again_friend": "Świetnie! Wróć po więcej.",
		"play.quests.empty": "Brak misji.",
		"play.quest.title": "Misje",
		"play.quest.default_title": "Misja",
		"play.mode.coop": "kooperacja",
		"play.mode.solo": "solo",
		"play.guest.name": "Gość",
		"play.stats.collectibles": "Znajdźki",
		"play.stats.achievements": "Osiągnięcia",
		"play.stats.time": "Czas",
		"play.cta.create_world": "Stwórz świat",
		"play.cta.create_world_voice": "Stwórz swój świat!",
		"play.session.celebration_title": "Świetna gra!",
		"play.session.collectibles_label": "Znajdźki",
		"play.session.achievements_label": "Osiągnięcia",
		"play.session.time_label": "Czas",
		"play.celebration.close": "Zagraj jeszcze",
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


func _audio_bank() -> Node:
	return get_node_or_null("/root/AudioBank")


func _play_world_music(template_id: String) -> void:
	var bank := _audio_bank()
	if bank == null:
		return
	var track_name: String
	match template_id:
		"adventure": track_name = "adventure_island"
		"farm":      track_name = "little_farm"
		"forest":    track_name = "mushroom_forest"
		_:           track_name = "landing_ambient"
	bank.play_music(track_name, true)


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
