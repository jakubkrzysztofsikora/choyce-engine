class_name ParentZoneShell
extends Control

const SHELL_CREATE := "create"
const SHELL_PLAY := "play"

var _navigator: ShellNavigator
var _profile: PlayerProfile
var _localization_policy: LocalizationPolicyPort
var _set_parental_controls_port: SetParentalControlsPort
var _parent_audit_read_model: ParentAuditReadModel
var _ai_performance_read_model: AIPerformanceReadModel
var _provenance_badge: ProvenanceBadge

@onready var _title: Label = $Layout/Header/Title
@onready var _info: Label = $Layout/Header/Info
@onready var _audit_summary: Label = $Layout/Header/AuditSummary
@onready var _ai_summary: Label = $Layout/Header/AISummary
@onready var _controls_title: Label = $Layout/ControlsPanel/Controls/ControlsTitle
@onready var _daily_limit_label: Label = $Layout/ControlsPanel/Controls/SettingsGrid/DailyLimitLabel
@onready var _daily_limit_spin: SpinBox = $Layout/ControlsPanel/Controls/SettingsGrid/DailyLimitSpin
@onready var _session_limit_label: Label = $Layout/ControlsPanel/Controls/SettingsGrid/SessionLimitLabel
@onready var _session_limit_spin: SpinBox = $Layout/ControlsPanel/Controls/SettingsGrid/SessionLimitSpin
@onready var _ai_access_label: Label = $Layout/ControlsPanel/Controls/SettingsGrid/AIAccessLabel
@onready var _ai_access_option: OptionButton = $Layout/ControlsPanel/Controls/SettingsGrid/AIAccessOption
@onready var _sharing_toggle: CheckBox = $Layout/ControlsPanel/Controls/SettingsGrid/SharingToggle
@onready var _language_override_toggle: CheckBox = $Layout/ControlsPanel/Controls/SettingsGrid/LanguageOverrideToggle
@onready var _cloud_sync_toggle: CheckBox = $Layout/ControlsPanel/Controls/SettingsGrid/CloudSyncToggle
@onready var _apply_policy_button: Button = $Layout/ControlsPanel/Controls/ApplyPolicyButton
@onready var _policy_status: Label = $Layout/ControlsPanel/Controls/PolicyStatus
@onready var _undo_button: Button = $Layout/Actions/UndoButton
@onready var _safe_restore_button: Button = $Layout/Actions/SafeRestoreButton
@onready var _go_create_button: Button = $Layout/Actions/GoCreateButton
@onready var _go_play_button: Button = $Layout/Actions/GoPlayButton

const AI_DISABLED := 0
const AI_CREATIVE_ONLY := 1
const AI_FULL := 2


func _ready() -> void:
	_setup_provenance_badge()
	_wire_actions()
	_apply_role_guard()
	_refresh_labels()


func setup(
	navigator: ShellNavigator,
	profile: PlayerProfile,
	localization_policy: LocalizationPolicyPort,
	set_parental_controls_port: SetParentalControlsPort,
	parent_audit_read_model: ParentAuditReadModel = null,
	ai_performance_read_model: AIPerformanceReadModel = null
) -> ParentZoneShell:
	_navigator = navigator
	_profile = profile
	_localization_policy = localization_policy
	_set_parental_controls_port = set_parental_controls_port
	_parent_audit_read_model = parent_audit_read_model
	_ai_performance_read_model = ai_performance_read_model
	if _provenance_badge != null and _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)

	if is_node_ready():
		_apply_role_guard()
		_refresh_labels()
		_refresh_dashboard_summaries()

	return self


func _apply_role_guard() -> void:
	var is_parent_user := _profile != null and _profile.is_parent()
	visible = is_parent_user

	_go_create_button.disabled = not is_parent_user
	_go_play_button.disabled = not is_parent_user
	_undo_button.disabled = not is_parent_user
	_safe_restore_button.disabled = not is_parent_user
	_daily_limit_spin.editable = is_parent_user
	_session_limit_spin.editable = is_parent_user
	_ai_access_option.disabled = not is_parent_user
	_sharing_toggle.disabled = not is_parent_user
	_language_override_toggle.disabled = not is_parent_user
	_cloud_sync_toggle.disabled = not is_parent_user
	_apply_policy_button.disabled = not is_parent_user


func _wire_actions() -> void:
	_go_create_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_CREATE)
	)
	_go_play_button.pressed.connect(func() -> void:
		if _navigator != null:
			_navigator.show_shell(SHELL_PLAY)
	)
	_apply_policy_button.pressed.connect(_on_apply_policy_pressed)


func set_context_provenance(provenance: Variant) -> void:
	if _provenance_badge == null:
		return
	if provenance == null or not (provenance is ProvenanceData):
		_provenance_badge.visible = false
		return
	_provenance_badge.set_provenance(provenance)


