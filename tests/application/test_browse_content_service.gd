extends ApplicationTest

const BrowseContentService = preload("res://src/application/browse_content_service.gd")
const PublishRequestScn = preload("res://src/domain/publishing/publish_request.gd")
const PlayerProfileScn = preload("res://src/domain/gameplay/player_profile.gd")
const TemplateLoaderScn = preload("res://src/application/template_loader.gd")
const PublishStorePortScn = preload("res://src/ports/outbound/publish_store_port.gd")
const ModerationResultScn = preload("res://src/domain/shared/moderation_result.gd")

var _service: BrowseContentService
var _publish_store: MockPublishStore
var _template_loader: TemplateLoaderScn
var _clock: MockClock

func run() -> Dictionary:
	_setup()
	test_list_templates()
	test_list_family_library()
	test_list_catalog_entries_filters()
	return _build_result("BrowseContentService")
	
func _setup() -> void:
	_publish_store = MockPublishStore.new()
	_clock = MockClock.new()
	_template_loader = TemplateLoaderScn.new().setup(MockProjectStore.new(), _clock)
	
	_service = BrowseContentService.new().setup(
		_publish_store,
		_template_loader,
		null
	)

func test_list_templates() -> void:
	var kid = PlayerProfileScn.new("kid_1")
	var list = _service.list_templates(kid)
	
	# Assert basics
	_assert_true(list.size() > 0, "Templates loaded")
	
	# Assert structure
	var entry = list[0]
	_assert_true(entry.has("id"), "Has ID")
	_assert_true(entry.has("title"), "Has Title")
	_assert_true(entry.has("safety_status"), "Template card exposes safety status")
	_assert_eq(entry.get("approval_status", ""), "approved", "Template card has approved curation status")

func test_list_family_library() -> void:
	var kid = PlayerProfileScn.new("kid_1")
	kid.preferences["family_id"] = "family_A"
	kid.preferences["classroom_id"] = "class_alpha"
	var parent = PlayerProfileScn.new("parent_1", PlayerProfileScn.Role.PARENT)
	parent.preferences["family_id"] = "family_A"
	var other_kid = PlayerProfileScn.new("kid_2")
	other_kid.preferences["family_id"] = "family_B"
	other_kid.preferences["classroom_id"] = "class_alpha"
	
	# Setup published content
	var p1 = _create_publish_request("private_1", kid.profile_id, PublishRequestScn.Visibility.PRIVATE, "family_A")
	var p2 = _create_publish_request("family_1", kid.profile_id, PublishRequestScn.Visibility.FAMILY, "family_A")
	var p3 = _create_publish_request("other_private", other_kid.profile_id, PublishRequestScn.Visibility.PRIVATE, "family_B")
	var p4 = _create_publish_request("draft_1", kid.profile_id, PublishRequestScn.Visibility.FAMILY, "family_A")
	p4.state = PublishRequestScn.PublishState.DRAFT # Not published yet!
	var p5 = _create_publish_request("family_other", other_kid.profile_id, PublishRequestScn.Visibility.FAMILY, "family_B")
	var p6 = _create_publish_request("classroom_shared", other_kid.profile_id, PublishRequestScn.Visibility.CLASSROOM, "family_B", "class_alpha")
	var p7 = _create_publish_request("unsafe_published", other_kid.profile_id, PublishRequestScn.Visibility.FAMILY, "family_A")
	p7.moderation_results = [ModerationResultScn.new(ModerationResultScn.Verdict.BLOCK, "unsafe")]
	
	_publish_store.requests = [p1, p2, p3, p4, p5, p6, p7]
	
	var kid_view = _service.list_family_library(kid)
	
	# Kid should see:
	# - Their own PRIVATE (p1)
	# - Their own FAMILY (p2)
	# - Classroom share for the same classroom (p6)
	# - NOT other family's FAMILY (p5)
	# - NOT other's PRIVATE (p3)
	# - NOT DRAFT (p4)
	# - NOT unsafe moderation blocked request (p7)
	
	_assert_eq(kid_view.size(), 3, "Kid sees correct count")
	_assert_true(p1 in kid_view, "Sees own private")
	_assert_true(p2 in kid_view, "Sees family shared")
	_assert_true(p6 in kid_view, "Sees same-classroom shared entry")
	_assert_false(p5 in kid_view, "Does not see other family's shared content")
	_assert_false(p3 in kid_view, "Does not see other private")
	_assert_false(p4 in kid_view, "Does not see draft")
	_assert_false(p7 in kid_view, "Does not see blocked moderation entries")
	
	# Other kid view
	var other_view = _service.list_family_library(other_kid)
	
	# Other Kid expects:
	# - Own family shared (p5)
	# - Their own private (p3)
	# - Classroom share (p6)
	# - NOT p2 (other family)
	# - NOT p1 (kid1's private)
	
	_assert_eq(other_view.size(), 3, "Other kid count")
	_assert_true(p5 in other_view, "Sees own family shared")
	_assert_true(p3 in other_view, "Sees own private")
	_assert_true(p6 in other_view, "Sees classroom shared")
	_assert_false(p2 in other_view, "Does not see other family shared")

	# Parent in family A should only see family A entries + own entries
	var parent_view = _service.list_family_library(parent)
	_assert_true(p2 in parent_view, "Parent sees family-A shared item")
	_assert_false(p5 in parent_view, "Parent does not see family-B shared item")
	_assert_false(p3 in parent_view, "Parent does not see other private item")


func test_list_catalog_entries_filters() -> void:
	var kid = PlayerProfileScn.new("kid_catalog")
	kid.preferences["family_id"] = "family_A"
	var req = _create_publish_request("catalog_req", "kid_catalog", PublishRequestScn.Visibility.FAMILY, "family_A")
	_publish_store.requests = [req]

	var all_entries = _service.list_catalog_entries(kid, {}, 50)
	_assert_true(all_entries.size() >= 2, "Catalog includes templates and family creations")

	var family_only = _service.list_catalog_entries(kid, {"entry_type": "family_creation"}, 50)
	_assert_eq(family_only.size(), 1, "Family-only filter isolates family creations")
	_assert_eq(family_only[0].get("approval_status", ""), "approved", "Published family entry is approval-complete")
	_assert_eq(family_only[0].get("safety_status", ""), "passed", "Published family entry carries safety metadata")


func _create_publish_request(
	id: String,
	requester: String,
	vis: int,
	family_id: String,
	classroom_id: String = ""
) -> PublishRequest:
	var r = PublishRequestScn.new("", "")
	r.request_id = id
	r.requester_id = requester
	r.family_id = family_id
	r.classroom_id = classroom_id
	r.visibility = vis
	r.state = PublishRequestScn.PublishState.PUBLISHED
	r.moderation_results = [ModerationResultScn.new(ModerationResultScn.Verdict.PASS, "")]
	return r

# =============================================================================
# Mocks
# =============================================================================

class MockPublishStore extends PublishStorePort:
	var requests: Array = []
	
	func list_published() -> Array:
		# Return all "potentially" published, logic filters state generally
		return requests

class MockProjectStore extends ProjectStorePort:
	func load_project(project_id: String) -> Project: return null

class MockClock extends ClockPort:
	func now_iso() -> String: return "2026-03-05T12:00:00Z"

class MockEventBus extends DomainEventBus:
	func emit(e) -> void: pass
