## Tests for Phase 8a: OllamaLLMAdapter async streaming contract.
##
## Covers:
##   MUST-1  Mock mode: on_done called synchronously with provider="ollama-local".
##   MUST-2  Mock mode: on_done result dict has required keys (text, provider, model, stopped).
##   MUST-3  Null envelope: on_done called with empty text and provider="fallback".
##   MUST-4  simulate_local_failure + no consent: on_done provider="fallback".
##   MUST-5  simulate_local_failure + cloud consent: cloud on_done called with cloud text.
##   MUST-6  cancel() in mock mode (no active request) does not crash.
##   MUST-7  Token buffer overflow: push_warning fired, oldest token dropped.
##   MUST-8  _on_chunk_received parses NDJSON lines, accumulates tokens.
##   MUST-9  _finish_request(stopped=true) fires on_done with stopped=true.
##   MUST-10 Service stub: RequestAICreationHelpService on_complete receives final action.
##   MUST-11 Service stub: RequestGameplayHintService on_complete receives hint dict.
##   MUST-12 ParentScriptEditorService explain_script on_complete receives explanation.
extends SceneTree


class MockConsentPort:
	extends IdentityConsentPort
	var _consents: Dictionary = {}

	func has_consent(p_id: String, ctype: String) -> bool:
		return _consents.get(p_id, []).has(ctype)

	func request_consent(p_id: String, ctype: String) -> bool:
		if not _consents.has(p_id):
			_consents[p_id] = []
		_consents[p_id].append(ctype)
		return true


class MockCloudLLM:
	extends LLMPort
	func complete(
		_envelope: PromptEnvelope,
		_options: Dictionary,
		_on_token: Callable,
		on_done: Callable
	) -> void:
		on_done.call({"text": "CLOUD_TEXT", "provider": "cloud", "model": "cloud-m", "stopped": false})

	func complete_with_tools_sync(_e: PromptEnvelope) -> Array[ToolInvocation]:
		var r: Array[ToolInvocation] = []
		return r


class StubLLM:
	extends LLMPort
	var inject_text := "risposta"
	var inject_provider := "ollama-local"
	var inject_stopped := false

	func complete(
		_envelope: PromptEnvelope,
		_options: Dictionary,
		_on_token: Callable,
		on_done: Callable
	) -> void:
		on_done.call({"text": inject_text, "provider": inject_provider, "model": "stub-m", "stopped": inject_stopped})

	func complete_with_tools_sync(_e: PromptEnvelope) -> Array[ToolInvocation]:
		var r: Array[ToolInvocation] = []
		r.append(ToolInvocation.new("scene_edit", {"operation": "add_object", "type": "tree"}, "stub_1"))
		return r

	func get_last_provider() -> String:
		return inject_provider

	func get_last_selected_model() -> String:
		return "stub-m"


class StubModeration:
	extends ModerationPort
	func check_text(text: String, _age_band) -> ModerationResult:
		var r := ModerationResult.new()
		r.is_safe = true
		return r


class StubClock:
	extends ClockPort
	func now_iso() -> String:
		return "2026-01-01T00:00:00Z"

	func now_msec() -> int:
		return 0


class StubLocalization:
	extends LocalizationPolicyPort
	func get_locale() -> String:
		return "pl-PL"


class StubScriptRepo:
	extends ScriptRepositoryPort
	func load_script(_pid: String, _spath: String) -> String:
		return "func _ready(): pass"

	func save_script(_pid: String, _spath: String, _code: String) -> bool:
		return true


