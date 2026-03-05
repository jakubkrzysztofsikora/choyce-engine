## Application-level failsafe controller for AI generation paths.
## When enabled, generative AI actions are blocked while deterministic
## rules-based helper hints remain available.
class_name AIFailsafeController
extends RefCounted

var _enabled: bool = false
var _reason: String = ""


func setup(enabled: bool = false, reason: String = "") -> AIFailsafeController:
	_enabled = enabled
	_reason = reason.strip_edges()
	return self


func enable(reason: String = "") -> void:
	_enabled = true
	_reason = reason.strip_edges()


func disable() -> void:
	_enabled = false
	_reason = ""


func is_enabled() -> bool:
	return _enabled


func current_reason() -> String:
	return _reason


func build_disabled_action(
	session_id: String,
	prompt_text: String,
	clock: ClockPort = null
) -> AIAssistantAction:
	var action := AIAssistantAction.new(
		"%s_failsafe_%d" % [session_id, absi(prompt_text.hash())],
		prompt_text
	)
	action.status = AIAssistantAction.ActionStatus.REJECTED
	action.impact_level = AIAssistantAction.ImpactLevel.LOW
	action.requires_parent_approval = false
	action.created_at = clock.now_iso() if clock != null else ""
	action.explanation = "Tryb awaryjny AI jest aktywny. Edytor dziala dalej, ale generowanie AI jest chwilowo wylaczone."
	if not _reason.is_empty():
		action.explanation = "%s Powod: %s." % [action.explanation, _reason]
	return action


func rules_based_hint(context: Dictionary, hint_level: int) -> String:
	var level := clampi(hint_level, 1, 3)
	var objective := str(context.get("objective", "")).strip_edges()
	if objective.is_empty():
		objective = str(context.get("situation", "")).strip_edges()

	match level:
		1:
			if objective.is_empty():
				return "Zacznij od jednego malego kroku i sprawdz, co sie zmieni."
			return "Skup sie na celu: %s. Zacznij od najprostszego kroku." % objective
		2:
			if objective.is_empty():
				return "Sprawdz po kolei: miejsce, przedmiot i zasade, ktora ma zadzialac."
			return "Najpierw ustaw element zwiazany z celem '%s', potem uruchom test." % objective
		3:
			if objective.is_empty():
				return "Uzyj podpowiedzi: dodaj brakujacy element i uruchom krotki playtest."
			return "Plan: 1) dodaj element dla '%s', 2) polacz zasade, 3) uruchom playtest." % objective
		_:
			return "Sprobuj jeszcze raz krok po kroku."
