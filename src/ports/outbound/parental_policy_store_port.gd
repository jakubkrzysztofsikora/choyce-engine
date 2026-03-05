## Outbound port for persisting and loading parental control policies.
## Separates structured policy data from the boolean consent store.
class_name ParentalPolicyStorePort
extends RefCounted


func save_policy(parent_id: String, policy: ParentalControlPolicy) -> bool:
	push_error("ParentalPolicyStorePort.save_policy() not implemented")
	return false


func load_policy(parent_id: String) -> ParentalControlPolicy:
	push_error("ParentalPolicyStorePort.load_policy() not implemented")
	return null
