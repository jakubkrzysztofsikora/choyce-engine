## Resolves language policy for AI interactions.
## Kid profiles are always Polish-first. Parent profiles may use non-Polish
## locale only when explicit language override is enabled in parental policy.
class_name PolishFirstLanguagePolicyService
extends RefCounted

var _localization: LocalizationPolicyPort
var _parental_policy_store: ParentalPolicyStorePort


func setup(
	localization: LocalizationPolicyPort,
	parental_policy_store: ParentalPolicyStorePort = null
) -> PolishFirstLanguagePolicyService:
	_localization = localization
	_parental_policy_store = parental_policy_store
	return self


func resolve_locale(actor: PlayerProfile) -> String:
	if actor == null:
		return "pl-PL"

	if actor.is_kid():
		return "pl-PL"

	var preferred := _preferred_locale(actor)
	if preferred.begins_with("pl"):
		return preferred

	if _is_parent_override_enabled(actor.profile_id):
		return preferred
	return "pl-PL"


func _preferred_locale(actor: PlayerProfile) -> String:
	var preferred := "pl-PL"
	if _localization != null:
		var locale := str(_localization.get_locale()).strip_edges()
		if not locale.is_empty():
			preferred = locale
	if actor != null and not actor.language.strip_edges().is_empty():
		preferred = actor.language.strip_edges()
	return preferred


func _is_parent_override_enabled(parent_id: String) -> bool:
	if _parental_policy_store == null:
		return false
	var policy := _parental_policy_store.load_policy(parent_id)
	if policy == null:
		return false
	return policy.language_override_allowed
