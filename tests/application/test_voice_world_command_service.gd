## Application test: VoiceWorldCommandService
## Verifies kid voice "buduj drzewo" -> ADD_NODE, "usuń kwiat" ->
## REMOVE_NODE, fail-closed on unknown nouns, friendly feedback lines.
class_name TestVoiceWorldCommandService
extends ApplicationTest


var _svc: VoiceWorldCommandService
var _extractor: PolishIntentExtractor


func _init() -> void:
	_extractor = PolishIntentExtractor.new().setup()
	_svc = VoiceWorldCommandService.new().setup(_extractor, null)


func run() -> Dictionary:
	test_build_drzewo_makes_add_command()
	test_delete_kwiat_makes_remove_command()
	test_move_dom_makes_move_command()
	test_unknown_noun_returns_null()
	test_empty_transcript_returns_null()
	test_help_intent_returns_null_with_friendly_feedback()
	test_feedback_line_for_add()
	test_feedback_line_for_unknown_noun()
	test_create_command_carries_spawn_position()
	return _build_result("VoiceWorldCommandService")


func test_build_drzewo_makes_add_command() -> void:
	var cmd := _svc.interpret("zbuduj drzewo", Vector3(0, 1, 0))
	_assert_true(cmd != null, "Drzewo: returns a command")
	_assert_eq(cmd.action, WorldEditCommand.Action.ADD_NODE, "Action ADD_NODE")
	_assert_eq(String(cmd.node_data["display_name_pl"]), "Drzewo", "Display name 'Drzewo'")
	_assert_eq(String(cmd.node_data["source"]), "voice", "Source = voice (audit trail)")


func test_delete_kwiat_makes_remove_command() -> void:
	var cmd := _svc.interpret("usuń kwiat")
	_assert_true(cmd != null, "Kwiat: returns a command")
	_assert_eq(cmd.action, WorldEditCommand.Action.REMOVE_NODE, "Action REMOVE_NODE")
	_assert_true(cmd.is_destructive(), "REMOVE_NODE flagged destructive")


func test_move_dom_makes_move_command() -> void:
	var cmd := _svc.interpret("przesuń dom", Vector3(5, 0, 3))
	_assert_true(cmd != null, "Dom: returns a command")
	_assert_eq(cmd.action, WorldEditCommand.Action.MOVE_NODE, "Action MOVE_NODE")
	var pos: Array = cmd.new_state["position"]
	_assert_eq(int(pos[0]), 5, "Move target X carried")
	_assert_eq(int(pos[2]), 3, "Move target Z carried")


func test_unknown_noun_returns_null() -> void:
	# 'samochód' is not in the kid-safe whitelist
	var cmd := _svc.interpret("zbuduj samochód")
	_assert_true(cmd == null, "Unknown noun: fail-closed (null)")


func test_empty_transcript_returns_null() -> void:
	_assert_true(_svc.interpret("") == null, "Empty: null")
	_assert_true(_svc.interpret("   ") == null, "Whitespace: null")


func test_help_intent_returns_null_with_friendly_feedback() -> void:
	var cmd := _svc.interpret("pomocy")
	_assert_true(cmd == null, "HELP intent: no edit command")
	var line: String = _svc.feedback_line(cmd, "pomocy")
	_assert_true(line.contains("buduj") or line.contains("usuń"),
		"Help feedback suggests buduj/usuń")


func test_feedback_line_for_add() -> void:
	var cmd := _svc.interpret("zbuduj drzewo")
	var line: String = _svc.feedback_line(cmd, "zbuduj drzewo")
	_assert_true(line.contains("Drzewo"), "Add feedback mentions Drzewo")


func test_feedback_line_for_unknown_noun() -> void:
	var cmd := _svc.interpret("zbuduj samochód")
	var line: String = _svc.feedback_line(cmd, "zbuduj samochód")
	_assert_true(line.length() > 0, "Unknown-noun feedback is non-empty")
	_assert_true(line.contains("drzewo") or line.contains("kwiat") or line.contains("dom"),
		"Suggests known nouns")


func test_create_command_carries_spawn_position() -> void:
	var cmd := _svc.interpret("buduj klucz", Vector3(7, 0, -2))
	_assert_true(cmd != null, "Klucz: command produced")
	var pos: Array = cmd.node_data["position"]
	_assert_eq(int(pos[0]), 7, "Spawn X")
	_assert_eq(int(pos[2]), -2, "Spawn Z")
