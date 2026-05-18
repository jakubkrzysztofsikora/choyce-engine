## Simple token-bucket rate limiter for AI requests.
## Tracks per-profile request timestamps in a sliding window.
class_name AIRateLimiter
extends RefCounted

var _max_requests_per_minute: int = 30
var _window_ms: int = 60000
var _profiles: Dictionary = {}


func setup(max_requests_per_minute: int = 30) -> AIRateLimiter:
	_max_requests_per_minute = max(max_requests_per_minute, 1)
	_window_ms = 60000
	_profiles.clear()
	return self


## Returns true if the profile is allowed to make a request right now.
func can_request(profile_id: String) -> bool:
	var now := Time.get_ticks_msec()
	var timestamps: Array = _profiles.get(profile_id, [])
	var cutoff := now - _window_ms
	var valid_count := 0
	for ts in timestamps:
		if ts is int and ts >= cutoff:
			valid_count += 1
	return valid_count < _max_requests_per_minute


## Records a new request timestamp for the profile.
func record_request(profile_id: String) -> void:
	var now := Time.get_ticks_msec()
	var timestamps: Array = _profiles.get(profile_id, [])
	var cutoff := now - _window_ms
	var pruned: Array = []
	for ts in timestamps:
		if ts is int and ts >= cutoff:
			pruned.append(ts)
	pruned.append(now)
	_profiles[profile_id] = pruned
