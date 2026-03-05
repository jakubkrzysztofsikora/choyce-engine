class_name ParentScriptEditorServiceContractTest
extends PortContractTest


class MockLLM:
	extends LLMPort

	func complete(envelope: PromptEnvelope) -> String:
		if envelope.prompt_text.to_lower().contains("refaktor"):
			return "Rozbij funkcje na mniejsze i nazwij zmienne precyzyjniej."
		return "unsafe wyjasnienie"

	func complete_with_tools(_envelope: PromptEnvelope) -> Array[ToolInvocation]:
		return []


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-02T16:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767427200000 + _tick


class MockModeration:
	extends ModerationPort

	func check_text(text: String, _age_band: AgeBand) -> ModerationResult:
		if text.to_lower().contains("unsafe"):
			var blocked := ModerationResult.new(ModerationResult.Verdict.BLOCK, "unsafe")
			blocked.safe_alternative = "Wyjasnienie zostalo bezpiecznie uproszczone."
			return blocked
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")

	func check_image(_image_data: PackedByteArray, _age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS, "")


func run() -> Dictionary:
	_reset()

	var repo := InMemoryScriptRepository.new()
	repo.save_script("project-1", "scripts/main.gd", "func run():\n\tprint('hej')")

	var service := ParentScriptEditorService.new().setup(
		repo,
		MockLLM.new(),
		MockClock.new(),
		EventSourcedActionLog.new(),
		MockModeration.new()
	)
	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)
	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)

	var kid_load := service.load_script("project-1", "scripts/main.gd", kid)
	_assert_true(not kid_load.get("ok", false), "Kid should not access parent script editor")

	var loaded := service.load_script("project-1", "scripts/main.gd", parent)
	_assert_true(loaded.get("ok", false), "Parent should load script")
	_assert_true(
		str(loaded.get("code", "")).contains("func run"),
		"Loaded script should include original source"
	)

	var explanation := service.explain_script("project-1", "scripts/main.gd", parent)
	_assert_true(explanation.get("ok", false), "Parent should request script explanation")
	_assert_true(
		str(explanation.get("explanation", "")) == "Wyjasnienie zostalo bezpiecznie uproszczone.",
		"Explanation output should be moderated before returning"
	)

	var refactor := service.suggest_refactor("project-1", "scripts/main.gd", parent)
	_assert_true(refactor.get("ok", false), "Parent should request refactor suggestion")
	_assert_true(
		str(refactor.get("suggestion", "")).to_lower().contains("rozbij"),
		"Refactor suggestion should return LLM guidance"
	)

	var preview := service.preview_mutation(
		"project-1",
		"scripts/main.gd",
		"func run():\n\tprint('hej rodzino')",
		parent
	)
	_assert_true(preview.get("ok", false), "Preview should succeed for parent")
	_assert_true(
		str(preview.get("diff", "")).contains("- \tprint('hej')"),
		"Preview should include removed line in diff"
	)
	_assert_true(
		str(preview.get("diff", "")).contains("+ \tprint('hej rodzino')"),
		"Preview should include added line in diff"
	)

	var missing_apply := service.apply_mutation("missing_mutation", parent)
	_assert_true(
		not missing_apply.get("ok", false),
		"Apply should fail without preview mutation id"
	)

	var applied := service.apply_mutation(str(preview.get("mutation_id", "")), parent)
	_assert_true(applied.get("ok", false), "Apply should succeed for previewed mutation")
	_assert_true(
		repo.load_script("project-1", "scripts/main.gd").contains("hej rodzino"),
		"Applied mutation should update repository source"
	)

	var rollback_token: Dictionary = applied.get("rollback_token", {})
	_assert_true(
		service.rollback_mutation(rollback_token, parent),
		"Rollback should restore previous script source"
	)
	_assert_true(
		repo.load_script("project-1", "scripts/main.gd").contains("print('hej')"),
		"Rollback should restore original code"
	)

	return _build_result("ParentScriptEditorService")
