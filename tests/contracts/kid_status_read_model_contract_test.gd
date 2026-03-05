## Contract test for KidStatusReadModel implementations.
class_name KidStatusReadModelContractTest
extends PortContractTest


func run() -> Dictionary:
	var impl = KidStatusReadModelAdapter.new()

	_assert_eq(impl.list_recent_projects("profile-1").size(), 0, "Initial state has no projects")

	# Simulate project creation
	var create_event = ProjectCreatedEvent.new("project-1", "My Game", "")
	impl.update_from_event(create_event)

	_assert_eq(impl.list_recent_projects("profile-1").size(), 1, "Should list created project")
	var status = impl.get_project_status("project-1", "profile-1")
	_assert_eq(status.get("title"), "My Game", "Should preserve project title")
	_assert_eq(status.get("progress_pct"), 0, "Initial progress is 0%")
	_assert_eq(status.get("session_count"), 0, "Initial session count is 0")

	# Simulate session completion
	var session_event = SessionCompletedEvent.new("project-1", 50, "2026-03-02T10:30:00Z")
	impl.update_from_event(session_event)

	status = impl.get_project_status("project-1", "profile-1")
	_assert_eq(status.get("progress_pct"), 50, "Should update progress percentage")
	_assert_eq(status.get("session_count"), 1, "Should increment session count")
	_assert_true(status.get("last_played") != "", "Should track last played timestamp")

	# Simulate collectible found
	var collectible_event = CollectibleFoundEvent.new("project-1", "coin-1", 50.0, "")
	impl.update_from_event(collectible_event)

	status = impl.get_project_status("project-1", "profile-1")
	_assert_eq(status.get("collectibles_found"), 1, "Should count collectibles")

	# Simulate achievement unlocked
	var achievement_event = AchievementUnlockedEvent.new("project-1", "first-win", "")
	impl.update_from_event(achievement_event)

	status = impl.get_project_status("project-1", "profile-1")
	_assert_eq(status.get("achievements_earned"), 1, "Should count achievements")

	return _build_result("KidStatusReadModel")


# Mock domain events for testing
class ProjectCreatedEvent extends DomainEvent:
	var project_id: String
	var title: String

	func _init(p_project_id: String, p_title: String, p_timestamp: String) -> void:
		super._init("ProjectCreatedEvent", "", p_timestamp)
		project_id = p_project_id
		title = p_title


class SessionCompletedEvent extends DomainEvent:
	var project_id: String
	var progress_pct: int

	func _init(p_project_id: String, p_progress_pct: int, p_timestamp: String) -> void:
		super._init("SessionCompletedEvent", "", p_timestamp)
		project_id = p_project_id
		progress_pct = p_progress_pct


class CollectibleFoundEvent extends DomainEvent:
	var project_id: String
	var collectible_id: String
	var value: float

	func _init(p_project_id: String, p_id: String, p_value: float, p_timestamp: String) -> void:
		super._init("CollectibleFoundEvent", "", p_timestamp)
		project_id = p_project_id
		collectible_id = p_id
		value = p_value


class AchievementUnlockedEvent extends DomainEvent:
	var project_id: String
	var achievement_id: String

	func _init(p_project_id: String, p_achievement_id: String, p_timestamp: String) -> void:
		super._init("AchievementUnlockedEvent", "", p_timestamp)
		project_id = p_project_id
		achievement_id = p_achievement_id
