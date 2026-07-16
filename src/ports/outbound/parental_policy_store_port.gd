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


## True when a policy has been persisted for this profile. Lets callers
## distinguish a brand-new profile (nothing stored → apply first-run
## defaults) from one whose stored policy is present but unreadable
## (tamper/wrong key → load_policy fails closed to deny-all). Absence and
## deny-all must not collapse into the same signal.
func has_policy(parent_id: String) -> bool:
	push_error("ParentalPolicyStorePort.has_policy() not implemented")
	return false
