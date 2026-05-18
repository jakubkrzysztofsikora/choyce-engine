## Contract test for IntentExtractorPort.
## Verifies the port default returns "" and PolishIntentExtractor satisfies the contract.
class_name IntentExtractorPortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	# 1. Port base default returns empty string
	var port := IntentExtractorPort.new()
	_assert_has_method(port, "extract_intent")
	var default_result := port.extract_intent("anything")
	_assert_true(
		default_result == "",
		"IntentExtractorPort.extract_intent() default must return empty string"
	)
	var empty_result := port.extract_intent("")
	_assert_true(
		empty_result == "",
		"IntentExtractorPort.extract_intent('') default must return empty string"
	)

	# 2. PolishIntentExtractor satisfies IntentExtractorPort contract
	var extractor: IntentExtractorPort = PolishIntentExtractor.new()
	_assert_true(
		extractor is IntentExtractorPort,
		"PolishIntentExtractor must extend IntentExtractorPort"
	)
	_assert_has_method(extractor, "extract_intent")

	# 3. PolishIntentExtractor returns String (not null, not other type)
	var intent := extractor.extract_intent("chcę zbudować sklep")
	_assert_string(intent, "PolishIntentExtractor.extract_intent(create_phrase)")

	var empty_intent := extractor.extract_intent("")
	_assert_true(
		empty_intent == "",
		"PolishIntentExtractor must return '' for empty transcript"
	)

	return _build_result("IntentExtractorPort")
