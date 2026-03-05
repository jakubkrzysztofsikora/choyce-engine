## Application service: deterministic AI orchestration loop for creation assistance.
## Flow: intent -> pre-check -> plan -> validate -> transactional execute ->
## post-check -> audit. High-impact actions are blocked for human approval.
class_name RequestAICreationHelpService
extends RequestAICreationHelpPort

var _llm: LLMPort
var _moderation: ModerationPort
var _clock: ClockPort
var _localization: LocalizationPolicyPort
var _event_bus: DomainEventBus
var _tool_gateway: ToolExecutionGateway
var _tool_registry: AIToolRegistry
var _failsafe: AIFailsafeController
var _language_policy: PolishFirstLanguagePolicyService
var _prompt_templates: RefCounted


func setup(
	llm: LLMPort,
	moderation: ModerationPort,
	clock: ClockPort,
	localization: LocalizationPolicyPort,
	event_bus: DomainEventBus = null,
	tool_gateway: ToolExecutionGateway = null,
	tool_registry: AIToolRegistry = null,
	failsafe: AIFailsafeController = null,
	parental_policy_store: ParentalPolicyStorePort = null,
	language_policy: PolishFirstLanguagePolicyService = null,
	prompt_templates: RefCounted = null
) -> RequestAICreationHelpService:
	_llm = llm
	_moderation = moderation
	_clock = clock
	_localization = localization
	_event_bus = event_bus
	_tool_gateway = tool_gateway
	_tool_registry = tool_registry if tool_registry != null else AIToolRegistry.new()
	_failsafe = failsafe
	_language_policy = language_policy if language_policy != null else PolishFirstLanguagePolicyService.new().setup(localization, parental_policy_store)
	_prompt_templates = prompt_templates
	return self


func execute(session_id: String, prompt_text: String, actor: PlayerProfile, preview_only: bool = false) -> AIAssistantAction:
	var resolved_locale := _resolve_ai_locale(actor)

	# Step 1: Build prompt envelope with safety metadata
	var envelope := PromptEnvelope.new(
		_build_prompt_text("ai_creation_help", prompt_text, resolved_locale, actor),
		resolved_locale,
		actor.age_band
	)
	envelope.session_id = session_id

	# Restrict tool scope for kids
	if actor.is_kid():
		envelope.permitted_tools = ["scene_edit", "paint", "duplicate", "visual_generate"]
	else:
		envelope.permitted_tools = ["scene_edit", "paint", "duplicate", "logic_edit", "script_edit", "asset_import", "visual_generate"]

	_emit_ai_request_event(session_id, actor, envelope, prompt_text)

	# Failsafe mode: disable generative AI output while keeping editor flow alive.
	if _failsafe != null and _failsafe.is_enabled():
		var disabled_action := _failsafe.build_disabled_action(session_id, prompt_text, _clock)
		_emit_safety_block_event(
			"%s_failsafe_%s" % [session_id, _clock.now_msec()],
			actor.profile_id,
			prompt_text,
			disabled_action.explanation,
			"FAILSAFE_MODE"
		)
		return disabled_action

	# Step 2: Input moderation pre-check
	var input_check := _moderation.check_text(prompt_text, actor.age_band)
	if input_check.is_blocked():
		_emit_safety_block_event(
			"%s_input_%s" % [session_id, _clock.now_msec()],
			actor.profile_id,
			prompt_text,
			input_check.safe_alternative
		)
		var blocked_action := AIAssistantAction.new(
			"%s_blocked_%s" % [session_id, _clock.now_msec()],
			prompt_text
		)
		blocked_action.status = AIAssistantAction.ActionStatus.REJECTED
		blocked_action.explanation = input_check.safe_alternative if input_check.safe_alternative else input_check.reason
		blocked_action.created_at = _clock.now_iso()
		return blocked_action

	# Step 3: Ask LLM to propose tool calls
	var tool_invocations := _llm.complete_with_tools(envelope)

	# Step 4: Validate tool calls against scope and deterministic args
	var validation_result := _validate_tool_invocations(envelope, tool_invocations)
	if not validation_result.get("ok", false):
		var reason := str(validation_result.get("reason", "Invalid tool invocation"))
		_emit_safety_block_event(
			"%s_validation_%s" % [session_id, _clock.now_msec()],
			actor.profile_id,
			reason,
			"Poproś o prostszą zmianę."
		)
		var invalid_action := AIAssistantAction.new(
			"%s_invalid_%s" % [session_id, _clock.now_msec()],
			prompt_text
		)
		invalid_action.status = AIAssistantAction.ActionStatus.REJECTED
		invalid_action.explanation = reason
		invalid_action.created_at = _clock.now_iso()
		return invalid_action

	# Step 5: Build proposed action
	var action := AIAssistantAction.new(
		"%s_action_%s" % [session_id, _clock.now_msec()],
		prompt_text
	)
	action.tool_invocations = tool_invocations
	action.created_at = _clock.now_iso()
	action.provenance = _build_action_provenance(action.action_id)
	_tag_tool_invocation_provenance(action)

	# Step 6: Determine impact level
	action.impact_level = _assess_impact(tool_invocations, actor)
	action.requires_parent_approval = action.impact_level == AIAssistantAction.ImpactLevel.HIGH

	# Step 7: Generate explanation
	var explain_envelope := PromptEnvelope.new(
		_build_prompt_text("ai_creation_explain", str(tool_invocations), resolved_locale, actor),
		resolved_locale,
		actor.age_band
	)
	action.explanation = _llm.complete(explain_envelope)

	# Step 8: Output moderation post-check
	var output_check := _moderation.check_text(action.explanation, actor.age_band)
	if output_check.is_blocked():
		_emit_safety_block_event(
			"%s_output_%s" % [session_id, _clock.now_msec()],
			actor.profile_id,
			action.explanation,
			output_check.safe_alternative
		)
		action.explanation = output_check.safe_alternative if output_check.safe_alternative else ""

	# Step 9: Transactional execution (only low/medium impact).
	if action.requires_parent_approval or preview_only:
		action.status = AIAssistantAction.ActionStatus.PROPOSED
		return action

	return execute_pending_action(action, actor)


