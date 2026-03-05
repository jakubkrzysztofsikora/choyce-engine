class_name PolishIntentExtractorTest
extends ApplicationTest

var _extractor: PolishIntentExtractor

func _init():
	_extractor = PolishIntentExtractor.new()

func _reset():
	_checks_run = 0
	_failures = []

func run():
	_reset()
	test_empty_transcript()
	test_child_speech_normalization()
	test_intent_extraction()
	test_age_band_setup()
	return _build_result("PolishIntentExtractor")

func test_empty_transcript():
	var result := _extractor.extract_intent("")
	_assert_eq(result, "", "Empty transcript should return empty intent")

func test_child_speech_normalization():
	# Test the normalization method directly
	var test_text := "chcę sia zbudowaćsklep"
	var normalized := _extractor._normalize_polish_child_speech(test_text)
	_assert_eq(normalized, "chcę się zbudować sklep", "Should normalize child speech patterns")

func test_intent_extraction():
	var create_intent := _extractor.extract_intent("chcę zbudować dom")
	_assert_eq(create_intent, "CREATE_OBJECT", "Should extract create intent")
	
	var delete_intent := _extractor.extract_intent("chcę usunąć ten obiekt")
	_assert_eq(delete_intent, "DELETE_OBJECT", "Should extract delete intent")
	
	var help_intent := _extractor.extract_intent("potrzebuję pomocy")
	_assert_eq(help_intent, "REQUEST_HELP", "Should extract help intent")
	
	var game_intent := _extractor.extract_intent("chcę zagrać")
	_assert_eq(game_intent, "START_GAME", "Should extract game intent")
	
	var general_intent := _extractor.extract_intent("co to jest?")
	_assert_eq(general_intent, "GENERAL_QUERY", "Should extract general query intent")

func test_age_band_setup():
	var child_extractor := PolishIntentExtractor.new().setup(AgeBand.new(AgeBand.Band.CHILD_6_8))
	_assert_not_null(child_extractor, "Should create extractor with child age band")
	
	var teen_extractor := PolishIntentExtractor.new().setup(AgeBand.new(AgeBand.Band.TEEN))
	_assert_not_null(teen_extractor, "Should create extractor with teen age band")
