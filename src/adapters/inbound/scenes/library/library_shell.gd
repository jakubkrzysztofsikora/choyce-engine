class_name LibraryShell
extends Control

const SHELL_CREATE := "create"
const SHELL_PLAY := "play"

var _navigator: ShellNavigator
var _profile: PlayerProfile
var _localization_policy: LocalizationPolicyPort
var _publish_port: PublishToFamilyLibraryPort
var _review_publish_port: ReviewPublishRequestPort
var _unpublish_port: UnpublishWorldPort
var _provenance_badge: ProvenanceBadge

@onready var _title: Label = $Layout/Header/Title
@onready var _info: Label = $Layout/Header/Info
@onready var _project_id_input: LineEdit = $Layout/PublishPanel/ProjectIdInput
@onready var _world_id_input: LineEdit = $Layout/PublishPanel/WorldIdInput
@onready var _request_id_input: LineEdit = $Layout/PublishPanel/RequestIdInput
@onready var _publish_button: Button = $Layout/PublishPanel/Actions/PublishButton
@onready var _approve_button: Button = $Layout/PublishPanel/Actions/ApproveButton
@onready var _reject_button: Button = $Layout/PublishPanel/Actions/RejectButton
@onready var _unpublish_button: Button = $Layout/PublishPanel/Actions/UnpublishButton
@onready var _publish_status: Label = $Layout/PublishPanel/Status
@onready var _undo_button: Button = $Layout/Actions/UndoButton
@onready var _safe_restore_button: Button = $Layout/Actions/SafeRestoreButton
@onready var _go_create_button: Button = $Layout/Actions/GoCreateButton
@onready var _go_play_button: Button = $Layout/Actions/GoPlayButton


func _ready() -> void:
	_setup_provenance_badge()
	_wire_actions()
	_refresh_labels()


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
	_undo_button.text = _t("ui.common.undo")
	_safe_restore_button.text = _t("ui.common.safe_restore")
	_go_create_button.text = _t("ui.library.go_create")
	_go_play_button.text = _t("ui.library.go_play")
	_apply_role_state()


func _on_publish_pressed() -> void:
	if _publish_port == null or _profile == null:
		_publish_status.text = _t("ui.library.status.failed")
		return
	var project_id := _project_id_input.text.strip_edges()
	var world_id := _world_id_input.text.strip_edges()
	var request := _publish_port.execute(project_id, world_id, _profile)
	if request == null:
		_publish_status.text = _t("ui.library.status.failed")
		return
	_request_id_input.text = request.request_id
	_publish_status.text = _t("ui.library.status.submitted")


func _on_approve_pressed() -> void:
	if _review_publish_port == null or _profile == null:
		_publish_status.text = _t("ui.library.status.failed")
		return
	var request_id := _request_id_input.text.strip_edges()
	var request := _review_publish_port.execute(request_id, true, _profile, "")
	if request == null:
		_publish_status.text = _t("ui.library.status.failed")
		return
	_publish_status.text = _t("ui.library.status.approved")


func _on_reject_pressed() -> void:
	if _review_publish_port == null or _profile == null:
		_publish_status.text = _t("ui.library.status.failed")
		return
	var request_id := _request_id_input.text.strip_edges()
	var request := _review_publish_port.execute(
		request_id,
		false,
		_profile,
		_t("ui.library.reject_reason")
	)
	if request == null:
		_publish_status.text = _t("ui.library.status.failed")
		return
	_publish_status.text = _t("ui.library.status.rejected")


func _on_unpublish_pressed() -> void:
	if _unpublish_port == null or _profile == null:
		_publish_status.text = _t("ui.library.status.failed")
		return
	var request_id := _request_id_input.text.strip_edges()
	var request := _unpublish_port.execute(request_id, _profile, _t("ui.library.unpublish_reason"))
	if request == null:
		_publish_status.text = _t("ui.library.status.failed")
		return
	_publish_status.text = _t("ui.library.status.unpublished")


func _apply_role_state() -> void:
	var is_parent := _profile != null and _profile.is_parent()
	_approve_button.disabled = not is_parent
	_reject_button.disabled = not is_parent
	_unpublish_button.disabled = not is_parent


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
		"ui.library.go_play": "Przejdź do gry"
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
