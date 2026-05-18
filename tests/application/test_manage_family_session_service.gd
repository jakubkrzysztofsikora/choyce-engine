extends ApplicationTest

const ManageFamilySessionServiceScn = preload("res://src/application/manage_family_session_service.gd")
const PlayerProfileScn = preload("res://src/domain/gameplay/player_profile.gd")
const ParentalControlPolicyScn = preload("res://src/domain/identity_safety/parental_control_policy.gd")
const FeatureFlagServiceScn = preload("res://src/application/feature_flag_service.gd")
const DeploymentConfigScn = preload("res://src/application/deployment_config.gd")

var _service: ManageFamilySessionServiceScn
var _gateway: MockGateway
var _policy_store: MockPolicyStore
var _flags: MockFlags
var _clock: MockClock
var _event_bus: MockEventBus

func run() -> Dictionary:
	_setup()
	test_create_invite_happy_path()
	test_create_invite_rejects_host_family_mismatch()
	test_create_invite_blocked_by_policy()
	test_create_invite_disabled_globally()
	test_create_invite_disabled_by_local_mode_defaults()
	test_join_session_happy_path()
	test_join_session_kid_requires_family_context()
	test_join_session_blocked_by_policy()
	test_close_session_happy_path()
	test_close_session_blocked_without_family_context()
	return _build_result("ManageFamilySessionService")

func _setup() -> void:
	_gateway = MockGateway.new()
	_policy_store = MockPolicyStore.new()
	_flags = MockFlags.new()
	_clock = MockClock.new()
	_event_bus = MockEventBus.new()
	
	_service = ManageFamilySessionServiceScn.new().setup(
		_gateway,
		_policy_store,
		_flags,
		_clock,
		_event_bus
	)

func test_create_invite_happy_path() -> void:
	var kid = PlayerProfileScn.new("kid_1", PlayerProfileScn.Role.KID)
	kid.preferences["family_id"] = "family_A"
	var family = "family_A"
	
	# Configure mocks
	_flags.enable("online_family_sessions", true)
	_policy_store.allow_sharing(family, true)
	
	var result = _service.create_invite(family, kid, "world_1", 30)
	
	_assert_true(result.get("ok", false), "Invite created successfully")
	_assert_eq(result.get("invite_code", ""), "INVITE-123", "Invite code returned")
	# Gateway called check impl later

func test_create_invite_rejects_host_family_mismatch() -> void:
	var kid = PlayerProfileScn.new("kid_mismatch", PlayerProfileScn.Role.KID)
	kid.preferences["family_id"] = "family_real"
	_flags.enable("online_family_sessions", true)
	_policy_store.allow_sharing("family_claimed", true)

	var result = _service.create_invite("family_claimed", kid, "world_mismatch")
	_assert_false(result.get("ok", true), "Host family mismatch is rejected")
	_assert_eq(result.get("error", ""), "Host family mismatch", "Correct mismatch error")

func test_create_invite_blocked_by_policy() -> void:
	var kid = PlayerProfileScn.new("kid_2", PlayerProfileScn.Role.KID)
	kid.preferences["family_id"] = "family_B"
	var family = "family_B"
	
	_flags.enable("online_family_sessions", true)
	_policy_store.allow_sharing(family, false) # Blocked!
	
	var result = _service.create_invite(family, kid, "world_2")
	_assert_false(result.get("ok", true), "Invite blocked by policy")
	_assert_eq(result.get("error", ""), "Sharing not allowed by parental policy", "Correct error message")

func test_create_invite_disabled_globally() -> void:
	var parent = PlayerProfileScn.new("parent_1", PlayerProfileScn.Role.PARENT)
	var family = "family_C"
	
	_flags.enable("online_family_sessions", false) # Disabled globally
	
	var result = _service.create_invite(family, parent, "world_3")
	_assert_false(result.get("ok", true), "Invite blocked by global flag")
	_assert_eq(result.get("error", ""), "Online sessions disabled by deployment policy", "Correct error message")


