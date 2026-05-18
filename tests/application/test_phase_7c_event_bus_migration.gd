## Regression test: Phase 7c — signal → DomainEventBus migration
## Verifies that QuestLog and OnboardingService publish domain events through
## DomainEventBus instead of Godot signals, and that fake subscribers receive
## the correct events end-to-end.
class_name TestPhase7cEventBusMigration
extends ApplicationTest


# ---------------------------------------------------------------------------
# Fake subscriber collector
# ---------------------------------------------------------------------------
class EventCollector:
	extends RefCounted

	var events: Array = []

	func on_event(event: DomainEvent) -> void:
		events.append(event)

	func first_of_type(type: String) -> DomainEvent:
		for e in events:
			if e.event_type == type:
				return e
		return null


# ---------------------------------------------------------------------------
# run()
# ---------------------------------------------------------------------------
func run() -> Dictionary:
	_test_quest_log_emits_no_godot_signals()
	_test_quest_log_progress_fires_quest_progressed_event()
	_test_quest_log_completion_fires_quest_completed_event()
	_test_quest_log_claim_fires_quest_claimed_event()
	_test_quest_log_active_quest_fires_active_quest_changed_event()
	_test_onboarding_emits_no_godot_signals()
	_test_onboarding_start_fires_step_changed_event()
	_test_onboarding_record_action_fires_step_completed_and_transition()
	_test_onboarding_finish_fires_onboarding_finished_event()
	_test_quest_log_without_event_bus_does_not_crash()
	_test_onboarding_without_event_bus_does_not_crash()
	return _build_result("Phase7cEventBusMigration")


# ---------------------------------------------------------------------------
# QuestLog tests
# ---------------------------------------------------------------------------

func _test_quest_log_emits_no_godot_signals() -> void:
	var ql := QuestLog.new()
	# Must not have any Godot signal declarations (Phase 7c MUST criterion).
	_assert_false(
		ql.has_signal("quest_progressed"),
		"QuestLog must not declare Godot signal quest_progressed"
	)
	_assert_false(
		ql.has_signal("quest_completed"),
		"QuestLog must not declare Godot signal quest_completed"
	)
	_assert_false(
		ql.has_signal("quest_claimed"),
		"QuestLog must not declare Godot signal quest_claimed"
	)
	_assert_false(
		ql.has_signal("active_quest_changed"),
		"QuestLog must not declare Godot signal active_quest_changed"
	)


func _test_quest_log_progress_fires_quest_progressed_event() -> void:
	var bus := DomainEventBus.new()
	var collector := EventCollector.new()
	bus.subscribe("QuestProgressed", Callable(collector, "on_event"))

	var ql := QuestLog.new()
	ql.setup(bus, "actor-1")
	var quest := Quest.new("q1")
	quest.status = Quest.Status.ACTIVE
	quest.target_count = 3
	ql.add_quest(quest)

	ql.progress_quest("q1", 1)

	var event = collector.first_of_type("QuestProgressed")
	_assert_not_null(event, "QuestProgressed event must be published via event_bus")
	_assert_true(event is QuestProgressedEvent, "Event must be QuestProgressedEvent instance")
	if event != null:
		_assert_eq(event.quest_id, "q1", "QuestProgressed.quest_id must match")
		_assert_eq(event.current_count, 1, "QuestProgressed.current_count must be 1")
		_assert_eq(event.target_count, 3, "QuestProgressed.target_count must be 3")


func _test_quest_log_completion_fires_quest_completed_event() -> void:
	var bus := DomainEventBus.new()
	var collector := EventCollector.new()
	bus.subscribe("QuestCompleted", Callable(collector, "on_event"))

	var ql := QuestLog.new()
	ql.setup(bus, "actor-1")
	var quest := Quest.new("q2")
	quest.status = Quest.Status.ACTIVE
	quest.target_count = 1
	ql.add_quest(quest)

	ql.progress_quest("q2", 1)

	var event = collector.first_of_type("QuestCompleted")
	_assert_not_null(event, "QuestCompleted event must be published when quest crosses threshold")
	_assert_true(event is QuestCompletedEvent, "Event must be QuestCompletedEvent instance")
	if event != null:
		_assert_eq(event.quest_id, "q2", "QuestCompleted.quest_id must match")


func _test_quest_log_claim_fires_quest_claimed_event() -> void:
	var bus := DomainEventBus.new()
	var collector := EventCollector.new()
	bus.subscribe("QuestClaimed", Callable(collector, "on_event"))

	var ql := QuestLog.new()
	ql.setup(bus, "actor-1")
	var quest := Quest.new("q3")
	quest.status = Quest.Status.COMPLETED
	quest.reward_score = 50
	quest.reward_unlocks = ["area-A"]
	ql.add_quest(quest)

	var claimed = ql.claim_quest("q3")
	_assert_true(claimed, "claim_quest should return true for COMPLETED quest")

	var event = collector.first_of_type("QuestClaimed")
	_assert_not_null(event, "QuestClaimed event must be published via event_bus")
	_assert_true(event is QuestClaimedEvent, "Event must be QuestClaimedEvent instance")
	if event != null:
		_assert_eq(event.quest_id, "q3", "QuestClaimed.quest_id must match")
		_assert_eq(event.reward_score, 50, "QuestClaimed.reward_score must match")


func _test_quest_log_active_quest_fires_active_quest_changed_event() -> void:
	var bus := DomainEventBus.new()
	var collector := EventCollector.new()
	bus.subscribe("ActiveQuestChanged", Callable(collector, "on_event"))

	var ql := QuestLog.new()
	ql.setup(bus, "actor-1")
	var quest := Quest.new("q4")
	quest.status = Quest.Status.LOCKED
	ql.add_quest(quest)

	var result = ql.set_active_quest("q4")
	_assert_true(result, "set_active_quest must return true for existing quest")

	var event = collector.first_of_type("ActiveQuestChanged")
	_assert_not_null(event, "ActiveQuestChanged event must be published via event_bus")
	_assert_true(event is ActiveQuestChangedEvent, "Event must be ActiveQuestChangedEvent instance")
	if event != null:
		_assert_eq(event.quest_id, "q4", "ActiveQuestChanged.quest_id must match")


