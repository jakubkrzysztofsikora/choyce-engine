class_name ParentZoneShell
extends Control

const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")
const SHELL_CREATE := "create"
const SHELL_PLAY := "play"
const SHELL_LANDING := "landing"

var _navigator: ShellNavigator
var _profile: PlayerProfile
var _localization_policy: LocalizationPolicyPort
var _set_parental_controls_port: SetParentalControlsPort
var _parent_audit_read_model: ParentAuditReadModel
var _ai_performance_read_model: AIPerformanceReadModel
var _manage_data_lifecycle_port: ManageDataLifecyclePort
var _provenance_badge: ProvenanceBadge

# COPPA data tab controls (created at runtime in _setup_coppa_panel)
var _coppa_export_button: Button
var _coppa_delete_button: Button
var _coppa_status_label: Label
var _coppa_confirm_dialog: ConfirmationDialog

@onready var _title: Label = $Layout/Header/Title
@onready var _info: Label = $Layout/Header/Info
@onready var _dashboard_grid: GridContainer = $Layout/DashboardGrid
@onready var _audit_card: PanelContainer = $Layout/DashboardGrid/AuditCard
@onready var _audit_summary: Label = $Layout/DashboardGrid/AuditCard/AuditContent/AuditSummary
@onready var _ai_card: PanelContainer = $Layout/DashboardGrid/AICard
@onready var _ai_summary: Label = $Layout/DashboardGrid/AICard/AIContent/AISummary
@onready var _playtime_card: PanelContainer = $Layout/DashboardGrid/PlaytimeCard
@onready var _playtime_summary: Label = $Layout/DashboardGrid/PlaytimeCard/PlaytimeContent/PlaytimeSummary
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
	_setup_coppa_panel()
	_ensure_back_button()
	_make_layout_responsive()
	_wire_actions()


## Center content with max-width so ultra-wide monitors don't
## stretch panels edge-to-edge. Mirrors CreateShell helper.
func _make_layout_responsive() -> void:
	var layout: VBoxContainer = $Layout
	if layout == null:
		return
	const MAX_CONTENT_WIDTH := 1280.0
	layout.anchor_left = 0.5
	layout.anchor_right = 0.5
	layout.anchor_top = 0.0
	layout.anchor_bottom = 1.0
	layout.offset_left = -MAX_CONTENT_WIDTH * 0.5
	layout.offset_right = MAX_CONTENT_WIDTH * 0.5
	layout.offset_top = 16.0
	layout.offset_bottom = -16.0
	layout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Role guard intentionally NOT called here — _profile may be null at _ready().
	# It is called unconditionally from setup() after profile is bound.
	_refresh_labels()
	_apply_theme()


## Inject a "← Menu" back button at the top of the layout so the kid
## always has a way to return to landing — separate from the top
## NavBar (which may be hidden or unreachable in some flows).
## Always enabled regardless of role guard — escape hatch first.
func _ensure_back_button() -> void:
	var layout: VBoxContainer = $Layout
	if layout == null:
		return
	if layout.has_node("BackToLandingButton"):
		return
	var btn := Button.new()
	btn.name = "BackToLandingButton"
	btn.text = "← Menu"
	btn.custom_minimum_size = Vector2(160, 48)
	btn.add_theme_font_size_override("font_size", 22)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.pressed.connect(_on_back_pressed)
	layout.add_child(btn)
	layout.move_child(btn, 0)


func _on_back_pressed() -> void:
	if _navigator != null:
		_navigator.show_shell(SHELL_LANDING)


func setup(
	navigator: ShellNavigator,
	profile: PlayerProfile,
	localization_policy: LocalizationPolicyPort,
	set_parental_controls_port: SetParentalControlsPort,
	parent_audit_read_model: ParentAuditReadModel = null,
	ai_performance_read_model: AIPerformanceReadModel = null,
	manage_data_lifecycle_port: ManageDataLifecyclePort = null
) -> ParentZoneShell:
	_navigator = navigator
	_profile = profile
	_localization_policy = localization_policy
	_set_parental_controls_port = set_parental_controls_port
	_parent_audit_read_model = parent_audit_read_model
	_ai_performance_read_model = ai_performance_read_model
	_manage_data_lifecycle_port = manage_data_lifecycle_port
	if _provenance_badge != null and _provenance_badge.has_method("setup"):
		_provenance_badge.call("setup", _localization_policy)

	if is_node_ready():
		# Profile is now bound — safe to apply role guard unconditionally.
		_apply_role_guard()
		_refresh_labels()
		_refresh_dashboard_summaries()
		_refresh_coppa_labels()

	return self


