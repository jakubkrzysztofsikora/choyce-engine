## Parent-mode advanced scripting workflow service.
## Provides edit, explain, refactor suggestion, preview-diff apply, and rollback.
class_name ParentScriptEditorService
extends RefCounted

var _scripts: ScriptRepositoryPort
var _llm: LLMPort
var _clock: ClockPort
var _action_log: EventSourcedActionLog
var _moderation: ModerationPort
var _prompt_templates: RefCounted
var _pending_mutations: Dictionary = {}


func setup(
	scripts: ScriptRepositoryPort,
	llm: LLMPort,
	clock: ClockPort = null,
	action_log: EventSourcedActionLog = null,
	moderation: ModerationPort = null,
	prompt_templates: RefCounted = null
) -> ParentScriptEditorService:
	_scripts = scripts
	_llm = llm
	_clock = clock
	_action_log = action_log
	_moderation = moderation
	_prompt_templates = prompt_templates
	return self


func load_script(project_id: String, script_path: String, actor: PlayerProfile) -> Dictionary:
	if not _can_access_parent_mode(actor):
		return {"ok": false, "error": "Parent mode required"}
	if _scripts == null:
		return {"ok": false, "error": "Script repository unavailable"}

	var code := _scripts.load_script(project_id, script_path)
	return {
		"ok": true,
		"project_id": project_id,
		"script_path": script_path,
		"code": code,
	}


func explain_script(project_id: String, script_path: String, actor: PlayerProfile) -> Dictionary:
	var loaded := load_script(project_id, script_path, actor)
	if not loaded.get("ok", false):
		return loaded

	var prompt := PromptEnvelope.new(
		_build_parent_prompt("parent_script_explain", str(loaded.get("code", "")), actor),
		_resolve_parent_locale(actor),
		actor.age_band
	)
	var output := _llm.complete(prompt)
	return {
		"ok": true,
		"explanation": _moderate_parent_output(output, actor),
	}


func suggest_refactor(project_id: String, script_path: String, actor: PlayerProfile) -> Dictionary:
	var loaded := load_script(project_id, script_path, actor)
	if not loaded.get("ok", false):
		return loaded

	var prompt := PromptEnvelope.new(
		_build_parent_prompt("parent_script_refactor", str(loaded.get("code", "")), actor),
		_resolve_parent_locale(actor),
		actor.age_band
	)
	var output := _llm.complete(prompt)
	return {
		"ok": true,
		"suggestion": _moderate_parent_output(output, actor),
	}


func preview_mutation(
	project_id: String,
	script_path: String,
	new_code: String,
	actor: PlayerProfile
) -> Dictionary:
	var loaded := load_script(project_id, script_path, actor)
	if not loaded.get("ok", false):
		return loaded

	var current_code := str(loaded.get("code", ""))
	var normalized_new := new_code
	var diff := _build_line_diff(current_code, normalized_new)
	var mutation_id := _mutation_id(project_id, script_path)

	_pending_mutations[mutation_id] = {
		"project_id": project_id,
		"script_path": script_path,
		"old_code": current_code,
		"new_code": normalized_new,
		"diff": diff,
		"created_at": _now_iso(),
	}

	return {
		"ok": true,
		"mutation_id": mutation_id,
		"diff": diff,
		"old_code": current_code,
		"new_code": normalized_new,
	}


func apply_mutation(mutation_id: String, actor: PlayerProfile) -> Dictionary:
	if not _can_access_parent_mode(actor):
		return {"ok": false, "error": "Parent mode required"}
	if _scripts == null:
		return {"ok": false, "error": "Script repository unavailable"}
	if not _pending_mutations.has(mutation_id):
		return {
			"ok": false,
			"error": "Mutation must be previewed before apply",
		}

	var mutation: Dictionary = _pending_mutations[mutation_id]
	var project_id := str(mutation.get("project_id", ""))
	var script_path := str(mutation.get("script_path", ""))
	var old_code := str(mutation.get("old_code", ""))
	var new_code := str(mutation.get("new_code", ""))

	var saved := _scripts.save_script(project_id, script_path, new_code)
	if not saved:
		return {"ok": false, "error": "Failed to persist script mutation"}

	if _action_log != null:
		_action_log.record_ai_patch(
			_script_stream(project_id, script_path),
			{"status": "APPLIED", "code": new_code},
			{"status": "PREVIEWED", "code": old_code},
			actor.profile_id,
			_now_iso()
		)

	_pending_mutations.erase(mutation_id)
	return {
		"ok": true,
		"mutation_id": mutation_id,
		"rollback_token": {
			"project_id": project_id,
			"script_path": script_path,
			"code": old_code,
		},
	}