# ---------------------------------------------------------------------------
# OnboardingService tests
# ---------------------------------------------------------------------------

func _test_onboarding_emits_no_godot_signals() -> void:
	var svc := OnboardingService.new()
	_assert_false(
		svc.has_signal("step_changed"),
		"OnboardingService must not declare Godot signal step_changed"
	)
	_assert_false(
		svc.has_signal("step_completed"),
		"OnboardingService must not declare Godot signal step_completed"
	)
	_assert_false(
		svc.has_signal("onboarding_finished"),
		"OnboardingService must not declare Godot signal onboarding_finished"
	)


func _test_onboarding_start_fires_step_changed_event() -> void:
	var bus := DomainEventBus.new()
	var collector := EventCollector.new()
	bus.subscribe("OnboardingStepChanged", Callable(collector, "on_event"))

	var svc := OnboardingService.new()
	svc.setup(bus)
	var profile := PlayerProfile.new("kid-1", PlayerProfile.Role.KID)
	svc.start_onboarding(profile)

	var event = collector.first_of_type("OnboardingStepChanged")
	_assert_not_null(event, "OnboardingStepChanged event must be published on start_onboarding")
	_assert_true(event is OnboardingStepChangedEvent, "Event must be OnboardingStepChangedEvent instance")
	if event != null:
		_assert_eq(event.step_id, OnboardingService.STEP_WELCOME, "step_id must be STEP_WELCOME on start")
		_assert_eq(event.instruction_key, "onboarding.welcome", "instruction_key must be onboarding.welcome")


func _test_onboarding_record_action_fires_step_completed_and_transition() -> void:
	var bus := DomainEventBus.new()
	var collector := EventCollector.new()
	bus.subscribe("OnboardingStepCompleted", Callable(collector, "on_event"))
	bus.subscribe("OnboardingStepChanged", Callable(collector, "on_event"))

	var svc := OnboardingService.new()
	svc.setup(bus)
	var profile := PlayerProfile.new("kid-2", PlayerProfile.Role.KID)
	svc.start_onboarding(profile)
	collector.events.clear()  # clear start event

	# Acknowledge welcome → transition to STEP_PLACE_FIRST
	svc.acknowledge_welcome()

	var step_changed = collector.first_of_type("OnboardingStepChanged")
	_assert_not_null(step_changed, "OnboardingStepChanged must fire after acknowledge_welcome")
	if step_changed != null:
		_assert_eq(step_changed.step_id, OnboardingService.STEP_PLACE_FIRST, "step_id must advance to STEP_PLACE_FIRST")

	collector.events.clear()

	# record_action("place") → completes STEP_PLACE_FIRST, transitions to STEP_PAINT_FIRST
	svc.record_action("place")

	var step_completed = collector.first_of_type("OnboardingStepCompleted")
	_assert_not_null(step_completed, "OnboardingStepCompleted must fire on record_action")
	_assert_true(step_completed is OnboardingStepCompletedEvent, "Must be OnboardingStepCompletedEvent")

	var next_step = collector.first_of_type("OnboardingStepChanged")
	_assert_not_null(next_step, "OnboardingStepChanged must fire after step completion")
	if next_step != null:
		_assert_eq(next_step.step_id, OnboardingService.STEP_PAINT_FIRST, "step_id must advance to STEP_PAINT_FIRST")


func _test_onboarding_finish_fires_onboarding_finished_event() -> void:
	var bus := DomainEventBus.new()
	var collector := EventCollector.new()
	bus.subscribe("OnboardingFinished", Callable(collector, "on_event"))

	var svc := OnboardingService.new()
	svc.setup(bus)
	var profile := PlayerProfile.new("kid-3", PlayerProfile.Role.KID)
	svc.start_onboarding(profile)
	svc.acknowledge_welcome()
	svc.record_action("place")
	svc.record_action("paint")
	# Now at STEP_PLAY
	svc.record_action("play")

	var event = collector.first_of_type("OnboardingFinished")
	_assert_not_null(event, "OnboardingFinished event must be published when all steps done")
	_assert_true(event is OnboardingFinishedEvent, "Event must be OnboardingFinishedEvent instance")
	_assert_true(
		profile.preferences.get("onboarding_complete", false),
		"profile.preferences[onboarding_complete] must be true after finish"
	)


# ---------------------------------------------------------------------------
# Null-safety (no event_bus) tests
# ---------------------------------------------------------------------------

func _test_quest_log_without_event_bus_does_not_crash() -> void:
	var ql := QuestLog.new()
	# setup() not called — _event_bus is null
	var quest := Quest.new("q5")
	quest.status = Quest.Status.ACTIVE
	quest.target_count = 1
	ql.add_quest(quest)
	# Must not crash even without event_bus
	ql.progress_quest("q5", 1)
	ql.set_active_quest("q5")
	ql.claim_quest("q5")
	_assert_true(true, "QuestLog works without event_bus (null-safe)")


func _test_onboarding_without_event_bus_does_not_crash() -> void:
	var svc := OnboardingService.new()
	# setup() not called
	var profile := PlayerProfile.new("kid-x", PlayerProfile.Role.KID)
	svc.start_onboarding(profile)
	svc.acknowledge_welcome()
	svc.record_action("place")
	_assert_true(true, "OnboardingService works without event_bus (null-safe)")