func _refresh_labels() -> void:
	_title.text = _t("ui.parent.title")
	_info.text = _t("ui.parent.info")
	_controls_title.text = _t("ui.parent.controls.title")
	_daily_limit_label.text = _t("ui.parent.controls.daily_limit")
	_session_limit_label.text = _t("ui.parent.controls.session_limit")
	_ai_access_label.text = _t("ui.parent.controls.ai_access")
	_sharing_toggle.text = _t("ui.parent.controls.sharing")
	_language_override_toggle.text = _t("ui.parent.controls.language_override")
	_cloud_sync_toggle.text = _t("ui.parent.controls.cloud_sync")
	_apply_policy_button.text = _t("ui.parent.controls.apply")
	_undo_button.text = _t("ui.common.undo")
	_safe_restore_button.text = _t("ui.common.safe_restore")
	_go_create_button.text = _t("ui.parent.go_create")
	_go_play_button.text = _t("ui.parent.go_play")
	_setup_ai_access_options()
	_refresh_dashboard_summaries()


func _setup_ai_access_options() -> void:
	_ai_access_option.clear()
	_ai_access_option.add_item(_t("ui.parent.controls.ai_disabled"), AI_DISABLED)
	_ai_access_option.add_item(_t("ui.parent.controls.ai_creative"), AI_CREATIVE_ONLY)
	_ai_access_option.add_item(_t("ui.parent.controls.ai_full"), AI_FULL)
	_ai_access_option.select(AI_CREATIVE_ONLY)


func _on_apply_policy_pressed() -> void:
	if _set_parental_controls_port == null or _profile == null:
		_policy_status.text = _t("ui.parent.controls.save_failed")
		return

	var settings := {
		"playtime_limit": {
			"daily": int(_daily_limit_spin.value),
			"session": int(_session_limit_spin.value),
		},
		"ai_access": _selected_ai_access_value(),
		"sharing_permissions": _sharing_toggle.button_pressed,
		"language_override": _language_override_toggle.button_pressed,
		"cloud_sync_consent": _cloud_sync_toggle.button_pressed,
	}
	var saved := _set_parental_controls_port.execute(_profile, settings)
	_policy_status.text = _t("ui.parent.controls.saved") if saved else _t("ui.parent.controls.save_failed")


func _selected_ai_access_value() -> String:
	match _ai_access_option.get_selected_id():
		AI_DISABLED:
			return "disabled"
		AI_FULL:
			return "full"
		_:
			return "creative_only"


func _refresh_dashboard_summaries() -> void:
	if _audit_summary != null:
		_audit_summary.text = _build_audit_summary()
	if _ai_summary != null:
		_ai_summary.text = _build_ai_summary()


func _build_audit_summary() -> String:
	if _parent_audit_read_model == null or _profile == null:
		return _t("ui.parent.audit.no_data")

	var timeline := _parent_audit_read_model.get_timeline(_profile.profile_id, "", "", 10)
	var interventions := _parent_audit_read_model.get_interventions(_profile.profile_id, 5)
	return _t("ui.parent.audit.template") % [timeline.size(), interventions.size()]


func _build_ai_summary() -> String:
	if _ai_performance_read_model == null:
		return _t("ui.parent.ai.no_data")

	var metrics := _ai_performance_read_model.get_metrics("7d")
	if metrics.is_empty():
		return _t("ui.parent.ai.no_data")
	return _t("ui.parent.ai.template") % [
		int(metrics.get("total_requests", 0)),
		int(round(float(metrics.get("success_rate", 0.0)))),
		int(metrics.get("blocked_by_moderation", 0)),
	]


func _t(key: String) -> String:
	if _localization_policy != null:
		return _localization_policy.translate(key)

	var fallback := {
		"ui.parent.title": "Strefa rodzica",
		"ui.parent.info": "Zarządzaj bezpieczeństwem, limitami i publikacją.",
		"ui.parent.controls.title": "Kontrola rodzicielska",
		"ui.parent.controls.daily_limit": "Limit dzienny (min)",
		"ui.parent.controls.session_limit": "Limit sesji (min)",
		"ui.parent.controls.ai_access": "Dostęp AI",
		"ui.parent.controls.sharing": "Pozwól na udostępnianie",
		"ui.parent.controls.language_override": "Zezwól na zmianę języka",
		"ui.parent.controls.cloud_sync": "Zezwól na synchronizację chmury",
		"ui.parent.controls.apply": "Zapisz ustawienia",
		"ui.parent.controls.saved": "Ustawienia zapisane.",
		"ui.parent.controls.save_failed": "Nie udało się zapisać ustawień.",
		"ui.parent.controls.ai_disabled": "AI wyłączone",
		"ui.parent.controls.ai_creative": "AI kreatywne",
		"ui.parent.controls.ai_full": "AI pełny dostęp",
		"ui.common.undo": "Cofnij",
		"ui.common.safe_restore": "Przywróć bezpieczny zapis",
		"ui.parent.go_create": "Przejdź do tworzenia",
		"ui.parent.go_play": "Przejdź do gry",
		"ui.parent.audit.no_data": "Audyt: brak danych.",
		"ui.parent.audit.template": "Audyt 24h: %d zdarzeń, %d interwencji",
		"ui.parent.ai.no_data": "AI: brak danych.",
		"ui.parent.ai.template": "AI 7d: %d żądań, %d%% skuteczności, %d blokad",
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