func execute_pending_action(action: AIAssistantAction, actor: PlayerProfile) -> AIAssistantAction:
	if action.status != AIAssistantAction.ActionStatus.PROPOSED:
		if action.status == AIAssistantAction.ActionStatus.APPLIED:
			return action
		# Allow retry if rejected? Probably not safely.
		action.mark_rejected("Action is not in PROPOSED state")
		return action

	if action.requires_parent_approval and actor.is_kid():
		# This should have been caught earlier, but safety check again.
		action.mark_rejected("Requires parent approval")
		return action

	var tx := _execute_transactionally(action, actor)
	if not tx.get("ok", false):
		action.mark_rejected(str(tx.get("reason", "Tool execution failed")))
		return action

	action.mark_applied()
	action.reversible_patch = {"undo_tokens": tx.get("undo_tokens", [])}
	_emit_ai_applied_event(action, actor)
	return action


func _assess_impact(invocations: Array, actor: PlayerProfile) -> AIAssistantAction.ImpactLevel:
	for inv in invocations:
		if inv is ToolInvocation and inv.requires_approval:
			return AIAssistantAction.ImpactLevel.HIGH

	if actor.is_kid():
		# Kids: any script/logic edit is high-impact
		for inv in invocations:
			if inv is ToolInvocation and inv.tool_name in ["logic_edit", "script_edit"]:
				return AIAssistantAction.ImpactLevel.HIGH
		if invocations.size() > 3:
			return AIAssistantAction.ImpactLevel.MEDIUM
		return AIAssistantAction.ImpactLevel.LOW
	else:
		# Parents: only bulk operations are high-impact
		if invocations.size() > 5:
			return AIAssistantAction.ImpactLevel.HIGH
		return AIAssistantAction.ImpactLevel.LOW


func _validate_tool_invocations(envelope: PromptEnvelope, invocations: Array) -> Dictionary:
	for invocation in invocations:
		if not invocation is ToolInvocation:
			return {"ok": false, "reason": "Malformed tool invocation payload"}

		var tool: ToolInvocation = invocation
		if not envelope.permitted_tools.has(tool.tool_name):
			return {
				"ok": false,
				"reason": "Tool '%s' is not allowed in this mode" % tool.tool_name,
			}

		if _tool_registry != null:
			var registry_validation := _tool_registry.validate_and_apply(tool)
			if not registry_validation.get("ok", false):
				return {
					"ok": false,
					"reason": str(registry_validation.get("error", "Tool schema validation failed")),
				}
		else:
			for key in tool.arguments.keys():
				var value: Variant = tool.arguments[key]
				if value is Callable or value is Object:
					return {
						"ok": false,
						"reason": "Tool '%s' has non-deterministic argument '%s'" % [tool.tool_name, str(key)],
					}

		# Image moderation for asset imports carrying inline data
		if tool.tool_name == "asset_import" and _moderation != null:
			var image_check := _moderate_asset_data(tool, envelope)
			if not image_check.get("ok", true):
				return image_check
		if tool.tool_name == "visual_generate":
			var visual_check := _validate_visual_generation_request(tool, envelope)
			if not visual_check.get("ok", true):
				return visual_check

	return {"ok": true}