func rollback_mutation(rollback_token: Dictionary, actor: PlayerProfile) -> bool:
	if not _can_access_parent_mode(actor):
		return false
	if _scripts == null:
		return false

	var project_id := str(rollback_token.get("project_id", ""))
	var script_path := str(rollback_token.get("script_path", ""))
	var old_code := str(rollback_token.get("code", ""))
	if project_id.is_empty() or script_path.is_empty():
		return false

	var restored := _scripts.save_script(project_id, script_path, old_code)
	if not restored:
		return false

	if _action_log != null:
		_action_log.record_ai_patch(
			_script_stream(project_id, script_path),
			{"status": "REVERTED", "code": old_code},
			{"status": "APPLIED"},
			actor.profile_id,
			_now_iso()
		)
	return true


func _can_access_parent_mode(actor: PlayerProfile) -> bool:
	return actor != null and actor.is_parent()


func _mutation_id(project_id: String, script_path: String) -> String:
	var seed := "%s|%s|%s" % [project_id, script_path, _now_iso()]
	return "mut_%d" % absi(seed.hash())


func _script_stream(project_id: String, script_path: String) -> String:
	return "script:%s:%s" % [project_id, script_path]


func _now_iso() -> String:
	if _clock == null:
		return ""
	return _clock.now_iso()


func _build_line_diff(old_code: String, new_code: String) -> String:
	var old_lines := old_code.split("\n")
	var new_lines := new_code.split("\n")
	var max_lines := maxi(old_lines.size(), new_lines.size())

	var diff_parts: Array[String] = []
	for i in range(max_lines):
		var old_line := old_lines[i] if i < old_lines.size() else ""
		var new_line := new_lines[i] if i < new_lines.size() else ""
		if old_line == new_line:
			diff_parts.append("  %s" % old_line)
		else:
			if not old_line.is_empty():
				diff_parts.append("- %s" % old_line)
			if not new_line.is_empty():
				diff_parts.append("+ %s" % new_line)
	return "\n".join(diff_parts)


func _moderate_parent_output(text: String, actor: PlayerProfile) -> String:
	if _moderation == null:
		return text
	var check := _moderation.check_text(text, actor.age_band)
	if check.is_blocked():
		if not check.safe_alternative.is_empty():
			return check.safe_alternative
		return "Tresc odpowiedzi zostala ukryta przez moderacje."
	return text


func _resolve_parent_locale(actor: PlayerProfile) -> String:
	if actor == null:
		return "pl-PL"
	var locale := actor.language.strip_edges()
	if locale.is_empty():
		return "pl-PL"
	return locale


func _build_parent_prompt(use_case: String, script_code: String, actor: PlayerProfile) -> String:
	var locale := _resolve_parent_locale(actor)
	var fallback := script_code
	if use_case == "parent_script_explain":
		fallback = "Wyjasnij ten skrypt prostym jezykiem dla rodzica:\n%s" % script_code
	elif use_case == "parent_script_refactor":
		fallback = "Zaproponuj bezpieczny refaktor tego skryptu i podaj krotkie uzasadnienie:\n%s" % script_code
	if _prompt_templates == null or not _prompt_templates.has_method("resolve_template"):
		return fallback

	var template_variant: Variant = _prompt_templates.call(
		"resolve_template",
		use_case,
		locale,
		"parent",
		"PARENT"
	)
	var template: Dictionary = {}
	if template_variant is Dictionary:
		template = template_variant as Dictionary
	var system_prompt := str(template.get("system_prompt", "")).strip_edges()
	var user_prefix := str(template.get("user_prefix", "")).strip_edges()
	var parts: Array[String] = []
	if not system_prompt.is_empty():
		parts.append(system_prompt)
	if not user_prefix.is_empty():
		parts.append("%s\n%s" % [user_prefix, script_code])
	else:
		parts.append(script_code)
	var built := "\n".join(parts).strip_edges()
	if built.is_empty():
		return fallback
	return built
