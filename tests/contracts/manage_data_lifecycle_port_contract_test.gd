## Contract test for ManageDataLifecyclePort via ManageDataLifecycleService.
##
## MUST-1  request_export() returns {ok: false} when lifecycle_port is null (unwired guard)
## MUST-2  request_delete() returns {ok: false} when lifecycle_port is null
## MUST-3  request_export() returns {ok: false} for kid profile (not authorized)
## MUST-4  request_delete() returns {ok: false} for kid profile (not authorized)
## MUST-5  request_export() returns {ok: false} when parent is null
## MUST-6  revoke_consent() returns false when lifecycle_port is null
## MUST-7  update_retention() returns false when lifecycle_port is null
class_name ManageDataLifecyclePortContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	# Build minimal stubs
	var svc_no_lifecycle := ManageDataLifecycleService.new().setup(null)

	var parent_profile := PlayerProfile.new("parent_1", PlayerProfile.Role.PARENT)
	parent_profile.preferences["managed_profiles"] = []  # empty = owns all
	var kid_profile := PlayerProfile.new("kid_1", PlayerProfile.Role.KID)

	# ── MUST-1: export with null lifecycle port ────────────────────────────────
	var export_result := svc_no_lifecycle.request_export(parent_profile, "kid_1")
	_assert_dictionary(export_result, "request_export() result")
	_assert_true(
		not bool(export_result.get("ok", true)),
		"MUST-1: request_export() must return ok:false when lifecycle_port is null"
	)

	# ── MUST-2: delete with null lifecycle port ────────────────────────────────
	var delete_result := svc_no_lifecycle.request_delete(parent_profile, "kid_1")
	_assert_dictionary(delete_result, "request_delete() result")
	_assert_true(
		not bool(delete_result.get("ok", true)),
		"MUST-2: request_delete() must return ok:false when lifecycle_port is null"
	)

	# ── MUST-3: export from kid profile (unauthorized) ─────────────────────────
	var export_kid := svc_no_lifecycle.request_export(kid_profile, "other_kid")
	_assert_true(
		not bool(export_kid.get("ok", true)),
		"MUST-3: request_export() must return ok:false for kid (non-parent) profile"
	)

	# ── MUST-4: delete from kid profile (unauthorized) ─────────────────────────
	var delete_kid := svc_no_lifecycle.request_delete(kid_profile, "other_kid")
	_assert_true(
		not bool(delete_kid.get("ok", true)),
		"MUST-4: request_delete() must return ok:false for kid (non-parent) profile"
	)

	# ── MUST-5: export with null parent ───────────────────────────────────────
	var export_null_parent := svc_no_lifecycle.request_export(null, "kid_1")
	_assert_dictionary(export_null_parent, "request_export(null parent) result")
	_assert_true(
		not bool(export_null_parent.get("ok", true)),
		"MUST-5: request_export() must return ok:false when parent is null"
	)

	# ── MUST-6: revoke_consent with null lifecycle port ────────────────────────
	var revoke_result := svc_no_lifecycle.revoke_consent(parent_profile, "kid_1", "cloud_sync")
	_assert_false(revoke_result, "MUST-6: revoke_consent() must return false when lifecycle_port is null")

	# ── MUST-7: update_retention with null lifecycle port ─────────────────────
	var retention_result := svc_no_lifecycle.update_retention(parent_profile, "kid_1", {"keep_days": 30})
	_assert_false(retention_result, "MUST-7: update_retention() must return false when lifecycle_port is null")

	return _build_result("ManageDataLifecyclePort")
