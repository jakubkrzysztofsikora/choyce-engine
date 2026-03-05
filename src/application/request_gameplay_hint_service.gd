## Application service: generates context-aware gameplay hints.
## Uses scaffolding strategy: level 1 (nudge), level 2 (guidance),
## level 3 (near-solution). Never reveals full answers by default.
class_name RequestGameplayHintService
extends RequestGameplayHintPort

var _llm: LLMPort
var _moderation: ModerationPort
var _clock: ClockPort
var _localization: LocalizationPolicyPort
var _event_bus: DomainEventBus
var _failsafe: AIFailsafeController
var _language_policy: PolishFirstLanguagePolicyService
var _prompt_templates: RefCounted


func setup(
	llm: LLMPort,
	moderation: ModerationPort,
	clock: ClockPort,
	localization: LocalizationPolicyPort,
	event_bus: DomainEventBus = null,
	failsafe: AIFailsafeController = null,
	parental_policy_store: ParentalPolicyStorePort = null,
	language_policy: PolishFirstLanguagePolicyService = null,
	prompt_templates: RefCounted = null
) -> RequestGameplayHintService:
	_llm = llm
	_moderation = moderation
	_clock = clock
	_localization = localization
	_event_bus = event_bus
	_failsafe = failsafe
	_language_policy = language_policy if language_policy != null else PolishFirstLanguagePolicyService.new().setup(localization, parental_policy_store)
	_prompt_templates = prompt_templates
	return self


## Returns {"hint_text": String, "hint_level": int, "quest_id": String}.
func execute(session_id: String, context: Dictionary, actor: PlayerProfile) -> Dictionary:
	var hint_level: int = context.get("hint_level", 1)
	hint_level = clampi(hint_level, 1, 3)
	var adaptive := _build_adaptive_guidance(context, actor, hint_level)
	hint_level = int(adaptive.get("recommended_hint_level", hint_level))
	hint_level = clampi(hint_level, 1, 3)

	var quest_id: String = context.get("quest_id", "")
	var situation: String = context.get("situation", "")

	# Failsafe mode disables generative hints but keeps helper available.
	if _failsafe != null and _failsafe.is_enabled():
		var rules_hint := _failsafe.rules_based_hint(context, hint_level)
		rules_hint = _moderate_hint_output(session_id, actor, rules_hint, hint_level)
		return {
			"hint_text": rules_hint,
			"hint_level": hint_level,
			"quest_id": quest_id,
			"difficulty_adjustment": adaptive.get("difficulty_adjustment", {}),
			"quest_suggestion": adaptive.get("quest_suggestion", ""),
			"reveals_full_solution": false,
		}

	var scaffold_instruction := _scaffold_prompt(hint_level)
	var resolved_locale := _resolve_ai_locale(actor)
	var prompt_text := _build_hint_prompt(scaffold_instruction, situation, resolved_locale, actor)

	var envelope := PromptEnvelope.new(
		prompt_text,
		resolved_locale,
		actor.age_band
	)
	envelope.session_id = session_id
	envelope.max_tokens = 150

	var hint_text := _llm.complete(envelope)

	if _is_model_unavailable(hint_text):
		if _failsafe != null:
			hint_text = _failsafe.rules_based_hint(context, hint_level)
		else:
			hint_text = _fallback_hint(hint_level)
		_emit_safety_event(
			session_id,
			actor.profile_id,
			"LLM unavailable for hint generation",
			hint_text,
			"RULES_HINT_FALLBACK"
		)

	hint_text = _moderate_hint_output(session_id, actor, hint_text, hint_level)
	if _looks_like_full_solution(hint_text):
		var guarded_hint := _fallback_hint(hint_level)
		_emit_safety_event(
			session_id,
			actor.profile_id,
			"Hint scaffold guard triggered for full-solution wording",
			guarded_hint,
			"HINT_SCAFFOLD_GUARD"
		)
		hint_text = guarded_hint

	return {
		"hint_text": hint_text,
		"hint_level": hint_level,
		"quest_id": quest_id,
		"difficulty_adjustment": adaptive.get("difficulty_adjustment", {}),
		"quest_suggestion": adaptive.get("quest_suggestion", ""),
		"reveals_full_solution": false,
	}


func _scaffold_prompt(level: int) -> String:
	match level:
		1:
			return "Daj delikatną wskazówkę. Nie zdradzaj rozwiązania."
		2:
			return "Daj bardziej szczegółową wskazówkę. Naprowadź na kierunek rozwiązania."
		3:
			return "Daj szczegółową pomoc, ale nie podawaj pełnego rozwiązania."
		_:
			return "Daj delikatną wskazówkę."


