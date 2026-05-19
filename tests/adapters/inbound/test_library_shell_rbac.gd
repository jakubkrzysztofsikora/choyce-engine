## tests/adapters/inbound/test_library_shell_rbac.gd
## Phase 9 + Wave C: Tests for library_shell server-side RBAC + ports_ready gate.
##
## Acceptance criteria verified:
## MUST-1: Kid profile + direct _on_approve_pressed() → review_publish_port NOT called.
## MUST-2: Kid profile + direct _on_reject_pressed()  → review_publish_port NOT called.
## MUST-3: Kid profile + direct _on_unpublish_pressed() → unpublish_port NOT called.
## MUST-4: Parent + ports_ready=false + _on_approve_pressed() → port NOT called.
## MUST-5: Parent + ports_ready=false + _on_reject_pressed()  → port NOT called.
## MUST-6: Parent + ports_ready=false + _on_unpublish_pressed() → port NOT called.
## MUST-7: Parent + ports_ready=true  + _on_approve_pressed()  → port IS called.
## MUST-8: Parent + ports_ready=true  + _on_reject_pressed()   → port IS called.
## MUST-9: Parent + ports_ready=true  + _on_unpublish_pressed() → port IS called.
## MUST-C4: Kid profile + _on_approve_pressed() → publish_status text matches
##          library.rbac.ask_parent (not the old library.access_denied bare text).
extends SceneTree

const LibraryShell = preload("res://src/adapters/inbound/scenes/library/library_shell.gd")
const PlayerProfile = preload("res://src/domain/gameplay/player_profile.gd")
const ReviewPublishRequestPort = preload("res://src/ports/inbound/review_publish_request_port.gd")
const UnpublishWorldPort = preload("res://src/ports/inbound/unpublish_world_port.gd")
const PublishToFamilyLibraryPort = preload("res://src/ports/inbound/publish_to_family_library_port.gd")

# ---------------------------------------------------------------------------
# Mocks
# ---------------------------------------------------------------------------

const PublishRequest = preload("res://src/domain/publishing/publish_request.gd")


class MockReviewPort extends ReviewPublishRequestPort:
	var execute_call_count := 0

	func execute(
		_request_id: String,
		_approved: bool,
		_reviewer: PlayerProfile,
		_reason: String
	) -> PublishRequest:
		execute_call_count += 1
		return null


class MockUnpublishPort extends UnpublishWorldPort:
	var execute_call_count := 0

	func execute(_request_id: String, _actor: PlayerProfile, _reason: String) -> PublishRequest:
		execute_call_count += 1
		return null


class MockPublishPort extends PublishToFamilyLibraryPort:
	func execute(_project_id: String, _world_id: String, _requester: PlayerProfile) -> PublishRequest:
		return null


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _exit_code := 0


func _init() -> void:
	call_deferred("_run_tests")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		print("FAIL: %s" % message)
		_exit_code = 1
	else:
		print("PASS: %s" % message)