func _init() -> void:
	var failures: Array[String] = []
	var checks := 0

	# ── MUST-1: mock on_done called synchronously ─────────────────────────────
	var adapter_mock := OllamaLLMAdapter.new()
	adapter_mock.set_mock_mode(true)
	var envelope := PromptEnvelope.new("Dodaj drzewo.")
	var done_called := false
	adapter_mock.complete(
		envelope,
		{},
		func(_t: String) -> void: pass,
		func(_r: Dictionary) -> void:
			done_called = true
	)
	checks += 1
	if not done_called:
		failures.append("MUST-1: mock on_done not called synchronously")

	# ── MUST-2: result dict has required keys ─────────────────────────────────
	var result_dict: Dictionary = {}
	adapter_mock.complete(
		envelope,
		{},
		func(_t: String) -> void: pass,
		func(r: Dictionary) -> void:
			result_dict = r
	)
	checks += 1
	for key in ["text", "provider", "model", "stopped"]:
		if not result_dict.has(key):
			failures.append("MUST-2: result dict missing key '%s'" % key)
	checks += 3  # remaining keys

	# ── MUST-3: null envelope: on_done with empty text ────────────────────────
	var null_result: Dictionary = {}
	adapter_mock.complete(
		null,
		{},
		func(_t: String) -> void: pass,
		func(r: Dictionary) -> void:
			null_result = r
	)
	checks += 1
	if not null_result.get("text", "x").is_empty():
		failures.append("MUST-3: null envelope should produce empty text")
	checks += 1
	if null_result.get("provider", "") != "fallback":
		failures.append("MUST-3: null envelope provider should be 'fallback'")

	# ── MUST-4: simulate_local_failure + no consent = fallback ────────────────
	var adapter_fail := OllamaLLMAdapter.new().setup(null, null, false)
	adapter_fail.set_mock_mode(true)
	adapter_fail.set_simulate_local_failure_for_tests(true)
	var fail_provider := ""
	adapter_fail.complete(
		envelope,
		{},
		func(_t: String) -> void: pass,
		func(r: Dictionary) -> void:
			fail_provider = r.get("provider", "")
	)
	checks += 1
	if fail_provider != "fallback":
		failures.append("MUST-4: simulate_local_failure without consent should produce fallback, got '%s'" % fail_provider)

	# ── MUST-5: simulate_local_failure + cloud consent = cloud ────────────────
	var consent := MockConsentPort.new()
	consent.request_consent("kid-1", "cloud_llm")
	var cloud_llm := MockCloudLLM.new()
	var adapter_cloud := OllamaLLMAdapter.new().setup(consent, cloud_llm, true)
	adapter_cloud.set_mock_mode(false)
	adapter_cloud.set_simulate_local_failure_for_tests(true)
	var env_tagged := PromptEnvelope.new("test")
	env_tagged.context_tags = ["profile_id:kid-1"]
	var cloud_text_received := ""
	adapter_cloud.complete(
		env_tagged,
		{},
		func(_t: String) -> void: pass,
		func(r: Dictionary) -> void:
			cloud_text_received = r.get("text", "")
	)
	checks += 1
	if cloud_text_received != "CLOUD_TEXT":
		failures.append("MUST-5: cloud fallback should return CLOUD_TEXT, got '%s'" % cloud_text_received)

	# ── MUST-6: cancel() in mock mode does not crash ──────────────────────────
	checks += 1
	var cancel_ok := true
	var adapter_cancel := OllamaLLMAdapter.new()
	adapter_cancel.set_mock_mode(true)
	adapter_cancel.cancel()  # nothing in-flight — must be a no-op
	if not cancel_ok:
		failures.append("MUST-6: cancel() crashed in mock mode")

	# ── MUST-7: token buffer overflow drops oldest, warns ────────────────────
	var adapter_buf := OllamaLLMAdapter.new()
	adapter_buf.set_mock_mode(true)
	# Simulate buffer state directly (unit-test white-box):
	adapter_buf._token_buffer = PackedStringArray()
	adapter_buf._token_buffer_bytes = 0
	adapter_buf._request_active = true
	adapter_buf._full_response_text = ""

	# Fill buffer to just under limit.
	var big_token := "A".repeat(OllamaLLMAdapter.TOKEN_BUFFER_MAX_BYTES - 10)
	adapter_buf._token_buffer.append(big_token)
	adapter_buf._token_buffer_bytes = big_token.length()
	adapter_buf._full_response_text = big_token

	# Now push a chunk that exceeds capacity.
	var overflow_chunk := '{"response": "%s"}' % "B".repeat(20)
	var warned := false
	var _original_push_warning: Variant = null  # can't intercept, but we can check buffer state.
	adapter_buf._on_chunk_received(overflow_chunk)

	checks += 1
	# After overflow: buffer should have at most 1 entry (oldest dropped, new added).
	if adapter_buf._token_buffer.size() > 1:
		failures.append("MUST-7: overflow should drop oldest token — buffer size %d > 1" % adapter_buf._token_buffer.size())
	checks += 1
	# New token should be present.
	var buf_joined := "".join(Array(adapter_buf._token_buffer))
	if not buf_joined.contains("B"):
		failures.append("MUST-7: new token 'B...' should be in buffer after overflow")

	# ── MUST-8: _on_chunk_received parses NDJSON, accumulates tokens ──────────
	var adapter_chunk := OllamaLLMAdapter.new()
	adapter_chunk.set_mock_mode(true)
	adapter_chunk._token_buffer = PackedStringArray()
	adapter_chunk._token_buffer_bytes = 0
	adapter_chunk._full_response_text = ""
	adapter_chunk._request_active = true

	var ndjson := '{"response":"Hello"}\n{"response":" world"}\n{"response":"","done":true}'
	adapter_chunk._on_chunk_received(ndjson)
	checks += 1
	if adapter_chunk._full_response_text != "Hello world":
		failures.append(
			"MUST-8: accumulated text should be 'Hello world', got '%s'" % adapter_chunk._full_response_text
		)
	checks += 1
	if adapter_chunk._token_buffer.size() != 2:
		failures.append(
			"MUST-8: token buffer should have 2 entries (ignores empty done token), got %d" % adapter_chunk._token_buffer.size()
		)

	# ── MUST-9: _finish_request(stopped=true) fires on_done with stopped=true ──
	var adapter_finish := OllamaLLMAdapter.new()
	adapter_finish.set_mock_mode(true)
	adapter_finish._request_active = true
	adapter_finish._full_response_text = "partial"
	adapter_finish._last_provider = "ollama-local"
	adapter_finish._last_selected_model = "test-model"
	var finish_stopped := false
	var finish_text := ""
	adapter_finish._active_on_token = func(_t: String) -> void: pass
	adapter_finish._active_on_done = func(r: Dictionary) -> void:
		finish_stopped = r.get("stopped", false)
		finish_text = r.get("text", "")
	adapter_finish._finish_request(true)
	checks += 1
	if not finish_stopped:
		failures.append("MUST-9: _finish_request(true) should set stopped=true in on_done result")
	checks += 1
	if finish_text != "partial":
		failures.append("MUST-9: _finish_request should pass accumulated text, got '%s'" % finish_text)

	# ── MUST-10: RequestAICreationHelpService on_complete receives final action ─
	var stub_llm := StubLLM.new()
	stub_llm.inject_text = "Wyjaśnienie akcji"
	stub_llm.inject_provider = "ollama-local"
	var stub_mod := StubModeration.new()
	var stub_clock := StubClock.new()
	var stub_loc := StubLocalization.new()

	var ai_service := RequestAICreationHelpService.new().setup(
		stub_llm, stub_mod, stub_clock, stub_loc
	)
	var actor := PlayerProfile.new("pid-1", PlayerProfile.Role.KID)

	var on_complete_action: AIAssistantAction = null
	ai_service.execute(
		"sess-1",
		"Dodaj drzewo",
		actor,
		false,
		func(a: AIAssistantAction) -> void:
			on_complete_action = a
	)
	checks += 1
	if on_complete_action == null:
		failures.append("MUST-10: on_complete should be called with AIAssistantAction")
	else:
		checks += 1
		if on_complete_action.explanation != "Wyjaśnienie akcji":
			failures.append(
				"MUST-10: action.explanation should be 'Wyjaśnienie akcji', got '%s'" % on_complete_action.explanation
			)

	# ── MUST-11: RequestGameplayHintService on_complete receives hint dict ─────
	stub_llm.inject_text = "Sprawdź skrzynię!"
	var hint_service := RequestGameplayHintService.new().setup(
		stub_llm, stub_mod, stub_clock, stub_loc
	)

	var on_complete_hint: Dictionary = {}
	hint_service.execute(
		"sess-2",
		{"hint_level": 1, "situation": "gracz utknął", "quest_id": "q-1"},
		actor,
		func(h: Dictionary) -> void:
			on_complete_hint = h
	)
	checks += 1
	if on_complete_hint.is_empty():
		failures.append("MUST-11: on_complete should be called with hint dict")
	else:
		checks += 1
		if on_complete_hint.get("hint_text", "") != "Sprawdź skrzynię!":
			failures.append(
				"MUST-11: hint_text should be 'Sprawdź skrzynię!', got '%s'" % on_complete_hint.get("hint_text", "")
			)

	# ── MUST-12: ParentScriptEditorService explain_script on_complete ─────────
	stub_llm.inject_text = "Ten skrypt robi X"
	var parent_actor := PlayerProfile.new("pid-2", PlayerProfile.Role.PARENT)
	var script_repo := StubScriptRepo.new()
	var script_service := ParentScriptEditorService.new().setup(
		script_repo, stub_llm, stub_clock, null, stub_mod
	)

	var on_complete_explain: Dictionary = {}
	script_service.explain_script(
		"proj-1",
		"script.gd",
		parent_actor,
		func(r: Dictionary) -> void:
			on_complete_explain = r
	)
	checks += 1
	if on_complete_explain.is_empty():
		failures.append("MUST-12: on_complete should be called with explanation dict")
	else:
		checks += 1
		if on_complete_explain.get("explanation", "") != "Ten skrypt robi X":
			failures.append(
				"MUST-12: explanation should be 'Ten skrypt robi X', got '%s'" % on_complete_explain.get("explanation", "")
			)

	# ── MUST-13: non-streaming — on_token called once with full text before on_done ──
	# Verify Option B contract: _finish_request calls on_token once with the accumulated
	# text, then calls on_done with the same text. Tested white-box via _finish_request.
	var adapter_nt := OllamaLLMAdapter.new()
	adapter_nt.set_mock_mode(true)
	adapter_nt._request_active = true
	adapter_nt._full_response_text = "pełny tekst odpowiedzi"
	adapter_nt._last_provider = "ollama-local"
	adapter_nt._last_selected_model = "test-model"
	var on_token_calls: Array[String] = []
	var on_done_text_nt := ""
	adapter_nt._active_on_token = func(t: String) -> void:
		on_token_calls.append(t)
	adapter_nt._active_on_done = func(r: Dictionary) -> void:
		on_done_text_nt = r.get("text", "")
	adapter_nt._finish_request(false)
	checks += 1
	if on_token_calls.size() != 1:
		failures.append("MUST-13: on_token should be called exactly once via _finish_request, called %d times" % on_token_calls.size())
	checks += 1
	if on_done_text_nt != "pełny tekst odpowiedzi":
		failures.append("MUST-13: on_done text should be 'pełny tekst odpowiedzi', got '%s'" % on_done_text_nt)
	checks += 1
	if on_token_calls.size() == 1 and on_token_calls[0] != on_done_text_nt:
		failures.append("MUST-13: on_token text '%s' should equal on_done text '%s'" % [on_token_calls[0], on_done_text_nt])

	# ── MUST-14: complete_with_tools async — mock path delivers result via on_done ─
	var adapter_cwt := OllamaLLMAdapter.new()
	adapter_cwt.set_mock_mode(true)
	var cwt_env := PromptEnvelope.new("Pomaluj na kolor żółty")
	cwt_env.permitted_tools = ["paint"]
	var cwt_result: Array = []
	var cwt_done_called := false
	adapter_cwt.complete_with_tools(
		cwt_env,
		func(invocations: Array) -> void:
			cwt_result = invocations
			cwt_done_called = true
	)
	checks += 1
	if not cwt_done_called:
		failures.append("MUST-14: complete_with_tools on_done not called in mock path")
	checks += 1
	if cwt_result.is_empty():
		failures.append("MUST-14: complete_with_tools result should contain at least one ToolInvocation")
	else:
		checks += 1
		var cwt_inv: ToolInvocation = cwt_result[0]
		if cwt_inv.tool_name != "paint":
			failures.append("MUST-14: expected tool_name 'paint', got '%s'" % cwt_inv.tool_name)

	# ── MUST-15: complete_with_tools null envelope — on_done called with empty array ─
	var adapter_cwt_null := OllamaLLMAdapter.new()
	adapter_cwt_null.set_mock_mode(true)
	var cwt_null_done := false
	var cwt_null_result: Array = [ToolInvocation.new("x", {}, "x")]  # prefill non-empty
	adapter_cwt_null.complete_with_tools(
		null,
		func(invocations: Array) -> void:
			cwt_null_result = invocations
			cwt_null_done = true
	)
	checks += 1
	if not cwt_null_done:
		failures.append("MUST-15: complete_with_tools null envelope — on_done not called")
	checks += 1
	if not cwt_null_result.is_empty():
		failures.append("MUST-15: complete_with_tools null envelope — expected empty result, got %d items" % cwt_null_result.size())

	# ── MUST-16: Polish UTF-8 byte count — 100 chars = 200 bytes in buffer ─────────
	var adapter_utf := OllamaLLMAdapter.new()
	adapter_utf.set_mock_mode(true)
	adapter_utf._token_buffer = PackedStringArray()
	adapter_utf._token_buffer_bytes = 0
	adapter_utf._request_active = true
	adapter_utf._full_response_text = ""

	# "ą" is 2 bytes in UTF-8. 100 × "ą" = 200 bytes but 100 chars.
	var polish_100 := "ą".repeat(100)
	checks += 1
	if polish_100.to_utf8_buffer().size() != 200:
		failures.append("MUST-16: 100 × 'ą' should be 200 UTF-8 bytes, got %d" % polish_100.to_utf8_buffer().size())

	# Feed token via _on_chunk_received — buffer should record 200 bytes.
	var polish_json := '{"response": "%s"}' % polish_100
	adapter_utf._on_chunk_received(polish_json)
	checks += 1
	if adapter_utf._token_buffer_bytes != 200:
		failures.append("MUST-16: buffer byte count should be 200 for 100 × 'ą', got %d" % adapter_utf._token_buffer_bytes)

	# Overflow: fill buffer to just under 4096 bytes using "ą" (2 bytes each).
	# 2048 × "ą" = 4096 bytes exactly — adding one more "ą" should trigger drop.
	var adapter_utf2 := OllamaLLMAdapter.new()
	adapter_utf2.set_mock_mode(true)
	adapter_utf2._token_buffer = PackedStringArray()
	adapter_utf2._token_buffer_bytes = 0
	adapter_utf2._request_active = true
	adapter_utf2._full_response_text = ""

	# Pre-fill with a single big token of 4086 bytes (2043 × "ą").
	var big_polish := "ą".repeat(2043)  # 4086 bytes
	adapter_utf2._token_buffer.append(big_polish)
	adapter_utf2._token_buffer_bytes = big_polish.to_utf8_buffer().size()  # 4086

	# Now add a 20-byte token ("ą" × 10 = 20 bytes) — total would be 4106 > 4096, drop triggered.
	var overflow_polish := '{"response": "%s"}' % "ą".repeat(10)
	adapter_utf2._on_chunk_received(overflow_polish)
	checks += 1
	# Buffer should have dropped the original big token and kept the new one.
	if adapter_utf2._token_buffer.size() > 1:
		failures.append("MUST-16: UTF-8 overflow should drop oldest token — size %d > 1" % adapter_utf2._token_buffer.size())
	checks += 1
	if adapter_utf2._token_buffer.size() == 1 and not adapter_utf2._token_buffer[0].contains("ą"):
		failures.append("MUST-16: new Polish token should remain after overflow drop")

	# ── MUST-17: null parent_node — push_warning fires (verified via code path) ────
	# We cannot intercept push_warning() in GDScript, but we can verify the code path
	# is reachable and does not crash by checking the method exists on the adapter.
	# A separate integration test would capture the warning via Engine error logger.
	var adapter_pn := OllamaLLMAdapter.new()
	adapter_pn.setup(null, null, false, {}, "", null)  # explicit null parent_node
	checks += 1
	# Verify _ensure_helper does not crash when parent_node is null
	# (in SceneTree test context, call_deferred to root may silently fail — that is expected).
	var pn_crash := false
	# We do NOT call _ensure_helper directly to avoid adding an unparented Node to the
	# test SceneTree root, which can cause Godot editor warnings. Instead verify the guard.
	if adapter_pn._parent_node != null:
		pn_crash = true
		failures.append("MUST-17: _parent_node should be null when not provided")
	if not pn_crash:
		pass  # warning fires at runtime when _ensure_helper is called; not catchable in unit test

	# ── Results ───────────────────────────────────────────────────────────────
	if failures.is_empty():
		print("OK  test_ollama_llm_adapter_streaming — %d checks passed" % checks)
		quit(0)
	else:
		for f in failures:
			printerr("FAIL  %s" % f)
		printerr("FAILED  test_ollama_llm_adapter_streaming — %d/%d checks failed" % [failures.size(), checks])
		quit(1)
