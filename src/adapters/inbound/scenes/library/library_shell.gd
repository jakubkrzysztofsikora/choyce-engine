class_name LibraryShell
extends Control

const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")
const SHELL_CREATE := "create"
const SHELL_PLAY := "play"

var _navigator: ShellNavigator
var _profile: PlayerProfile
var _localization_policy: LocalizationPolicyPort
var _publish_port: PublishToFamilyLibraryPort
var _review_publish_port: ReviewPublishRequestPort
var _unpublish_port: UnpublishWorldPort
var _provenance_badge: ProvenanceBadge

## Phase 9: ports_ready gate — prevents handler calls before DI wiring completes.
var _ports_ready: bool = false

@onready var _title: Label = $Layout/Header/Title
@onready var _info: Label = $Layout/Header/Info
@onready var _project_id_input: LineEdit = $Layout/MainContent/PublishCard/PublishForm/ProjectIdInput
@onready var _world_id_input: LineEdit = $Layout/MainContent/PublishCard/PublishForm/WorldIdInput
@onready var _request_id_input: LineEdit = $Layout/MainContent/PublishCard/PublishForm/RequestIdInput
@onready var _publish_button: Button = $Layout/MainContent/PublishCard/PublishForm/Actions/PublishButton
@onready var _approve_button: Button = $Layout/MainContent/PublishCard/PublishForm/Actions/ApproveButton
@onready var _reject_button: Button = $Layout/MainContent/PublishCard/PublishForm/Actions/RejectButton
@onready var _unpublish_button: Button = $Layout/MainContent/PublishCard/PublishForm/Actions/UnpublishButton
@onready var _publish_status: Label = $Layout/MainContent/PublishCard/PublishForm/Status
@onready var _status_dot: PanelContainer = $Layout/MainContent/PublishCard/PublishForm/StatusRow/StatusDot
@onready var _status_text: Label = $Layout/MainContent/PublishCard/PublishForm/StatusRow/StatusText
@onready var _undo_button: Button = $Layout/Actions/UndoButton
@onready var _safe_restore_button: Button = $Layout/Actions/SafeRestoreButton
@onready var _go_create_button: Button = $Layout/Actions/GoCreateButton
@onready var _go_play_button: Button = $Layout/Actions/GoPlayButton


func _ready() -> void:
	_setup_provenance_badge()
	_wire_actions()
	_refresh_labels()
	_apply_theme()
	_update_status_dot("ready")


func setup(
	navigator: ShellNavigator,
	profile: PlayerProfile,
	localization_policy: LocalizationPolicyPort,
	publish_port: PublishToFamilyLibraryPort,
	review_publish_port: ReviewPublishRequestPort = null,
	unpublish_port: UnpublishWorldPort = null
) -> LibraryShell:
	_navigator = navigator
	_profile = profile
	_localization_policy = localization_policy
	_publish_port = publish_port
	_review_publish_port = review_publish_port
	_unpublish_port = unpublish_port
	if _provenance_badge != null and _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)

	if is_node_ready():
		_refresh_labels()
		_apply_role_state()

	return self


## Phase 9: called by inbound main when the ports_ready signal fires.
## Until this is called, all port-mutating handlers return silently.
func notify_ports_ready() -> void:
	_ports_ready = true


func _wire_actions() -> void:
	_publish_button.pressed.connect(_on_publish_pressed)
	_approve_button.pressed.connect(_on_approve_pressed)
	_reject_button.pressed.connect(_on_reject_pressed)
	_unpublish_button.pressed.connect(_on_unpublish_pressed)
	_go_create_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_CREATE)
	)
	_go_play_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_PLAY)
		)


func set_context_provenance(provenance: Variant) -> void:
	if _provenance_badge == null:
		return
	if provenance == null or not (provenance is ProvenanceData):
		_provenance_badge.visible = false
		return
	_provenance_badge.set_provenance(provenance)


func _refresh_labels() -> void:
	_title.text = _t("ui.library.title")
	_info.text = _t("ui.library.info")
	_project_id_input.placeholder_text = _t("ui.library.project_id")
	_world_id_input.placeholder_text = _t("ui.library.world_id")
	_request_id_input.placeholder_text = _t("ui.library.request_id")
	_publish_button.text = _t("ui.library.publish")
	_approve_button.text = _t("ui.library.approve")
	_reject_button.text = _t("ui.library.reject")
	_unpublish_button.text = _t("ui.library.unpublish")
	_publish_status.text = _t("ui.library.status.ready")
	_status_text.text = _t("ui.library.status.ready")
	_undo_button.text = "%s %s" % [IconFont.get_icon("undo"), _t("ui.common.undo")]
	_safe_restore_button.text = "%s %s" % [IconFont.get_icon("restore"), _t("ui.common.safe_restore")]
	_go_create_button.text = "%s %s" % [IconFont.get_icon("build"), _t("ui.library.go_create")]
	_go_play_button.text = "%s %s" % [IconFont.get_icon("play"), _t("ui.library.go_play")]
	_apply_role_state()


func _on_publish_pressed() -> void:
	if _publish_port == null or _profile == null:
		_set_status("failed")
		return
	var project_id := _project_id_input.text.strip_edges()
	var world_id := _world_id_input.text.strip_edges()
	var request := _publish_port.execute(project_id, world_id, _profile)
	if request == null:
		_set_status("failed")
		return
	_request_id_input.text = request.request_id
	_set_status("submitted")


