## Application service: parent reviews a pending publish request.
## Validates parent role via PublishingPolicy, transitions the request
## state, and emits the appropriate domain event.
class_name ReviewPublishRequestService
extends ReviewPublishRequestPort

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
) -> ReviewPublishRequestService:
	_publish_store = publish_store
	_policy = policy
	_clock = clock
	_event_bus = event_bus
	_role_token_guard = role_token_guard
	return self


func execute(request_id: String, approved: bool, reviewer: PlayerProfile, reason: String) -> PublishRequest:
	var request := _publish_store.load_request(request_id)
	if request == null:
		return null
	if _role_token_guard != null and not _role_token_guard.verify_parent_profile(reviewer):
		return null

	if approved:
		if not _policy.can_approve(reviewer):
			return null

		if not request.approve(reviewer.profile_id):
			return null

		# Auto-publish on approval
		var now := _clock.now_iso()
		if not request.publish(now):
			return null

		if _event_bus != null:
			var event := PublishApprovedEvent.new(request_id, reviewer.profile_id, now)
			event.reviewer_id = reviewer.profile_id
			event.visibility = _visibility_name(request.visibility)
			_event_bus.emit(event)

			var pub_event := WorldPublishedEvent.new(request_id, reviewer.profile_id, now)
			pub_event.project_id = request.project_id
			pub_event.world_id = request.world_id
			pub_event.visibility = _visibility_name(request.visibility)
			_event_bus.emit(pub_event)

		_publish_store.save_request(request)
		return request
	else:
		if not _policy.can_reject(reviewer):
			return null

		if not request.reject(reviewer.profile_id, reason):
			return null

		if _event_bus != null:
			var event := PublishRejectedEvent.new(request_id, reviewer.profile_id, _clock.now_iso())
			event.reviewer_id = reviewer.profile_id
			event.rejection_reason = reason
			_event_bus.emit(event)

		_publish_store.save_request(request)
		return request


func _visibility_name(vis: PublishRequest.Visibility) -> String:
	match vis:
		PublishRequest.Visibility.PRIVATE: return "PRIVATE"
		PublishRequest.Visibility.FAMILY: return "FAMILY"
		PublishRequest.Visibility.CLASSROOM: return "CLASSROOM"
	return "PRIVATE"
