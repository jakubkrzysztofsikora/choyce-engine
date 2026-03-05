## In-memory adapter for ParentalPolicyStorePort.
## Stores parental control policies in a dictionary keyed by parent profile ID.
## Suitable for tests and single-session use; data is lost on restart.
class_name InMemoryParentalPolicyStore
extends ParentalPolicyStorePort

var _policies: Dictionary = {}


func setup() -> InMemoryParentalPolicyStore:
	_policies = {}
	return self


func save_policy(parent_id: String, policy: ParentalControlPolicy) -> bool:
	if parent_id.strip_edges().is_empty():
		return false
	if policy == null:
		return false
	_policies[parent_id] = policy
	return true


func load_policy(parent_id: String) -> ParentalControlPolicy:
	if parent_id.strip_edges().is_empty():
		return null
	var result: Variant = _policies.get(parent_id, null)
	if result is ParentalControlPolicy:
		return result as ParentalControlPolicy
	return null