func _on_approve_pressed() -> void:
	# Phase 9: server-side RBAC — role check at handler entry, not just button.disabled.
	if not _is_parent_profile():
		_show_toast(_t("library.rbac.ask_parent"))
		return
	# Phase 9: ports_ready gate — guard against pre-wiring invocations.
	if not _ports_ready:
		_show_toast(_t("library.error.ports_not_ready"))
		return
	if _review_publish_port == null or _profile == null:
		_show_toast(_t("library.error.port_unavailable"))
		_set_status("failed")
		return
	var request_id := _request_id_input.text.strip_edges()
	var request := _review_publish_port.execute(request_id, true, _profile, "")
	if request == null:
		_show_toast(_t("library.error.port_unavailable"))
		_set_status("failed")
		return
	_show_toast(_t("library.approve.toast_ok"))
	_set_status("approved")


func _on_reject_pressed() -> void:
	# Phase 9: server-side RBAC — role check at handler entry, not just button.disabled.
	if not _is_parent_profile():
		_show_toast(_t("library.rbac.ask_parent"))
		return
	# Phase 9: ports_ready gate.
	if not _ports_ready:
		_show_toast(_t("library.error.ports_not_ready"))
		return
	if _review_publish_port == null or _profile == null:
		_show_toast(_t("library.error.port_unavailable"))
		_set_status("failed")
		return
	var request_id := _request_id_input.text.strip_edges()
	var request := _review_publish_port.execute(
		request_id,
		false,
		_profile,
		_t("ui.library.reject_reason")
	)
	if request == null:
		_show_toast(_t("library.error.port_unavailable"))
		_set_status("failed")
		return
	_show_toast(_t("library.reject.toast_ok"))
	_set_status("rejected")


func _on_unpublish_pressed() -> void:
	# Phase 9: server-side RBAC — role check at handler entry, not just button.disabled.
	if not _is_parent_profile():
		_show_toast(_t("library.rbac.ask_parent"))
		return
	# Phase 9: ports_ready gate.
	if not _ports_ready:
		_show_toast(_t("library.error.ports_not_ready"))
		return
	if _unpublish_port == null or _profile == null:
		_show_toast(_t("library.error.port_unavailable"))
		_set_status("failed")
		return
	var request_id := _request_id_input.text.strip_edges()
	var request := _unpublish_port.execute(request_id, _profile, _t("ui.library.unpublish_reason"))
	if request == null:
		_show_toast(_t("library.error.port_unavailable"))
		_set_status("failed")
		return
	_show_toast(_t("library.unpublish.toast_ok"))
	_set_status("unpublished")


## Phase 9: returns true only when a real parent profile is active.
## Used by privileged handlers as server-side RBAC enforcement.
func _is_parent_profile() -> bool:
	return _profile != null and _profile.is_parent()


## Minimal toast: updates the publish_status label for one-shot feedback.
## Godot 4 UI adapters without a full toast node use this lightweight approach.
func _show_toast(message: String) -> void:
	if _publish_status != null:
		_publish_status.text = message


func _set_status(status_key: String) -> void:
	var text := _t("ui.library.status." + status_key)
	_publish_status.text = text
	_status_text.text = text
	_update_status_dot(status_key)


func _update_status_dot(status_key: String) -> void:
	if _status_dot == null:
		return
	var color := Color.GRAY
	match status_key:
		"approved", "published":
			color = Color8(120, 210, 140)
		"submitted", "pending":
			color = Color8(255, 200, 80)
		"failed", "rejected", "unpublished":
			color = Color8(255, 120, 120)
		_:
			color = Color8(180, 190, 200)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_status_dot.add_theme_stylebox_override("panel", style)


func _apply_role_state() -> void:
	var is_parent := _profile != null and _profile.is_parent()
	_approve_button.disabled = not is_parent
	_reject_button.disabled = not is_parent
	_unpublish_button.disabled = not is_parent


func _apply_theme() -> void:
	var theme := load("res://data/themes/choyce_theme.tres") as Theme
	if theme != null:
		self.theme = theme


func _t(key: String) -> String:
	if _localization_policy != null:
		return _localization_policy.translate(key)

	var fallback := {
		"ui.library.title": "Biblioteka rodzinna",
		"ui.library.info": "Przeglądaj opublikowane światy i uruchamiaj je.",
		"ui.library.project_id": "ID projektu",
		"ui.library.world_id": "ID świata",
		"ui.library.request_id": "ID wniosku publikacji",
		"ui.library.publish": "Wyślij do publikacji",
		"ui.library.approve": "Zatwierdź",
		"ui.library.reject": "Odrzuć",
		"ui.library.unpublish": "Wycofaj publikację",
		"ui.library.status.ready": "Gotowe do publikacji.",
		"ui.library.status.submitted": "Wniosek publikacji został zapisany.",
		"ui.library.status.approved": "Wniosek został zatwierdzony i opublikowany.",
		"ui.library.status.rejected": "Wniosek został odrzucony.",
		"ui.library.status.unpublished": "Publikacja została wycofana.",
		"ui.library.status.failed": "Operacja publikacji nie powiodła się.",
		"ui.library.reject_reason": "Odrzucono przez rodzica",
		"ui.library.unpublish_reason": "Wycofano przez rodzica",
		"ui.common.undo": "Cofnij",
		"ui.common.safe_restore": "Przywróć bezpieczny zapis",
		"ui.library.go_create": "Przejdź do tworzenia",
		"ui.library.go_play": "Przejdź do gry",
		# Phase 9 / Phase 4: RBAC + ports_ready feedback keys
		"library.access_denied": "Tylko rodzic.",
		# Wave C: kid RBAC follow-up (ask parent)
		"library.rbac.ask_parent": "Tylko rodzic. Poproś rodzica.",
		"library.approve.toast_ok": "Zatwierdzone.",
		"library.reject.toast_ok": "Odrzucone.",
		"library.unpublish.toast_ok": "Cofnięte.",
		"library.error.port_unavailable": "Coś nie działa. Spróbuj później.",
		"library.error.ports_not_ready": "Chwilę...",
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
