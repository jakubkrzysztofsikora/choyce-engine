## Entity representing a request to publish a world to the family library.
## Enforces private-by-default sharing, requires moderation checks to pass,
## and gates on parent approval before visibility changes.
##
## State machine:
##   DRAFT → MODERATION_PASSED → PENDING_REVIEW → APPROVED → PUBLISHED
##                                      ↓                        ↓
##                                  REJECTED ← ← ← ← ← ← UNPUBLISHED
##                                      ↓
##                                    DRAFT (revise)
class_name PublishRequest
extends RefCounted

enum PublishState {
	DRAFT,
	MODERATION_PASSED,
	PENDING_REVIEW,
	APPROVED,
	PUBLISHED,
	REJECTED,
	UNPUBLISHED,
}

enum Visibility { PRIVATE, FAMILY, CLASSROOM }

var request_id: String
var project_id: String
var world_id: String
var state: PublishState
var visibility: Visibility
var requester_id: String
var reviewer_id: String
var moderation_results: Array  # of ModerationResult
var rejection_reason: String
var created_at: String  # ISO 8601
var published_at: String  # ISO 8601
var unpublished_at: String  # ISO 8601
var revision_count: int


func _init(p_project_id: String = "", p_world_id: String = "") -> void:
	request_id = ""
	project_id = p_project_id
	world_id = p_world_id
	state = PublishState.DRAFT
	visibility = Visibility.PRIVATE
	requester_id = ""
	reviewer_id = ""
	moderation_results = []
	rejection_reason = ""
	created_at = ""
	published_at = ""
	unpublished_at = ""
	revision_count = 0


# --- Query methods ---

func all_moderation_passed() -> bool:
	if moderation_results.is_empty():
		return false
	return moderation_results.all(func(r): return not r.is_blocked())


func requires_parent_approval() -> bool:
	return state == PublishState.PENDING_REVIEW


func is_visible_to_family() -> bool:
	return state == PublishState.PUBLISHED and visibility != Visibility.PRIVATE


# --- State transitions (return false if transition is invalid) ---

func submit_for_review(reviewer: String) -> bool:
	if state != PublishState.MODERATION_PASSED:
		return false
	reviewer_id = reviewer
	state = PublishState.PENDING_REVIEW
	return true


func approve(p_reviewer_id: String) -> bool:
	if state != PublishState.PENDING_REVIEW:
		return false
	reviewer_id = p_reviewer_id
	rejection_reason = ""
	state = PublishState.APPROVED
	return true


func reject(p_reviewer_id: String, reason: String) -> bool:
	if state != PublishState.PENDING_REVIEW:
		return false
	reviewer_id = p_reviewer_id
	rejection_reason = reason
	state = PublishState.REJECTED
	return true


func publish(timestamp: String) -> bool:
	if state != PublishState.APPROVED:
		return false
	published_at = timestamp
	state = PublishState.PUBLISHED
	return true


func unpublish(timestamp: String) -> bool:
	if state != PublishState.PUBLISHED:
		return false
	unpublished_at = timestamp
	state = PublishState.UNPUBLISHED
	return true


func revise() -> bool:
	if state not in [PublishState.REJECTED, PublishState.UNPUBLISHED]:
		return false
	revision_count += 1
	rejection_reason = ""
	moderation_results = []
	state = PublishState.DRAFT
	return true


func set_visibility(new_visibility: Visibility) -> bool:
	# Visibility can only be changed before publishing or after unpublishing
	if state in [PublishState.PUBLISHED]:
		return false
	visibility = new_visibility
	return true