func test_create_invite_disabled_by_local_mode_defaults() -> void:
	var parent = PlayerProfileScn.new("parent_local_mode", PlayerProfileScn.Role.PARENT)
	var local_flags := FeatureFlagServiceScn.new(
		DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
	)
	var local_mode_service = ManageFamilySessionServiceScn.new().setup(
		_gateway,
		_policy_store,
		local_flags,
		_clock,
		_event_bus
	)

	var result = local_mode_service.create_invite("family_local_mode", parent, "world_local_mode")
	_assert_false(result.get("ok", true), "LOCAL_ONLY defaults disable online family sessions")
	_assert_eq(result.get("error", ""), "Online sessions disabled by deployment policy", "Correct error message")


func test_join_session_happy_path() -> void:
	var kid = PlayerProfileScn.new("kid_3", PlayerProfileScn.Role.KID)
	kid.preferences["family_id"] = "family_join_ok"
	_flags.enable("online_family_sessions", true)
	_policy_store.allow_sharing("family_join_ok", true)
	
	var result = _service.join_session("INVITE-ABC", kid)
	_assert_true(result.get("ok", false), "Joined session successfully")


func test_join_session_kid_requires_family_context() -> void:
	var kid = PlayerProfileScn.new("kid_no_family", PlayerProfileScn.Role.KID)
	_flags.enable("online_family_sessions", true)

	var result = _service.join_session("INVITE-NO-FAMILY", kid)
	_assert_false(result.get("ok", true), "Kid join requires family context")
	_assert_eq(result.get("error", ""), "Family context required for join", "Correct error message")


func test_join_session_blocked_by_policy() -> void:
	var kid = PlayerProfileScn.new("kid_policy_block", PlayerProfileScn.Role.KID)
	kid.preferences["family_id"] = "family_join_blocked"
	_flags.enable("online_family_sessions", true)
	_policy_store.allow_sharing("family_join_blocked", false)

	var result = _service.join_session("INVITE-BLOCKED", kid)
	_assert_false(result.get("ok", true), "Kid join blocked by parental policy")
	_assert_eq(result.get("error", ""), "Sharing not allowed by parental policy", "Correct error message")


func test_close_session_happy_path() -> void:
	var parent = PlayerProfileScn.new("parent_close", PlayerProfileScn.Role.PARENT)
	parent.preferences["family_id"] = "family_close_ok"
	_flags.enable("online_family_sessions", true)

	var closed = _service.close_session("sess_1", parent, "done")
	_assert_true(closed, "Parent can close family session with valid family context")
	_assert_eq(_gateway.last_close_payload.get("actor_role", ""), "parent", "Close payload carries actor role")


func test_close_session_blocked_without_family_context() -> void:
	var parent = PlayerProfileScn.new("parent_close_no_family", PlayerProfileScn.Role.PARENT)
	_flags.enable("online_family_sessions", true)

	var closed = _service.close_session("sess_2", parent, "done")
	_assert_false(closed, "Close session requires actor family context")

# =============================================================================
# Mocks
# =============================================================================

class MockGateway extends FamilySessionGatewayPort:
	var last_close_payload: Dictionary = {}

	func create_invite(payload: Dictionary) -> Dictionary:
		return {"ok": true, "invite_code": "INVITE-123", "id": "sess_001"}
	func join_session(payload: Dictionary) -> Dictionary:
		return {"ok": true, "session_id": "sess_001"}
	func close_session(payload: Dictionary) -> bool:
		last_close_payload = payload
		return true

class MockPolicyStore extends ParentalPolicyStorePort:
	var overrides = {} # family_id -> bool (sharing_allowed)
	
	func allow_sharing(family_id: String, allowed: bool) -> void:
		overrides[family_id] = allowed
		
	func load_policy(parent_id: String) -> ParentalControlPolicy:
		if not (parent_id in overrides):
			return null
		var p = ParentalControlPolicy.new()
		p.sharing_allowed = overrides[parent_id]
		return p

class MockFlags extends FeatureFlagService:
	var flags = {}
	func enable(key: String, val: bool) -> void:
		flags[key] = val
	func is_enabled(key: String) -> bool:
		return flags.get(key, false)

class MockClock extends ClockPort:
	func now_iso() -> String: return "2026-03-05T12:00:00Z"
	func now_msec() -> int: return 1000000

class MockEventBus extends DomainEventBus:
	func emit(event: DomainEvent) -> void:
		pass
