## Application service: initiates publishing a world to the family library.
## Runs content moderation on world text and assets, creates a PublishRequest,
## and gates on parent approval via PublishingPolicy. Private-by-default sharing.
class_name PublishToFamilyLibraryService
extends PublishToFamilyLibraryPort

var _project_store: ProjectStorePort
var _publish_store: PublishStorePort
var _moderation: ModerationPort
var _clock: ClockPort
var _policy: PublishingPolicy
var _event_bus: DomainEventBus
var _role_token_guard: RoleTokenGuard


func setup(
	project_store: ProjectStorePort,
	publish_store: PublishStorePort,
	moderation: ModerationPort,
	clock: ClockPort,
	policy: PublishingPolicy,
	event_bus: DomainEventBus = null,
	role_token_guard: RoleTokenGuard = null
) -> PublishToFamilyLibraryService:
	_project_store = project_store
	_publish_store = publish_store
	_moderation = moderation
	_clock = clock
	_policy = policy
	_event_bus = event_bus
	_role_token_guard = role_token_guard
	return self


func execute(project_id: String, world_id: String, requester: PlayerProfile) -> PublishRequest:
	if not _policy.can_request_publish(requester):
		return null
	if requester != null and requester.is_parent():
		if _role_token_guard != null and not _role_token_guard.verify_parent_profile(requester):
			return null

	var project := _project_store.load_project(project_id)
	if project == null:
		return null

	var world := project.get_world(world_id)
	if world == null:
		return null

	var now := _clock.now_iso()

	var request := PublishRequest.new(project_id, world_id)
	request.request_id = "%s_pub_%s" % [world_id, _clock.now_msec()]
	request.requester_id = requester.profile_id
	request.visibility = PublishRequest.Visibility.PRIVATE
	request.created_at = now

	# Run content moderation on world name, rule names, and node names
	# plus generated visual/audio publishability checks.
	var texts_to_check: Array[String] = [world.name]
	for rule in world.game_rules:
		texts_to_check.append(rule.display_name)
	for node in world.scene_nodes:
		texts_to_check.append(node.display_name)

	for text in texts_to_check:
		if text.is_empty():
			continue
		var result := _moderation.check_text(text, requester.age_band)
		request.moderation_results.append(result)

	# Visual moderation path for AI-generated visuals.
	for node_variant in world.scene_nodes:
		if not (node_variant is SceneNode):
			continue
		var node: SceneNode = node_variant
		if node.provenance != null and node.provenance.source == ProvenanceData.SourceType.AI_VISUAL:
			var image_data := _extract_node_image_data(node)
			var image_result := _moderation.check_image(image_data, requester.age_band)
			image_result.category = "publish_visual"
			request.moderation_results.append(image_result)

	# Audio moderation path for AI-generated audio descriptors.
	for node_variant in world.scene_nodes:
		if not (node_variant is SceneNode):
			continue
		var node: SceneNode = node_variant
		if node.provenance != null and node.provenance.source == ProvenanceData.SourceType.AI_AUDIO:
			var audio_desc := str(node.properties.get("audio_description", node.display_name)).strip_edges()
			var audio_result := _moderation.check_text(
				"audio:%s" % audio_desc,
				requester.age_band
			)
			audio_result.category = "publish_audio"
			request.moderation_results.append(audio_result)

	# Determine state based on moderation
	if not request.all_moderation_passed():
		request.state = PublishRequest.PublishState.REJECTED
		for r in request.moderation_results:
			if r.is_blocked():
				request.rejection_reason = r.reason
				break
		_publish_store.save_request(request)
		return request

	request.state = PublishRequest.PublishState.MODERATION_PASSED

	# Route through policy: kids need parent review, parents can self-approve
	if _policy.requires_review(requester):
		if not request.submit_for_review(""):  # reviewer TBD until parent acts
			return null
	else:
		if not request.approve(requester.profile_id):
			return null
		if not request.publish(now):
			return null

	# Emit submission event
	if _event_bus != null:
		var event := PublishRequestSubmittedEvent.new(request.request_id, requester.profile_id, now)
		event.project_id = project_id
		event.world_id = world_id
		event.visibility = "PRIVATE"
		_event_bus.emit(event)

	# Emit published event if self-approved by parent
	if request.state == PublishRequest.PublishState.PUBLISHED and _event_bus != null:
		var pub_event := WorldPublishedEvent.new(request.request_id, requester.profile_id, now)
		pub_event.project_id = project_id
		pub_event.world_id = world_id
		pub_event.visibility = "PRIVATE"
		_event_bus.emit(pub_event)

	_publish_store.save_request(request)
	return request


func _extract_node_image_data(node: SceneNode) -> PackedByteArray:
	var raw: Variant = node.properties.get("image_data", PackedByteArray())
	if raw is PackedByteArray:
		var image_data: PackedByteArray = raw
		if not image_data.is_empty():
			return image_data
	# Minimal PNG signature fallback keeps moderation deterministic.
	return PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])
