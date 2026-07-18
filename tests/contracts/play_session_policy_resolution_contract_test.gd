## Integration proof for the release BLOCKER: on the REAL click path (encrypted
## vault, no autoplay) a brand-new kid must get combat ENABLED so enemies spawn
## and the score-based Adventure win can fire.
##
## Mirrors exactly the three lines PlayShell._resolve_policy_for_session runs
## against a live EncryptedParentalPolicyStore:
##   has_stored := store.has_policy(profile_id)
##   stored     := store.load_policy(profile_id)
##   policy     := ParentalControlPolicy.resolve_for_session(has_stored, stored)
##
## Regression it guards: the encrypted store returns deny_all() (combat off)
## for a missing file, and the old `stored == null` branch never fired, so
## default_for_first_run() (combat on) was dead and every fresh kid session
## spawned zero enemies.
class_name PlaySessionPolicyResolutionContractTest
extends PortContractTest

const TEST_ROOT := "user://contract_tests/play_session_policy_vault"


func run() -> Dictionary:
	_reset()
	_cleanup_user_path(TEST_ROOT)

	var storage := LocalEncryptedStorage.new().setup()
	var key := "0123456789ABCDEF0123456789ABCDEF".to_utf8_buffer()
	var store := EncryptedParentalPolicyStore.new().setup(storage, key, TEST_ROOT)

	# 1) Brand-new kid, nothing in the vault — the exact bug scenario.
	var fresh := _resolve(store, "local_kid_1")
	_assert_true(
		fresh.combat_enabled,
		"BLOCKER guard: fresh kid on encrypted vault must have combat ENABLED (enemies spawn)"
	)
	_assert_eq(fresh.combat_wave_cap, 5, "fresh kid inherits first-run wave cap 5")

	# 2) Parent later disables combat — that choice must be honored (not overridden by first-run).
	var combat_off := ParentalControlPolicy.new(
		60, 30, ParentalControlPolicy.AIAccessLevel.CREATIVE_ONLY,
		false, false, false, false, 0
	)
	_assert_true(store.save_policy("local_kid_1", combat_off), "save parent policy")
	var after := _resolve(store, "local_kid_1")
	_assert_true(
		not after.combat_enabled,
		"stored combat-off policy honored (parent choice wins over first-run default)"
	)

	# 3) Different kid, still fresh — independent of kid 1's stored policy.
	var other := _resolve(store, "local_kid_2")
	_assert_true(other.combat_enabled, "second fresh kid still gets combat on")

	_cleanup_user_path(TEST_ROOT)
	return _build_result("PlaySession policy resolution (encrypted vault)")


## The three lines PlayShell runs, verbatim.
func _resolve(store: EncryptedParentalPolicyStore, profile_id: String) -> ParentalControlPolicy:
	var has_stored := store.has_policy(profile_id)
	var stored := store.load_policy(profile_id)
	return ParentalControlPolicy.resolve_for_session(has_stored, stored)


func _cleanup_user_path(path: String) -> void:
	_remove_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _remove_dir_recursive_absolute(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_remove_dir_recursive_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
