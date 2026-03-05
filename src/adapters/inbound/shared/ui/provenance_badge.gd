class_name ProvenanceBadge
extends PanelContainer

const COLOR_HUMAN = Color("4FC3F7") # Light Blue
const COLOR_AI = Color("E040FB")    # Purple
const COLOR_HYBRID = Color("FFB74D") # Orange

var _provenance: ProvenanceData
var _label: Label
var _icon: TextureRect # Placeholder for future icon
var _hbox: HBoxContainer
var _localization_policy: LocalizationPolicyPort

func _init() -> void:
	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 4)
	add_child(_hbox)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.visible = false # Hidden until we have actual icons
	_hbox.add_child(_icon)

	_label = Label.new()
	_hbox.add_child(_label)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
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

	match _provenance.source:
		ProvenanceData.SourceType.HUMAN:
			source_text = _t("ui.provenance.human", "Human")
			color = COLOR_HUMAN
		ProvenanceData.SourceType.AI_TEXT:
			source_text = _t("ui.provenance.ai_text", "AI (Text)")
			color = COLOR_AI
		ProvenanceData.SourceType.AI_VISUAL:
			source_text = _t("ui.provenance.ai_visual", "AI (Visual)")
			color = COLOR_AI
		ProvenanceData.SourceType.AI_AUDIO:
			source_text = _t("ui.provenance.ai_audio", "AI (Audio)")
			color = COLOR_AI
		ProvenanceData.SourceType.HYBRID:
			source_text = _t("ui.provenance.hybrid", "Hybrid")
			color = COLOR_HYBRID

	_label.text = source_text
	_label.modulate = color
	
	# Future: Load icon based on _provenance.get_badge_icon_name()

	var tooltip = _fmt(_t("ui.tooltip.provenance.source", "Source: %s"), source_text)
	if not _provenance.generator_model.is_empty():
		tooltip += "\n" + _fmt(_t("ui.tooltip.provenance.model", "Model: %s"), _provenance.generator_model)
	if not _provenance.audit_id.is_empty():
		tooltip += "\n" + _fmt(_t("ui.tooltip.provenance.audit", "Audit ID: %s"), _provenance.audit_id)
	
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
