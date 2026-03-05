class_name ProvenanceBadgeLocalizationContractTest
extends PortContractTest


class MockLocalization:
	extends LocalizationPolicyPort

	var _translations := {
		"ui.provenance.human": "Czlowiek",
		"ui.provenance.ai_text": "AI (Tekst)",
		"ui.provenance.ai_visual": "AI (Wizualne)",
		"ui.provenance.ai_audio": "AI (Audio)",
		"ui.provenance.hybrid": "Hybrydowe",
		"ui.tooltip.provenance.source": "Zrodlo: %s",
		"ui.tooltip.provenance.model": "Model: %s",
		"ui.tooltip.provenance.audit": "Audit ID: %s",
	}

	func get_locale() -> String:
		return "pl-PL"

	func translate(key: String) -> String:
		return str(_translations.get(key, key))

	func is_term_safe(_term: String) -> bool:
		return true


func run() -> Dictionary:
	_reset()

	var badge := ProvenanceBadge.new()
	badge.setup(MockLocalization.new())

	var ai_text := ProvenanceData.new(
		ProvenanceData.SourceType.AI_TEXT,
		"qwen2.5:7b-instruct",
		"audit-localized-1"
	)
	badge.set_provenance(ai_text)

	_assert_true(badge.visible, "Badge should be visible when provenance is present")
	_assert_true(
		badge._label.text == "AI (Tekst)",
		"Badge should use localized source label from LocalizationPolicyPort"
	)
	_assert_true(
		badge.tooltip_text.find("Zrodlo: AI (Tekst)") != -1,
		"Badge tooltip should localize provenance source label"
	)
	_assert_true(
		badge.tooltip_text.find("Model: qwen2.5:7b-instruct") != -1,
		"Badge tooltip should include generator model"
	)
	_assert_true(
		badge.tooltip_text.find("Audit ID: audit-localized-1") != -1,
		"Badge tooltip should include audit linkage id"
	)

	badge.set_provenance(null)
	_assert_true(not badge.visible, "Badge should hide when provenance is cleared")
	badge.free()

	return _build_result("ProvenanceBadgeLocalization")