func _emit_safety_event(
	session_id: String,
	actor_id: String,
	trigger_context: String,
	safe_alternative: String,
	policy_rule: String = "MODERATION_BLOCK"
) -> void:
	if _event_bus == null:
		return
	var event := SafetyInterventionTriggeredEvent.new(
		"%s_hint_%s" % [session_id, _clock.now_msec()],
		actor_id,
		_clock.now_iso()
	)
	event.decision_type = "BLOCK"
	event.policy_rule = policy_rule
	event.trigger_context = trigger_context
	event.safe_alternative_offered = not safe_alternative.is_empty()
	_event_bus.emit(event)


func _is_model_unavailable(hint_text: String) -> bool:
	if hint_text.strip_edges().is_empty():
		return true
	if _llm != null:
		return _llm.get_last_provider() == "fallback"
	return false


func _fallback_hint(level: int) -> String:
	match level:
		1: return "Spróbuj rozejrzeć się dookoła!"
		2: return "Sprawdź pobliskie przedmioty."
		3: return "Użyj przedmiotu, który znalazłeś wcześniej."
		_: return "Spróbuj jeszcze raz!"


func _build_adaptive_guidance(context: Dictionary, actor: PlayerProfile, hint_level: int) -> Dictionary:
	var failures := int(context.get("recent_failures", 0))
	var successes := int(context.get("recent_successes", 0))
	var stuck_seconds := int(context.get("stuck_seconds", 0))
	var objective := str(context.get("objective", "Pomóż bohaterowi ukończyć zadanie.")).strip_edges()
	if objective.is_empty():
		objective = "Pomóż bohaterowi ukończyć zadanie."

	var scalar := 1.0
	var hint_recommendation := hint_level

	if actor != null and actor.age_band != null and actor.age_band.band == AgeBand.Band.CHILD_6_8:
		scalar = 0.95

	if failures >= 4 or stuck_seconds >= 240:
		scalar -= 0.15
		hint_recommendation = mini(3, hint_level + 1)
	elif failures >= 2 or stuck_seconds >= 120:
		scalar -= 0.1
	elif successes >= 4 and stuck_seconds < 60:
		scalar += 0.1
		hint_recommendation = maxi(1, hint_level - 1)
	elif successes >= 2:
		scalar += 0.05

	scalar = clampf(scalar, 0.8, 1.2)
	var objective_steps := clampi(int(round(3.0 * scalar)), 2, 4)
	var spawn_scale := clampf(0.9 + ((scalar - 1.0) * 0.6), 0.8, 1.1)
	var reward_scale := clampf(1.0 + ((1.0 - scalar) * 0.25), 0.9, 1.05)

	return {
		"recommended_hint_level": hint_recommendation,
		"difficulty_adjustment": {
			"difficulty_scalar": scalar,
			"spawn_rate_scale": spawn_scale,
			"reward_scale": reward_scale,
			"objective_steps": objective_steps,
		},
		"quest_suggestion": _build_adaptive_quest(objective, objective_steps, scalar),
	}


func _build_adaptive_quest(objective: String, objective_steps: int, scalar: float) -> String:
	var difficulty_tag := "łagodny"
	if scalar >= 1.1:
		difficulty_tag = "odważny"
	elif scalar >= 0.98:
		difficulty_tag = "standardowy"

	return "Mini-quest (%s): %s. Ukończ %d krótkie kroki." % [
		difficulty_tag,
		objective,
		objective_steps,
	]


func _looks_like_full_solution(hint_text: String) -> bool:
	var normalized := hint_text.to_lower()
	var markers := [
		"krok po kroku",
		"zrób dokładnie tak",
		"najpierw kliknij",
		"dokładna odpowiedź",
	]
	for marker in markers:
		if normalized.contains(marker):
			return true
	return false


func _moderate_hint_output(
	session_id: String,
	actor: PlayerProfile,
	hint_text: String,
	hint_level: int
) -> String:
	var check := _moderation.check_text(hint_text, actor.age_band)
	if check.is_blocked():
		_emit_safety_event(session_id, actor.profile_id, hint_text, check.safe_alternative)
		return check.safe_alternative if check.safe_alternative else _fallback_hint(hint_level)
	return hint_text


func _resolve_ai_locale(actor: PlayerProfile) -> String:
	if _language_policy != null:
		return _language_policy.resolve_locale(actor)
	if _localization != null:
		var locale := str(_localization.get_locale()).strip_edges()
		if not locale.is_empty():
			return locale
	return "pl-PL"


func _build_hint_prompt(
	scaffold_instruction: String,
	situation: String,
	locale: String,
	actor: PlayerProfile
) -> String:
	var context := situation.strip_edges()
	var fallback := "%s\nSytuacja: %s" % [scaffold_instruction, context]
	if _prompt_templates == null or not _prompt_templates.has_method("resolve_template"):
		return fallback

	var template_variant: Variant = _prompt_templates.call(
		"resolve_template",
		"gameplay_hint",
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
	parts.append(scaffold_instruction)
	if not user_prefix.is_empty():
		parts.append("%s %s" % [user_prefix, context])
	else:
		parts.append("Sytuacja: %s" % context)
	return "\n".join(parts).strip_edges()


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
