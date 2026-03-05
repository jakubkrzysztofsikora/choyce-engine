class_name LocalSTTAdapterTest
extends ApplicationTest

var _adapter: LocalSTTAdapter

func _init():
	_adapter = LocalSTTAdapter.new()

func _reset():
	_checks_run = 0
	_failures = []

func run():
	test_empty_audio()
	test_polish_language_default()
	test_child_speech_simulation()
	return _build_result("LocalSTTAdapter")

func test_empty_audio():
	_reset()
	var result := _adapter.transcribe(PackedByteArray())
	_assert_eq(result, "", "Empty audio should return empty string")

func test_polish_language_default():
	_reset()
	var test_audio := PackedByteArray([1, 2, 3, 4, 5])  # Small audio
	var result := _adapter.transcribe(test_audio)
	_assert_ne(result, "", "Should transcribe small audio")
	_assert_true(result.to_utf8_buffer().size() > 0, "Result should be UTF-8 encodable")

func test_child_speech_simulation():
	_reset()
	var longer_audio := PackedByteArray()
	longer_audio.resize(250)
	longer_audio.fill(1)  # Larger audio
	var result := _adapter.transcribe(longer_audio)
	_assert_ne(result, "", "Should transcribe longer audio")
	_assert_true(result.length() > 3, "Longer audio should produce longer transcript")
