class_name ProvenanceBadge
extends PanelContainer

const IconFont = preload("res://src/adapters/inbound/shared/ui/icon_font.gd")
const COLOR_HUMAN = Color("29B6F6") # Bright Blue
const COLOR_AI = Color("AB47BC")    # Soft Purple
const COLOR_HYBRID = Color("FFA726") # Warm Orange

var _provenance: ProvenanceData
var _label: Label
var _icon_label: Label
var _hbox: HBoxContainer
var _localization_policy: LocalizationPolicyPort

func _init() -> void:
	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 8)
	add_child(_hbox)

	_icon_label = Label.new()
	_icon_label.add_theme_font_size_override("font_size", 18)
	_hbox.add_child(_icon_label)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_hbox.add_child(_label)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18, 0.85)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", style)

func set_provenance(data: ProvenanceData) -> void:
	_provenance = data
	_update_ui()


func setup(localization_policy: LocalizationPolicyPort) -> ProvenanceBadge:
	_localization_policy = localization_policy
	_update_ui()
	return self

func _update_ui() -> void:
	if _provenance == null:
		visible = false
		return

	visible = true
	var source_text = ""
	var color = Color.WHITE
	var icon = ""

	match _provenance.source:
		ProvenanceData.SourceType.HUMAN:
			source_text = _t("ui.provenance.human", "Człowiek")
			color = COLOR_HUMAN
			icon = IconFont.get_icon("human")
		ProvenanceData.SourceType.AI_TEXT:
			source_text = _t("ui.provenance.ai_text", "AI (Tekst)")
			color = COLOR_AI
			icon = IconFont.get_icon("ai")
		ProvenanceData.SourceType.AI_VISUAL:
			source_text = _t("ui.provenance.ai_visual", "AI (Obraz)")
			color = COLOR_AI
			icon = IconFont.get_icon("ai")
		ProvenanceData.SourceType.AI_AUDIO:
			source_text = _t("ui.provenance.ai_audio", "AI (Dźwięk)")
			color = COLOR_AI
			icon = IconFont.get_icon("ai")
		ProvenanceData.SourceType.HYBRID:
			source_text = _t("ui.provenance.hybrid", "Hybryda")
			color = COLOR_HYBRID
			icon = IconFont.get_icon("sparkle")

	_icon_label.text = icon
	_label.text = source_text
	_label.add_theme_color_override("font_color", color)
	_icon_label.add_theme_color_override("font_color", color)
	
	var tooltip = _fmt(_t("ui.tooltip.provenance.source", "Źródło: %s"), source_text)
	if not _provenance.generator_model.is_empty():
		tooltip += "\n" + _fmt(_t("ui.tooltip.provenance.model", "Model: %s"), _provenance.generator_model)
	if not _provenance.audit_id.is_empty():
		tooltip += "\n" + _fmt(_t("ui.tooltip.provenance.audit", "Audyt ID: %s"), _provenance.audit_id)
	
	tooltip_text = tooltip


func _t(key: String, fallback: String) -> String:
	if _localization_policy == null:
		return fallback
	var translated := _localization_policy.translate(key)
	if translated.strip_edges().is_empty() or translated == key:
		return fallback
	return translated


func _fmt(template: String, value: String) -> String:
	if template.find("%s") == -1:
		return "%s %s" % [template, value]
	return template % value
