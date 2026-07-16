## Contract: ParentalControlPolicy.resolve_for_session(has_stored, stored)
## is the single decision that picks the effective policy for a play session.
##
## The bug it closes: with the encrypted vault, a brand-new kid's load_policy
## returns deny_all() (combat off), NOT null — so the old `stored == null`
## branch never fired and default_for_first_run() (combat on) was dead code.
## Result: no enemies spawn on the real click path, score stays 0, the
## score-based win never fires.
##
## Correct three-way:
##   - nothing stored (brand-new kid)        -> default_for_first_run (combat ON)
##   - stored present + valid                -> honor it
##   - stored present but broken/wrong-type  -> deny_all (fail closed, NOT first-run)
class_name ParentalPolicyResolveForSessionContractTest
extends PortContractTest


func run() -> Dictionary:
	_reset()

	# Brand-new kid: no policy on disk -> friendly first-run default, combat ON.
	var fresh := ParentalControlPolicy.resolve_for_session(false, null)
	_assert_true(fresh != null, "resolve: fresh kid returns a policy")
	_assert_true(fresh.combat_enabled, "resolve: fresh kid has combat ENABLED (first-run default)")
	_assert_eq(fresh.combat_wave_cap, 5, "resolve: fresh kid inherits wave cap 5")

	# Stored + valid parent policy: honored verbatim.
	var custom := ParentalControlPolicy.new(
		45, 20, ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
		false, false, false, false, 0
	)
	var honored := ParentalControlPolicy.resolve_for_session(true, custom)
	_assert_true(honored != null, "resolve: stored policy returned")
	_assert_true(honored.equals(custom), "resolve: stored policy honored verbatim")
	_assert_true(not honored.combat_enabled, "resolve: parent's combat-off choice respected")

	# Stored present but unreadable (tamper/wrong-type) -> deny_all, NOT first-run.
	var tampered := ParentalControlPolicy.resolve_for_session(true, null)
	_assert_true(tampered != null, "resolve: broken-store path returns a policy")
	_assert_true(not tampered.combat_enabled, "resolve: broken store fails closed (combat OFF)")
	var deny := ParentalControlPolicy.deny_all()
	_assert_true(tampered.equals(deny), "resolve: broken store returns deny_all, not first-run")

	# Stored deny_all (present, decrypt-failed at the store) -> honored as-is.
	var stored_deny := ParentalControlPolicy.resolve_for_session(true, ParentalControlPolicy.deny_all())
	_assert_true(not stored_deny.combat_enabled, "resolve: stored deny_all stays deny (no first-run rescue)")

	return _build_result("ParentalControlPolicy.resolve_for_session")
