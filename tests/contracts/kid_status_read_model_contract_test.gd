## Contract test for KidStatusReadModel implementations.
class_name KidStatusReadModelContractTest
extends PortContractTest


func run() -> Dictionary:
	var impl = KidStatusReadModelAdapter.new()

	_assert_eq(impl.list_recent_projects("profile-1").size(), 0, "Initial state has no projects")

	# Simulate project creation
	var create_event = MockWorldEditedEvent.new("project-1", "My Game", "")
	impl.update_from_event(create_event)

	_assert_eq(impl.list_recent_projects("profile-1").size(), 1, "Should list created project")
	var status = impl.get_project_status("project-1", "profile-1")
	_assert_eq(status.get("title"), "My Game", "Should preserve project title")
	_assert_eq(status.get("progress_pct"), 0, "Initial progress is 0%")
	_assert_eq(status.get("session_count"), 0, "Initial session count is 0")

	# Simulate session completion
	var session_event = MockSessionProgressUpdatedEvent.new("project-1", 50, "2026-03-02T10:30:00Z")
	impl.update_from_event(session_event)

	status = impl.get_project_status("project-1", "profile-1")
	_assert_eq(status.get("progress_pct"), 50, "Should update progress percentage")
	_assert_eq(status.get("session_count"), 1, "Should increment session count")
	_assert_true(status.get("last_played") != "", "Should track last played timestamp")

	# Simulate collectible found
	var collectible_event = MockSessionProgressUpdatedEvent.new("project-1", 0, "", 1, 0)
	impl.update_from_event(collectible_event)

	status = impl.get_project_status("project-1", "profile-1")
	_assert_eq(status.get("collectibles_found"), 1, "Should count collectibles")

	# Simulate achievement unlocked
	var achievement_event = MockSessionProgressUpdatedEvent.new("project-1", 0, "", 0, 1)
	impl.update_from_event(achievement_event)

	status = impl.get_project_status("project-1", "profile-1")
	_assert_eq(status.get("achievements_earned"), 1, "Should count achievements")

	# Profile-isolation gate: profile-owned project should not leak to other profiles.
	var profile_owned := MockWorldEditedEvent.new("project-private", "Hidden", "", "kid-owner")
	impl.update_from_event(profile_owned)
	var leaked := impl.get_project_status("project-private", "kid-other")
	_assert_true(leaked.is_empty(), "Profile-isolated project should not be readable by other profile")

	# Data-minimization gate: ad-tech identifiers must never be exposed by read model payloads.
	impl._projects["project-adtech"] = {
		"project_id": "project-adtech",
		"profile_id": "profile-1",
		"title": "Sanitized",
		"progress_pct": 5,
		"last_played": "2026-03-02T11:00:00Z",
		"session_count": 1,
		"collectibles_found": 0,
		"achievements_earned": 0,
		"advertising_id": "ad-123",
		"device_ad_id": "gaid-xyz",
	}
	var minimized_status := impl.get_project_status("project-adtech", "profile-1")
	_assert_false(minimized_status.has("advertising_id"), "Status payload should remove advertising_id")
	_assert_false(minimized_status.has("device_ad_id"), "Status payload should remove ad-tech IDs")
	var minimized_rows := impl.list_recent_projects("profile-1")
	var found_row := false
	for row_variant in minimized_rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant
		if row.get("project_id", "") == "project-adtech":
			found_row = true
			_assert_false(row.has("advertising_id"), "Recent project row should remove ad-tech identifiers")
	_assert_true(found_row, "Ad-tech sanitization row should remain queryable")

	return _build_result("KidStatusReadModel")


# Mock domain events for testing
class MockWorldEditedEvent extends DomainEvent:
	var project_id: String
	var title: String

	func _init(
		p_project_id: String,
		p_title: String,
		p_timestamp: String,
		p_actor_id: String = ""
	) -> void:
		super._init("WorldEdited", p_actor_id, p_timestamp)
		project_id = p_project_id
		title = p_title


class MockSessionProgressUpdatedEvent extends DomainEvent:
	var project_id: String
	var progress_pct: int
	var collectibles_found: int
	var achievements_earned: int

	func _init(
		p_project_id: String,
		p_progress_pct: int = 0,
		p_timestamp: String = "",
		p_collectibles: int = 0,
		p_achievements: int = 0
	) -> void:
		super._init("SessionProgressUpdatedEvent", "", p_timestamp)
		project_id = p_project_id
		progress_pct = p_progress_pct
		collectibles_found = p_collectibles
		achievements_earned = p_achievements
