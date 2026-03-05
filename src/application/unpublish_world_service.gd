## Application service: takes down a published world from the family library.
## Only parents can unpublish. The request transitions to UNPUBLISHED and
## can be revised and re-submitted.
class_name UnpublishWorldService
extends UnpublishWorldPort

var _publish_store: PublishStorePort
var _policy: PublishingPolicy
var _clock: ClockPort
var _event_bus: DomainEventBus
var _role_token_guard: RoleTokenGuard


func setup(
	publish_store: PublishStorePort,
	policy: PublishingPolicy,
	clock: ClockPort,
	event_bus: DomainEventBus = null,
	role_token_guard: RoleTokenGuard = null
) -> UnpublishWorldService:
	_publish_store = publish_store
	_policy = policy
	_clock = clock
	_event_bus = event_bus
	_role_token_guard = role_token_guard
	return self


func execute(request_id: String, actor: PlayerProfile, reason: String) -> PublishRequest:
	if _role_token_guard != null and not _role_token_guard.verify_parent_profile(actor):
		return null
	if not _policy.can_unpublish(actor):
		return null

	var request := _publish_store.load_request(request_id)
	if request == null:
		return null

	if not request.unpublish(_clock.now_iso()):
		return null

	var event := WorldUnpublishedEvent.new(request_id, actor.profile_id, _clock.now_iso())
	event.world_id = request.world_id
	event.reason = reason

	_publish_store.save_request(request)

	if _event_bus != null:
		_event_bus.emit(event)

	return request
