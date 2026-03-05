## Domain service encapsulating publishing business rules.
## Determines who can publish, who must approve, and what
## visibility levels are allowed per age band.
class_name PublishingPolicy
extends RefCounted


## Kids and parents can request publishing, but never null/invalid actors.
func can_request_publish(requester: PlayerProfile) -> bool:
	if requester == null:
		return false
	if requester.profile_id.is_empty():
		return false
	return requester.is_kid() or requester.is_parent()


## Only parents can approve publish requests.
func can_approve(approver: PlayerProfile) -> bool:
	if approver == null:
		return false
	return approver.is_parent()


## Only parents can reject or unpublish.
func can_reject(reviewer: PlayerProfile) -> bool:
	if reviewer == null:
		return false
	return reviewer.is_parent()


## Only parents can unpublish content.
func can_unpublish(actor: PlayerProfile) -> bool:
	if actor == null:
		return false
	return actor.is_parent()


## Kid requests always need parent review. Parents can self-approve.
func requires_review(requester: PlayerProfile) -> bool:
	return requester.is_kid()


## Kids can only publish as PRIVATE or FAMILY (not CLASSROOM).
## Parents can use all visibility levels.
func allowed_visibility(profile: PlayerProfile) -> Array:
	if profile.is_kid():
		return [PublishRequest.Visibility.PRIVATE, PublishRequest.Visibility.FAMILY]
	return [
		PublishRequest.Visibility.PRIVATE,
		PublishRequest.Visibility.FAMILY,
		PublishRequest.Visibility.CLASSROOM,
	]


## Check if a visibility level is permitted for this profile.
func is_visibility_allowed(profile: PlayerProfile, vis: PublishRequest.Visibility) -> bool:
	return vis in allowed_visibility(profile)
