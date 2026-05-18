extends ApplicationTest

const CreateProjectServiceScn = preload("res://src/application/create_project_service.gd")
const RequestAICreationHelpServiceScn = preload("res://src/application/request_ai_creation_help_service.gd")
const OfflineAutosaveServiceScn = preload("res://src/application/offline_autosave_service.gd")
const PublishToFamilyLibraryServiceScn = preload("res://src/application/publish_to_family_library_service.gd")
const EventSourcedActionLogScn = preload("res://src/application/event_sourced_action_log.gd")
const FilesystemProjectStoreScn = preload("res://src/adapters/outbound/filesystem_project_store.gd")

# Domain & Shared
const PlayerProfileScn = preload("res://src/domain/gameplay/player_profile.gd")
const ProjectScn = preload("res://src/domain/world_authoring/project.gd")
const ToolInvocationScn = preload("res://src/domain/shared/tool_invocation.gd")
const PromptEnvelopeScn = preload("res://src/domain/shared/prompt_envelope.gd")
const AIAssistantActionScn = preload("res://src/domain/ai_orchestration/ai_assistant_action.gd")
const ModerationResultScn = preload("res://src/domain/shared/moderation_result.gd")
const AgeBandScn = preload("res://src/domain/shared/age_band.gd")

var _temp_dir: String = "user://test_e2e_mvp"
var _clock: MockClock
var _event_bus: MockEventBus
var _store: FilesystemProjectStoreScn
var _log_service: EventSourcedActionLogScn

# Services
var _create_service: CreateProjectServiceScn
var _ai_service: RequestAICreationHelpServiceScn
var _autosave_service: OfflineAutosaveServiceScn
var _publish_service: PublishToFamilyLibraryServiceScn

func run() -> Dictionary:
	_cleanup()
	_setup()
	
	test_kid_creation_flow_happy_path()
	
	_cleanup()
	return _build_result("E2E_MVP_Flows")

func _setup() -> void:
	_clock = MockClock.new()
	_event_bus = MockEventBus.new()
	_store = FilesystemProjectStoreScn.new().setup(_temp_dir)
	_log_service = EventSourcedActionLogScn.new()

	_create_service = CreateProjectServiceScn.new().setup(_store, _clock)
	
	var mock_llm = MockLLM.new()
	var mock_mod = MockModeration.new()
	var mock_loc = MockLocalization.new()
	var mock_gateway = MockToolGateway.new()
	
	_ai_service = RequestAICreationHelpServiceScn.new().setup(
		mock_llm,
		mock_mod,
		_clock,
		mock_loc,
		_event_bus,
		mock_gateway,
		null, # registry
		null, # failsafe
		null, # parental policy
		null, # language policy
		null  # prompt templates
	)
	
	var mock_consent = MockConsent.new()
	_autosave_service = OfflineAutosaveServiceScn.new().setup(
		_store,
		_clock,
		mock_consent
	)
	
	var mock_pub_store = MockPublishStore.new()
	var mock_policy = MockPublishPolicy.new()
	
	_publish_service = PublishToFamilyLibraryServiceScn.new().setup(
		_store,
		mock_pub_store,
		mock_mod,
		_clock,
		mock_policy,
		_event_bus
	)

func _cleanup() -> void:
	# Manual cleanup if needed, but unique temp dir per run (or standard) is better.
	# Here we just use the fixed one.
	pass

