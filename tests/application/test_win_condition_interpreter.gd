## Coverage for WinConditionInterpreter (MVP-I §7).
## Asserts the recursive-descent parser refuses anything outside the
## documented grammar (fail-closed) and evaluates well-formed
## expressions deterministically.
extends ApplicationTest

const WinConditionInterpreter = preload("res://src/application/win_condition_interpreter.gd")


func run() -> Dictionary:
	test_parses_simple_comparison()
	test_evaluates_simple_comparison()
	test_inventory_dotted_identifier()
	test_quest_string_equality()
	test_and_or_precedence()
	test_not_negates()
	test_parentheses_override_precedence()
	test_rejects_unknown_identifier()
	test_rejects_bare_inventory_without_subname()
	test_rejects_eval_injection_attempt()
	test_rejects_function_call_syntax()
	test_rejects_unterminated_string()
	test_rejects_trailing_tokens()
	test_evaluate_without_parse_returns_false()
	test_evaluate_with_missing_context_key()
	test_type_mismatch_fails_closed()
	test_bare_identifier_truthy()
	return _build_result("WinConditionInterpreter")


func test_parses_simple_comparison() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_true(interp.parse("score>=100"), "score>=100 parses")


func test_evaluates_simple_comparison() -> void:
	var interp := WinConditionInterpreter.new()
	interp.parse("score>=100")
	_assert_true(interp.evaluate({"score": 100}), "score=100 satisfies >=100")
	_assert_true(interp.evaluate({"score": 200}), "score=200 satisfies >=100")
	_assert_false(interp.evaluate({"score": 99}), "score=99 fails >=100")


func test_inventory_dotted_identifier() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_true(interp.parse("inventory.carrot>=5"), "dotted ident parses")
	_assert_true(interp.evaluate({"inventory": {"carrot": 5}}), "exactly 5 wins")
	_assert_false(interp.evaluate({"inventory": {"carrot": 4}}), "4 < 5")


func test_quest_string_equality() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_true(interp.parse("quest.harvest=='complete'"), "string literal parses")
	_assert_true(
		interp.evaluate({"quest": {"harvest": "complete"}}),
		"quest.harvest == 'complete'"
	)
	_assert_false(
		interp.evaluate({"quest": {"harvest": "in_progress"}}),
		"in_progress != complete"
	)


func test_and_or_precedence() -> void:
	# `and` binds tighter than `or` — `A or B and C` == `A or (B and C)`
	var interp := WinConditionInterpreter.new()
	_assert_true(
		interp.parse("score>=10 or blocks_placed>=10 and time<=60"),
		"compound expression parses"
	)
	# A=true,B=false,C=true → true
	_assert_true(
		interp.evaluate({"score": 10, "blocks_placed": 0, "time": 0}),
		"score>=10 wins regardless of right branch"
	)
	# A=false,B=true,C=true → true
	_assert_true(
		interp.evaluate({"score": 0, "blocks_placed": 10, "time": 30}),
		"right and-branch wins when score below threshold"
	)
	# A=false,B=true,C=false → false (and-branch fails on time)
	_assert_false(
		interp.evaluate({"score": 0, "blocks_placed": 10, "time": 120}),
		"and-branch fails when time>60"
	)


func test_not_negates() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_true(interp.parse("not in_zone.danger"), "not parses")
	_assert_true(
		interp.evaluate({"in_zone": {"danger": false}}),
		"not(false) is true"
	)
	_assert_false(
		interp.evaluate({"in_zone": {"danger": true}}),
		"not(true) is false"
	)


func test_parentheses_override_precedence() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_true(
		interp.parse("(score>=10 or blocks_placed>=10) and time<=60"),
		"parens parse"
	)
	# (false or true) and false → false
	_assert_false(
		interp.evaluate({"score": 0, "blocks_placed": 10, "time": 120}),
		"parens force outer and to fail"
	)


func test_rejects_unknown_identifier() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_false(interp.parse("rm>=1"), "rm is not allowlisted")
	_assert_ne(interp.last_error, "", "error populated")


func test_rejects_bare_inventory_without_subname() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_false(interp.parse("inventory>=1"), "bare inventory rejected")


func test_rejects_eval_injection_attempt() -> void:
	# Classic Expression.parse() injection — must NOT execute.
	var interp := WinConditionInterpreter.new()
	_assert_false(
		interp.parse("score>=1; OS.execute('rm', ['-rf', '/'])"),
		"injection rejected"
	)


func test_rejects_function_call_syntax() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_false(interp.parse("score(100)"), "function-call form rejected")


func test_rejects_unterminated_string() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_false(interp.parse("quest.harvest=='oops"), "unterminated string rejected")


func test_rejects_trailing_tokens() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_false(
		interp.parse("score>=10 something_else"),
		"trailing junk rejected"
	)


func test_evaluate_without_parse_returns_false() -> void:
	var interp := WinConditionInterpreter.new()
	_assert_false(
		interp.evaluate({"score": 1000}),
		"evaluate before parse returns false"
	)


func test_evaluate_with_missing_context_key() -> void:
	var interp := WinConditionInterpreter.new()
	interp.parse("inventory.carrot>=5")
	_assert_false(
		interp.evaluate({}),  # no inventory at all
		"missing context fails closed"
	)


func test_type_mismatch_fails_closed() -> void:
	var interp := WinConditionInterpreter.new()
	interp.parse("score>=10")
	_assert_false(
		interp.evaluate({"score": "ten"}),  # string vs int
		"type mismatch fails closed"
	)


func test_bare_identifier_truthy() -> void:
	# Bare boolean-style: `in_zone.win` evaluates to truthiness of the value.
	var interp := WinConditionInterpreter.new()
	_assert_true(interp.parse("in_zone.win"), "bare dotted ident parses")
	_assert_true(
		interp.evaluate({"in_zone": {"win": true}}),
		"true value passes"
	)
	_assert_false(
		interp.evaluate({"in_zone": {"win": false}}),
		"false value fails"
	)