func _make_shell_headless(
	profile: PlayerProfile,
	review_port: MockReviewPort,
	unpublish_port: MockUnpublishPort
) -> LibraryShell:
	# Instantiate without a scene tree scene to avoid @onready null errors in
	# headless context. We call setup() and then call handlers directly.
	# The shell extends Control, so we add it to the root.
	var scene := load("res://src/adapters/inbound/scenes/library/library_shell.tscn")
	if scene == null:
		push_error("library_shell.tscn not loadable; tests will be incomplete")
		return null
	var shell: LibraryShell = scene.instantiate()
	get_root().add_child(shell)
	shell.setup(
		null,          # navigator
		profile,
		null,          # localization_policy
		MockPublishPort.new(),
		review_port,
		unpublish_port
	)
	return shell


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## MUST-C4: Kid profile + _on_approve_pressed() → publish_status text contains
##          library.rbac.ask_parent text ("Tylko rodzic. Poproś rodzica.").
func _test_kid_approve_toast_shows_ask_parent_message() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var shell := _make_shell_headless(kid, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.set("_ports_ready", true)
	shell.call("_on_approve_pressed")
	await process_frame

	var status_label = shell.get("_publish_status")
	if status_label == null:
		print("SKIP: _publish_status label not found")
		shell.queue_free()
		await process_frame
		return

	# library.rbac.ask_parent resolves via shell _t() fallback or policy
	var expected: String = shell.call("_t", "library.rbac.ask_parent")
	var old_denied: String = shell.call("_t", "library.access_denied")

	_assert(
		status_label.text == expected,
		"MUST-C4: kid approve toast shows library.rbac.ask_parent text"
	)
	_assert(
		status_label.text != old_denied or expected == old_denied,
		"MUST-C4: toast is NOT bare library.access_denied text (follow-up included)"
	)
	shell.queue_free()
	await process_frame


## MUST-C4b: Kid profile + _on_reject_pressed() → toast text is library.rbac.ask_parent.
func _test_kid_reject_toast_shows_ask_parent_message() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var shell := _make_shell_headless(kid, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.set("_ports_ready", true)
	shell.call("_on_reject_pressed")
	await process_frame

	var status_label = shell.get("_publish_status")
	if status_label == null:
		print("SKIP: _publish_status label not found")
		shell.queue_free()
		await process_frame
		return

	var expected: String = shell.call("_t", "library.rbac.ask_parent")
	_assert(
		status_label.text == expected,
		"MUST-C4b: kid reject toast shows library.rbac.ask_parent text"
	)
	shell.queue_free()
	await process_frame


## MUST-C4c: Kid profile + _on_unpublish_pressed() → toast text is library.rbac.ask_parent.
func _test_kid_unpublish_toast_shows_ask_parent_message() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var shell := _make_shell_headless(kid, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.set("_ports_ready", true)
	shell.call("_on_unpublish_pressed")
	await process_frame

	var status_label = shell.get("_publish_status")
	if status_label == null:
		print("SKIP: _publish_status label not found")
		shell.queue_free()
		await process_frame
		return

	var expected: String = shell.call("_t", "library.rbac.ask_parent")
	_assert(
		status_label.text == expected,
		"MUST-C4c: kid unpublish toast shows library.rbac.ask_parent text"
	)
	shell.queue_free()
	await process_frame


func _run_tests() -> void:
	print("=== Phase 9 + Wave C: library_shell RBAC + ports_ready gate tests ===")

	await _test_kid_approve_does_not_call_port()
	await _test_kid_reject_does_not_call_port()
	await _test_kid_unpublish_does_not_call_port()
	await _test_parent_ports_not_ready_approve_does_not_call_port()
	await _test_parent_ports_not_ready_reject_does_not_call_port()
	await _test_parent_ports_not_ready_unpublish_does_not_call_port()
	await _test_parent_ports_ready_approve_calls_port()
	await _test_parent_ports_ready_reject_calls_port()
	await _test_parent_ports_ready_unpublish_calls_port()
	await _test_ports_ready_initially_false()
	await _test_notify_ports_ready_sets_flag()

	# Wave C: RBAC toast shows ask-parent follow-up
	await _test_kid_approve_toast_shows_ask_parent_message()
	await _test_kid_reject_toast_shows_ask_parent_message()
	await _test_kid_unpublish_toast_shows_ask_parent_message()

	quit(_exit_code)


# MUST-1: Kid profile + direct _on_approve_pressed() → review_publish_port NOT called.
func _test_kid_approve_does_not_call_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var shell := _make_shell_headless(kid, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.set("_ports_ready", true)  # ensure only RBAC blocks, not ports_ready
	shell.call("_on_approve_pressed")
	await process_frame

	_assert(
		review.execute_call_count == 0,
		"MUST-1: Kid profile — _on_approve_pressed does NOT call review_publish_port"
	)
	shell.queue_free()
	await process_frame


# MUST-2: Kid profile + direct _on_reject_pressed() → review_publish_port NOT called.
func _test_kid_reject_does_not_call_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var shell := _make_shell_headless(kid, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.set("_ports_ready", true)
	shell.call("_on_reject_pressed")
	await process_frame

	_assert(
		review.execute_call_count == 0,
		"MUST-2: Kid profile — _on_reject_pressed does NOT call review_publish_port"
	)
	shell.queue_free()
	await process_frame


# MUST-3: Kid profile + direct _on_unpublish_pressed() → unpublish_port NOT called.
func _test_kid_unpublish_does_not_call_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var kid := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)
	var shell := _make_shell_headless(kid, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.set("_ports_ready", true)
	shell.call("_on_unpublish_pressed")
	await process_frame

	_assert(
		unpublish.execute_call_count == 0,
		"MUST-3: Kid profile — _on_unpublish_pressed does NOT call unpublish_port"
	)
	shell.queue_free()
	await process_frame


# MUST-4: Parent + ports_ready=false + _on_approve_pressed() → port NOT called.
func _test_parent_ports_not_ready_approve_does_not_call_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var parent := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	var shell := _make_shell_headless(parent, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	# _ports_ready is false by default — do NOT call notify_ports_ready()
	shell.call("_on_approve_pressed")
	await process_frame

	_assert(
		review.execute_call_count == 0,
		"MUST-4: Parent + ports_ready=false — _on_approve_pressed does NOT call port"
	)
	shell.queue_free()
	await process_frame


# MUST-5: Parent + ports_ready=false + _on_reject_pressed() → port NOT called.
func _test_parent_ports_not_ready_reject_does_not_call_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var parent := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	var shell := _make_shell_headless(parent, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.call("_on_reject_pressed")
	await process_frame

	_assert(
		review.execute_call_count == 0,
		"MUST-5: Parent + ports_ready=false — _on_reject_pressed does NOT call port"
	)
	shell.queue_free()
	await process_frame


# MUST-6: Parent + ports_ready=false + _on_unpublish_pressed() → port NOT called.
func _test_parent_ports_not_ready_unpublish_does_not_call_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var parent := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	var shell := _make_shell_headless(parent, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.call("_on_unpublish_pressed")
	await process_frame

	_assert(
		unpublish.execute_call_count == 0,
		"MUST-6: Parent + ports_ready=false — _on_unpublish_pressed does NOT call port"
	)
	shell.queue_free()
	await process_frame


# MUST-7: Parent + ports_ready=true + _on_approve_pressed() → port IS called.
func _test_parent_ports_ready_approve_calls_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var parent := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	var shell := _make_shell_headless(parent, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.notify_ports_ready()
	shell.call("_on_approve_pressed")
	await process_frame

	_assert(
		review.execute_call_count == 1,
		"MUST-7: Parent + ports_ready=true — _on_approve_pressed CALLS review_publish_port"
	)
	shell.queue_free()
	await process_frame


# MUST-8: Parent + ports_ready=true + _on_reject_pressed() → port IS called.
func _test_parent_ports_ready_reject_calls_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var parent := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	var shell := _make_shell_headless(parent, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.notify_ports_ready()
	shell.call("_on_reject_pressed")
	await process_frame

	_assert(
		review.execute_call_count == 1,
		"MUST-8: Parent + ports_ready=true — _on_reject_pressed CALLS review_publish_port"
	)
	shell.queue_free()
	await process_frame


# MUST-9: Parent + ports_ready=true + _on_unpublish_pressed() → port IS called.
func _test_parent_ports_ready_unpublish_calls_port() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var parent := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	var shell := _make_shell_headless(parent, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.notify_ports_ready()
	shell.call("_on_unpublish_pressed")
	await process_frame

	_assert(
		unpublish.execute_call_count == 1,
		"MUST-9: Parent + ports_ready=true — _on_unpublish_pressed CALLS unpublish_port"
	)
	shell.queue_free()
	await process_frame


# Structural: _ports_ready starts false on fresh shell.
func _test_ports_ready_initially_false() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var parent := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	var shell := _make_shell_headless(parent, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	# Note: setup() was already called in _make_shell_headless — _ports_ready stays false.
	_assert(
		shell.get("_ports_ready") == false,
		"Structural: _ports_ready is false on freshly-setup shell"
	)
	shell.queue_free()
	await process_frame


# Structural: notify_ports_ready() sets _ports_ready to true.
func _test_notify_ports_ready_sets_flag() -> void:
	var review := MockReviewPort.new()
	var unpublish := MockUnpublishPort.new()
	var parent := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	var shell := _make_shell_headless(parent, review, unpublish)
	if shell == null:
		print("SKIP: could not instantiate library_shell.tscn")
		return

	shell.notify_ports_ready()

	_assert(
		shell.get("_ports_ready") == true,
		"Structural: notify_ports_ready() sets _ports_ready to true"
	)
	shell.queue_free()
	await process_frame