func _apply_role_guard() -> void:
	# Guard: profile may be null before setup() is called (e.g. during _ready()).
	# No-op in that case — shell remains in its default state.
	if _profile == null:
		return

	var is_parent_user := _profile.is_parent()
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

	# COPPA buttons follow the same guard
	if _coppa_export_button != null:
		_coppa_export_button.disabled = not is_parent_user
	if _coppa_delete_button != null:
		_coppa_delete_button.disabled = not is_parent_user


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
	_apply_policy_button.text = "%s %s" % [IconFont.get_icon("check"), _t("ui.parent.controls.apply")]
	_undo_button.text = "%s %s" % [IconFont.get_icon("undo"), _t("ui.common.undo")]
	_safe_restore_button.text = "%s %s" % [IconFont.get_icon("restore"), _t("ui.common.safe_restore")]
	_go_create_button.text = "%s %s" % [IconFont.get_icon("build"), _t("ui.parent.go_create")]
	_go_play_button.text = "%s %s" % [IconFont.get_icon("play"), _t("ui.parent.go_play")]
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
	if _playtime_summary != null:
		_playtime_summary.text = _build_playtime_summary()


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


func _build_playtime_summary() -> String:
	return "%s 120 min\n%s 45 min" % [IconFont.get_icon("time"), IconFont.get_icon("chart")]


func _setup_coppa_panel() -> void:
	# Create "Dane mojego dziecka" panel programmatically so the .tscn node
	# matches the DaneTab section added there.  If the DaneTab node already
	# exists in the scene tree (from .tscn edit) we skip creation to avoid
	# duplicates.
	if has_node("Layout/DaneTab"):
		var tab := get_node("Layout/DaneTab") as Control
		_coppa_export_button = tab.find_child("ExportButton", true, false)
		_coppa_delete_button = tab.find_child("DeleteButton", true, false)
		_coppa_status_label  = tab.find_child("StatusLabel", true, false)
	else:
		# Build the panel in code (fallback when .tscn node not yet present).
		var panel := PanelContainer.new()
		panel.name = "DaneTab"
		var vbox := VBoxContainer.new()
		vbox.name = "DaneContent"

		var title := Label.new()
		title.name = "DaneTitle"
		title.text = _t("parent.coppa.tab")

		_coppa_export_button = Button.new()
		_coppa_export_button.name = "ExportButton"
		_coppa_export_button.custom_minimum_size = Vector2(220, 48)
		_coppa_export_button.text = _t("parent.coppa.export")

		_coppa_delete_button = Button.new()
		_coppa_delete_button.name = "DeleteButton"
		_coppa_delete_button.custom_minimum_size = Vector2(220, 48)
		_coppa_delete_button.text = _t("parent.coppa.delete")

		_coppa_status_label = Label.new()
		_coppa_status_label.name = "StatusLabel"
		_coppa_status_label.text = ""
		_coppa_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		vbox.add_child(title)
		vbox.add_child(_coppa_export_button)
		vbox.add_child(_coppa_delete_button)
		vbox.add_child(_coppa_status_label)
		panel.add_child(vbox)
		$Layout.add_child(panel)

	# Wire confirmation dialog
	_coppa_confirm_dialog = ConfirmationDialog.new()
	_coppa_confirm_dialog.title = _t("parent.coppa.delete_confirm.title")
	_coppa_confirm_dialog.dialog_text = _t("parent.coppa.delete_confirm.body")
	add_child(_coppa_confirm_dialog)

	if _coppa_export_button != null:
		_coppa_export_button.pressed.connect(_on_coppa_export_pressed)
	if _coppa_delete_button != null:
		_coppa_delete_button.pressed.connect(_on_coppa_delete_pressed)
	_coppa_confirm_dialog.confirmed.connect(_on_coppa_delete_confirmed)


