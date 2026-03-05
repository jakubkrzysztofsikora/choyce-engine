class_name PublishWorkflowServicesContractTest
extends PortContractTest


class MockProjectStore:
	extends ProjectStorePort

	var project: Project

	func save_project(_project: Project) -> bool:
		return false

	func load_project(project_id: String) -> Project:
		if project != null and project.project_id == project_id:
			return project
		return null

	func list_projects() -> Array:
		return [project] if project != null else []


class MockClock:
	extends ClockPort

	var _tick: int = 0

	func now_iso() -> String:
		_tick += 1
		return "2026-03-05T10:00:%02dZ" % _tick

	func now_msec() -> int:
		_tick += 1
		return 1767664800000 + _tick


func run() -> Dictionary:
	_reset()

	var project_store := MockProjectStore.new()
	project_store.project = _build_project("project-1", "world-1", false)
	var publish_store := InMemoryPublishStore.new().setup()
	var moderation := LocalModerationAdapter.new().setup("")
	var clock := MockClock.new()
	var policy := PublishingPolicy.new()
	var event_bus := DomainEventBus.new()
	var role_secret := "role-token-signing-key-32-bytes!!!".to_utf8_buffer()
	var role_guard := RoleTokenGuard.new().setup(clock, role_secret)

	var publish_service := PublishToFamilyLibraryService.new().setup(
		project_store,
		publish_store,
		moderation,
		clock,
		policy,
		event_bus,
		role_guard
	)
	var review_service := ReviewPublishRequestService.new().setup(
		publish_store,
		policy,
		clock,
		event_bus,
		role_guard
	)
	var unpublish_service := UnpublishWorldService.new().setup(
		publish_store,
		policy,
		clock,
		event_bus,
		role_guard
	)

	var kid := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	var parent := PlayerProfile.new("parent-1", PlayerProfile.Role.PARENT)

	# 1) Kid request should pass moderation, then require parent review.
	var kid_request := publish_service.execute("project-1", "world-1", kid)
	_assert_true(kid_request != null, "Kid publish request should be created")
	_assert_true(
		kid_request.state == PublishRequest.PublishState.PENDING_REVIEW,
		"Kid request should transition to pending review after moderation"
	)
	_assert_true(
		kid_request.visibility == PublishRequest.Visibility.PRIVATE,
		"Publish visibility should be private-by-default"
	)
	_assert_true(
		kid_request.moderation_results.size() >= 5,
		"Publish moderation should include text + visual + audio checks"
	)

	# 2) Parent approval requires valid parent role token.
	var denied := review_service.execute(kid_request.request_id, true, parent, "")
	_assert_null(denied, "Parent approval should fail without role token when guard enabled")

	parent.preferences["role_token"] = RoleToken.issue(parent, clock, role_secret, 60)
	var approved := review_service.execute(kid_request.request_id, true, parent, "")
	_assert_true(approved != null, "Parent approval should return updated request")
	_assert_true(
		approved.state == PublishRequest.PublishState.PUBLISHED,
		"Parent approval should publish request"
	)

	# 3) Parent unpublish flow should succeed.
	var unpublished := unpublish_service.execute(kid_request.request_id, parent, "maintenance")
	_assert_true(unpublished != null, "Unpublish should return updated request")
	_assert_true(
		unpublished.state == PublishRequest.PublishState.UNPUBLISHED,
		"Parent unpublish should transition request to unpublished"
	)

	# 4) Unsafe metadata should be rejected by moderation before review.
	project_store.project = _build_project("project-unsafe", "world-unsafe", true)
	var blocked := publish_service.execute("project-unsafe", "world-unsafe", kid)
	_assert_true(blocked != null, "Blocked publish request should still return request object")
	_assert_true(
		blocked.state == PublishRequest.PublishState.REJECTED,
		"Unsafe publish metadata should be rejected"
	)
	_assert_true(not blocked.rejection_reason.strip_edges().is_empty(), "Rejected request should include reason")

	return _build_result("PublishWorkflowServices")


func _build_project(project_id: String, world_id: String, unsafe: bool) -> Project:
	var project := Project.new(project_id, "Publish Test")
	var world_name := "zabij potwora" if unsafe else "Przyjazny swiat"
	var world := World.new(world_id, world_name)

	var rule := GameRule.new("rule-1", GameRule.RuleType.EVENT_TRIGGER)
	rule.display_name = "Start quest"
	world.add_rule(rule)

	var visual_node := SceneNode.new("node-visual", SceneNode.NodeType.OBJECT)
	visual_node.display_name = "Drzewko"
	visual_node.provenance = ProvenanceData.new(
		ProvenanceData.SourceType.AI_VISUAL,
		"safe-visual-v1",
		"audit-visual-1"
	)
	visual_node.properties["image_data"] = PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10, 0])
	world.add_node(visual_node)

	var audio_node := SceneNode.new("node-audio", SceneNode.NodeType.DECORATION)
	audio_node.display_name = "Spokojny dzwiek"
	audio_node.provenance = ProvenanceData.new(
		ProvenanceData.SourceType.AI_AUDIO,
		"safe-audio-v1",
		"audit-audio-1"
	)
	audio_node.properties["audio_description"] = "lagodny dzwiek tla"
	world.add_node(audio_node)

	project.add_world(world)
	return project
