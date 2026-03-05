class_name PlayShell
extends Control

const SHELL_CREATE := "create"
const SHELL_LIBRARY := "library"

var _navigator: ShellNavigator
var _profile: PlayerProfile
var _localization_policy: LocalizationPolicyPort
var _run_playtest_port: RunPlaytestPort
var _kid_status_read_model: KidStatusReadModel
var _active_world_id: String = ""
var _provenance_badge: ProvenanceBadge

@onready var _title: Label = $Layout/Header/Title
@onready var _info: Label = $Layout/Header/Info
@onready var _status_summary: Label = $Layout/Header/StatusSummary
@onready var _play_solo_button: Button = $Layout/Actions/PlaySoloButton
@onready var _play_coop_button: Button = $Layout/Actions/PlayCoopButton
@onready var _undo_button: Button = $Layout/Actions/UndoButton
@onready var _safe_restore_button: Button = $Layout/Actions/SafeRestoreButton
@onready var _go_create_button: Button = $Layout/Actions/GoCreateButton
@onready var _go_library_button: Button = $Layout/Actions/GoLibraryButton


func _ready() -> void:
	_setup_provenance_badge()
	_wire_actions()
	_refresh_labels()


func setup(
	navigator: ShellNavigator,
	profile: PlayerProfile,
	localization_policy: LocalizationPolicyPort,
	run_playtest_port: RunPlaytestPort,
	kid_status_read_model: KidStatusReadModel = null
) -> PlayShell:
	_navigator = navigator
	_profile = profile
	_localization_policy = localization_policy
	_run_playtest_port = run_playtest_port
	_kid_status_read_model = kid_status_read_model
	if _provenance_badge != null and _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)

	if is_node_ready():
		_refresh_labels()
		_refresh_kid_status_summary()

	return self


func set_world_context(world_id: String) -> void:
	_active_world_id = world_id
	_refresh_kid_status_summary()


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


func _refresh_labels() -> void:
	_title.text = _t("ui.play.title")
	_info.text = _t("ui.play.info")
	_status_summary.text = _t("ui.play.status.no_data")
	_play_solo_button.text = _t("ui.play.start_solo")
	_play_coop_button.text = _t("ui.play.start_coop")
	_undo_button.text = _t("ui.common.undo")
	_safe_restore_button.text = _t("ui.common.safe_restore")
	_go_create_button.text = _t("ui.play.go_create")
	_go_library_button.text = _t("ui.play.go_library")
	_refresh_kid_status_summary()


func _launch_playtest(local_coop: bool) -> Session:
	if _run_playtest_port == null or _profile == null:
		return null
	if _active_world_id.is_empty():
		_info.text = "Brak aktywnego swiata do testu."
		return null

	var players: Array = [_profile]
	if local_coop:
		var guest := PlayerProfile.new("%s_local_guest" % _profile.profile_id, PlayerProfile.Role.KID)
		guest.display_name = "Gosc"
		players.append(guest)

	var session := _run_playtest_port.execute(_active_world_id, players)
	if session == null:
		_info.text = "Nie udalo sie uruchomic playtestu."
		return null

	_info.text = "Test uruchomiony: %s (%s)" % [
		"kooperacja" if local_coop else "solo",
		session.session_id
	]
	return session


func _t(key: String) -> String:
	if _localization_policy != null:
		return _localization_policy.translate(key)

	var fallback := {
		"ui.play.title": "Tryb gry",
		"ui.play.info": "Wybierz świat i uruchom sesję.",
		"ui.play.status.no_data": "Brak danych postepu dla aktywnego swiata.",
		"ui.play.status.template": "Postep: %d%% | Znajdzki: %d | Osiagniecia: %d",
		"ui.play.start_solo": "Start solo",
		"ui.play.start_coop": "Start lokalnej kooperacji",
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