func _refresh_coppa_labels() -> void:
	if _coppa_export_button != null:
		_coppa_export_button.text = _t("parent.coppa.export")
	if _coppa_delete_button != null:
		_coppa_delete_button.text = _t("parent.coppa.delete")
	if _coppa_confirm_dialog != null:
		_coppa_confirm_dialog.title = _t("parent.coppa.delete_confirm.title")
		_coppa_confirm_dialog.dialog_text = _t("parent.coppa.delete_confirm.body")


func _on_coppa_export_pressed() -> void:
	if _manage_data_lifecycle_port == null or _profile == null:
		_set_coppa_status(_t("ui.parent.controls.save_failed"))
		return
	var subject_id := _get_subject_profile_id()
	var result := _manage_data_lifecycle_port.request_export(_profile, subject_id)
	if result.get("ok", false):
		_set_coppa_status(_t("parent.coppa.export_ok"))
	else:
		_set_coppa_status(_t("ui.parent.controls.save_failed"))


func _on_coppa_delete_pressed() -> void:
	if _coppa_confirm_dialog != null:
		_coppa_confirm_dialog.popup_centered()


func _on_coppa_delete_confirmed() -> void:
	if _manage_data_lifecycle_port == null or _profile == null:
		_set_coppa_status(_t("ui.parent.controls.save_failed"))
		return
	var subject_id := _get_subject_profile_id()
	var result := _manage_data_lifecycle_port.request_delete(_profile, subject_id)
	if result.get("ok", false):
		_set_coppa_status(_t("parent.coppa.delete_ok"))
	else:
		_set_coppa_status(_t("ui.parent.controls.save_failed"))


func _get_subject_profile_id() -> String:
	# Derive managed kid profile ID from parent's preferences (first managed, or default).
	if _profile == null:
		return ""
	var managed_variant = _profile.preferences.get("managed_profiles", [])
	if managed_variant is Array and not (managed_variant as Array).is_empty():
		return str((managed_variant as Array)[0])
	# Fallback: use conventional kid ID derived from family
	var family_id := str(_profile.preferences.get("family_id", "family_local"))
	return "%s_kid_1" % family_id


func _set_coppa_status(text: String) -> void:
	if _coppa_status_label != null:
		_coppa_status_label.text = text


## VoxelForge palette (matches landing + create chips).
const VOXEL_LIME := Color(0.639, 0.902, 0.208, 1)
const VOXEL_LIME_GLOW := Color(0.518, 0.800, 0.086, 1)
const VOXEL_BLACK := Color(0.0, 0.0, 0.0, 1)
const VOXEL_CARD_BG := Color(0.08, 0.08, 0.08, 1)   # near-black card surface


## Builds a card panel style: black surface, lime border, soft lime glow.
func _voxel_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = VOXEL_CARD_BG
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = VOXEL_LIME
	style.shadow_color = Color(VOXEL_LIME.r, VOXEL_LIME.g, VOXEL_LIME.b, 0.12)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 0)
	style.content_margin_left = 18
	style.content_margin_top = 16
	style.content_margin_right = 18
	style.content_margin_bottom = 16
	return style


func _apply_theme() -> void:
	var theme := load("res://data/themes/choyce_theme.tres") as Theme
	if theme != null:
		self.theme = theme

	for card in [_audit_card, _ai_card, _playtime_card]:
		if card != null:
			card.add_theme_stylebox_override("panel", _voxel_card_style())

	$Layout/ControlsPanel.add_theme_stylebox_override("panel", _voxel_card_style())


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
		"parent.coppa.tab": "Dane mojego dziecka",
		"parent.coppa.export": "Eksportuj dane",
		"parent.coppa.delete": "Usuń dane",
		"parent.coppa.delete_confirm.title": "Usunąć dane?",
		"parent.coppa.delete_confirm.body": "To zniknie i nie wróci.",
		"parent.coppa.export_ok": "Zapisałem dane.",
		"parent.coppa.delete_ok": "Usunąłem dane.",
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