func _resolve_ai_locale(actor: PlayerProfile) -> String:
	if _language_policy != null:
		return _language_policy.resolve_locale(actor)
	if _localization != null:
		var locale := str(_localization.get_locale()).strip_edges()
		if not locale.is_empty():
			return locale
	return "pl-PL"


func _build_prompt_text(
	use_case: String,
	user_text: String,
	locale: String,
	actor: PlayerProfile
) -> String:
	var clean_text := user_text.strip_edges()
	var fallback := clean_text
	if use_case == "ai_creation_explain":
		fallback = "Explain briefly what these changes will do: %s" % clean_text
	if _prompt_templates == null or not _prompt_templates.has_method("resolve_template"):
		return fallback

	var template_variant: Variant = _prompt_templates.call(
		"resolve_template",
		use_case,
		locale,
		_actor_role(actor),
		_age_band_name(actor)
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
		parts.append("%s %s" % [user_prefix, clean_text])
	elif not clean_text.is_empty():
		parts.append(clean_text)
	var built := "\n".join(parts).strip_edges()
	if built.is_empty():
		return fallback
	return built


func _actor_role(actor: PlayerProfile) -> String:
	if actor != null and actor.is_parent():
		return "parent"
	return "kid"


func _age_band_name(actor: PlayerProfile) -> String:
	if actor == null or actor.age_band == null:
		return "ANY"
	match actor.age_band.band:
		AgeBand.Band.CHILD_6_8:
			return "CHILD_6_8"
		AgeBand.Band.CHILD_9_12:
			return "CHILD_9_12"
		AgeBand.Band.TEEN:
			return "TEEN"
		AgeBand.Band.PARENT:
			return "PARENT"
		_:
			return "ANY"


func _execute_transactionally(action: AIAssistantAction, actor: PlayerProfile) -> Dictionary:
	if _tool_gateway == null:
		# No gateway configured yet: keep deterministic no-op apply semantics.
		return {"ok": true, "undo_tokens": []}

	var undo_tokens: Array = []
	var base_context := {"actor_id": actor.profile_id}
	var action_provenance := _provenance_to_dict(action.provenance)
	if not action_provenance.is_empty():
		base_context["provenance"] = action_provenance
	for invocation in action.tool_invocations:
		var context := base_context.duplicate(true)
		if invocation is ToolInvocation:
			var tool: ToolInvocation = invocation
			if not tool.provenance.is_empty():
				context["provenance"] = tool.provenance.duplicate(true)
		var result := _tool_gateway.execute(invocation, context)
		if not result.get("ok", false):
			for i in range(undo_tokens.size() - 1, -1, -1):
				_tool_gateway.rollback(undo_tokens[i], base_context)
			return {"ok": false, "reason": str(result.get("error", "Execution failed"))}

		var undo_token: Variant = result.get("undo_token", null)
		if undo_token is Dictionary:
			undo_tokens.append(undo_token)

	return {"ok": true, "undo_tokens": undo_tokens}


func _emit_ai_request_event(
	session_id: String,
	actor: PlayerProfile,
	envelope: PromptEnvelope,
	intent_summary: String
) -> void:
	if _event_bus == null:
		return

	var event := AIAssistanceRequestedEvent.new(
		session_id,
		actor.profile_id,
		_clock.now_iso()
	)
	event.prompt_envelope = envelope
	event.intent_summary = intent_summary
	_event_bus.emit(event)


func _emit_safety_block_event(
	decision_id: String,
	actor_id: String,
	trigger_context: String,
	safe_alternative: String,
	policy_rule: String = "MODERATION_BLOCK"
) -> void:
	if _event_bus == null:
		return

	var event := SafetyInterventionTriggeredEvent.new(
		decision_id,
		actor_id,
		_clock.now_iso()
	)
	event.decision_type = "BLOCK"
	event.policy_rule = policy_rule
	event.trigger_context = trigger_context
	event.safe_alternative_offered = not safe_alternative.is_empty()
	_event_bus.emit(event)


func _emit_ai_applied_event(action: AIAssistantAction, actor: PlayerProfile) -> void:
	if _event_bus == null:
		return

	var event := AIAssistanceAppliedEvent.new(
		action.action_id,
		actor.profile_id,
		_clock.now_iso()
	)
	event.event_id = action.action_id
	event.tool_invocations_count = action.tool_invocations.size()
	event.impact_level = _impact_level_name(action.impact_level)
	event.was_parent_approved = actor.is_parent()
	var patch_keys: Array[String] = []
	for key in action.reversible_patch.keys():
		patch_keys.append(str(key))
	event.reversible_patch_keys = patch_keys
	_event_bus.emit(event)


func _build_action_provenance(audit_id: String) -> ProvenanceData:
	var model_name := _resolve_llm_model_name()
	return ProvenanceData.new(ProvenanceData.SourceType.AI_TEXT, model_name, audit_id)


func _resolve_llm_model_name() -> String:
	if _llm == null:
		return ""
	if _llm.has_method("get_last_selected_model"):
		var selected_model: Variant = _llm.call("get_last_selected_model")
		var clean_selected := str(selected_model).strip_edges()
		if not clean_selected.is_empty():
			return clean_selected
	if _llm.has_method("get_last_provider"):
		var provider: Variant = _llm.call("get_last_provider")
		return str(provider).strip_edges()
	return ""


func _tag_tool_invocation_provenance(action: AIAssistantAction) -> void:
	var base := _provenance_to_dict(action.provenance)
	if base.is_empty():
		return
	for invocation in action.tool_invocations:
		if not (invocation is ToolInvocation):
			continue
		var tool: ToolInvocation = invocation
		var tagged := base.duplicate(true)
		tagged["source"] = _source_for_tool(tool.tool_name)
		tool.provenance = tagged


func _source_for_tool(tool_name: String) -> int:
	match tool_name:
		"visual_generate":
			return int(ProvenanceData.SourceType.AI_VISUAL)
		"generate_audio", "voice_generate", "music_generate", "sfx_generate":
			return int(ProvenanceData.SourceType.AI_AUDIO)
		_:
			return int(ProvenanceData.SourceType.AI_TEXT)


func _provenance_to_dict(provenance: ProvenanceData) -> Dictionary:
	if provenance == null:
		return {}
	return {
		"source": int(provenance.source),
		"generator_model": provenance.generator_model,
		"audit_id": provenance.audit_id,
		"timestamp": provenance.timestamp,
	}


func _moderate_asset_data(tool: ToolInvocation, envelope: PromptEnvelope) -> Dictionary:
	var base64_data := str(tool.arguments.get("asset_bytes_base64", "")).strip_edges()
	if base64_data.is_empty():
		return {"ok": true}

	var raw_bytes := Marshalls.base64_to_raw(base64_data)
	if raw_bytes.is_empty():
		return {"ok": true}

	var age_band: AgeBand = envelope.age_band if envelope != null else null
	var image_check := _moderation.check_image(raw_bytes, age_band)
	if image_check.is_blocked():
		return {
			"ok": false,
			"reason": "Asset import blocked by image moderation: %s" % image_check.reason,
		}
	return {"ok": true}


func _impact_level_name(level: AIAssistantAction.ImpactLevel) -> String:
	match level:
		AIAssistantAction.ImpactLevel.LOW: return "LOW"
		AIAssistantAction.ImpactLevel.MEDIUM: return "MEDIUM"
		AIAssistantAction.ImpactLevel.HIGH: return "HIGH"
	return "LOW"


func _validate_visual_generation_request(tool: ToolInvocation, envelope: PromptEnvelope) -> Dictionary:
	var style := str(tool.arguments.get("style_preset", "")).strip_edges().to_lower()
	var prompt := str(tool.arguments.get("prompt", "")).strip_edges().to_lower()
	var is_child := envelope != null and envelope.age_band != null and envelope.age_band.is_child()
	if not is_child:
		return {"ok": true}

	var safe_styles := [
		"cartoon",
		"storybook",
		"lowpoly",
		"pixel_fantasy",
		"watercolor",
	]
	if not safe_styles.has(style):
		return {
			"ok": false,
			"reason": "Visual style '%s' is not allowed in kid mode" % style,
		}

	if prompt.contains("photoreal") and _contains_human_visual_term(prompt):
		return {
			"ok": false,
			"reason": "Photoreal human generation is blocked in kid mode",
		}
	if style.contains("photoreal") and _contains_human_visual_term(prompt):
		return {
			"ok": false,
			"reason": "Photoreal human generation is blocked in kid mode",
		}
	return {"ok": true}


func _contains_human_visual_term(text: String) -> bool:
	var normalized := text.to_lower()
	for term in [
		"human",
		"person",
		"portrait",
		"selfie",
		"czlowiek",
		"osoba",
		"portret",
	]:
		if normalized.contains(term):
			return true
	return false