func test_kid_creation_flow_happy_path() -> void:
	# 1. Identity Setup
	var kid_profile = PlayerProfileScn.new("kid_1", PlayerProfileScn.Role.KID)
	
	# 2. CREATE PROJECT
	var project = _create_service.execute("starter_island", kid_profile)
	_assert_not_null(project, "Project created successfully")
	_assert_eq(project.owner_profile_id, "kid_1", "Owner is correct")
	
	# 3. AI ASSIST (Add a Tree)
	# Mock LLM is configured to return a tool call for "add_tree" when prompted.
	var action = _ai_service.execute("session_1", "add a tree", kid_profile)
	
	_assert_not_null(action, "AI Action returned")
	_assert_eq(action.status, int(AIAssistantActionScn.ActionStatus.APPLIED), "AI Action completed (simulated)")
	
	# Verify that events were emitted
	_assert_true(_event_bus.has_event("AIAssistanceRequested"), "Request submitted event")
	_assert_true(_event_bus.has_event("AIAssistanceApplied"), "Assistance applied event")
	
	# 4. AUTOSAVE
	# Trigger autosave schedule
	_clock.advance(5000) # 5 seconds later
	var scheduled = _autosave_service.maybe_schedule(project, kid_profile)
	_assert_true(scheduled, "Autosave scheduled")
	
	# Process pending
	var saved_count = _autosave_service.process_pending()
	_assert_eq(saved_count, 1, "Project saved to disk")
	
	# Verify persistence (Reload)
	var loaded_project = _store.load_project(project.project_id)
	_assert_not_null(loaded_project, "Project persisted and reloaded")
	
	# 5. PUBLISH
	var request = _publish_service.execute(project.project_id, project.worlds[0].world_id, kid_profile)
	_assert_not_null(request, "Publish request created")
	var pending_review_state = 2 # PublishState.PENDING_REVIEW
	if "PENDING_REVIEW" in PublishRequest.PublishState:
		pending_review_state = PublishRequest.PublishState.PENDING_REVIEW
	
	_assert_eq(request.state, pending_review_state, "Status is PENDING_REVIEW") # Pending Review
	
	# Verify moderation check happened (implied by success return in happy path)
	_assert_true(_event_bus.has_event("PublishRequestSubmitted"), "Publish event emitted")


# =============================================================================
# Mocks
# =============================================================================

class MockClock extends ClockPort:
	var _time: int = 1000000
	func now_msec() -> int: return _time
	func now_iso() -> String: return Time.get_datetime_string_from_system() # simplified
	func advance(ms: int) -> void: _time += ms

class MockEventBus extends DomainEventBus:
	var events: Array = []
	func emit(event: DomainEvent) -> void:
		events.append(event)
	func has_event(name: String) -> bool:
		for e in events:
			if e.event_type == name: return true
		return false

class MockLLM extends LLMPort:
	func complete(envelope: PromptEnvelope) -> String:
		return "This action adds a tree."
	func complete_with_tools(envelope: PromptEnvelope) -> Array[ToolInvocation]:
		# Return a valid ToolInvocation for "scene_edit"
		# Use untyped dictionary or typed if possible.
		# ToolInvocation is a class_name, we can instantiate it.
		var inv = ToolInvocation.new("scene_edit", {"operation": "add", "type": "tree"}, "inv_123")
		var arr: Array[ToolInvocation] = []
		arr.append(inv)
		return arr

class MockModeration extends ModerationPort:
	func check_text(text: String, age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS)
	func check_image(data: PackedByteArray, age_band: AgeBand) -> ModerationResult:
		return ModerationResult.new(ModerationResult.Verdict.PASS)

class MockLocalization extends LocalizationPolicyPort:
	func resolve_locale(profile: PlayerProfile) -> String:
		return "pl-PL"

class MockToolGateway extends ToolExecutionGateway:
	func execute(invocation: ToolInvocation, context: Dictionary = {}) -> Dictionary:
		# Simulate success
		return {"ok": true, "result": "Tree added", "undo_token": {"op": "add_tree"}}

class MockConsent extends IdentityConsentPort:
	func has_consent(profile_id: String, purpose: String) -> bool:
		return true

class MockPublishStore extends PublishStorePort:
	func save_request(req) -> bool: return true
	func get_request(id) -> Resource: return null

class MockPublishPolicy extends PublishingPolicy:
	func can_request_publish(profile: PlayerProfile) -> bool: return true
	func requires_approval(profile: PlayerProfile) -> bool: return true
