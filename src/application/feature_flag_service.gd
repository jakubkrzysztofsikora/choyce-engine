class_name FeatureFlagService
extends RefCounted

## Service managing feature availability across deployment modes and runtime overrides.
## Decouples application code from deployment specifics.

signal feature_changed(feature_key: String, enabled: bool)

const ENV_VAR_OVERRIDES := "CHOYCE_FEATURE_OVERRIDES"

var _config: DeploymentConfig
var _overrides: Dictionary = {}

func _init(config: DeploymentConfig = null) -> void:
	if config:
		_config = config
	else:
		_config = DeploymentConfig.new()
	_load_environment_overrides()

func _load_environment_overrides() -> void:
	var overrides_str := OS.get_environment(ENV_VAR_OVERRIDES)
	if overrides_str.is_empty():
		return

	# Try parsing as JSON first.
	var json := JSON.new()
	var err := json.parse(overrides_str)
	if err == OK and json.data is Dictionary:
		for key in json.data:
			set_override(str(key), json.data[key])
		return

	# Fallback: comma-separated key=value parser.
	var pairs: Array = overrides_str.split(",")
	for pair_variant in pairs:
		var pair := str(pair_variant)
		var parts: Array = pair.split("=")
		if parts.size() != 2:
			continue
		var key := str(parts[0]).strip_edges()
		var val_str := str(parts[1]).strip_edges().to_lower()
		var val := val_str == "true" or val_str == "1"
		set_override(key, val)

## Returns true if the feature is available.
## Checks overrides first, then deployment defaults.
func is_enabled(feature_key: String) -> bool:
	if _config != null and _config.is_feature_hard_disabled(feature_key):
		return false
	if _overrides.has(feature_key):
		return bool(_overrides[feature_key])
	return _config.is_feature_enabled(feature_key)

## Sets a runtime override for a feature flag.
## Used for dev tools or remote config updates.
func set_override(feature_key: String, enabled: Variant) -> void:
	if enabled == null:
		_overrides.erase(feature_key)
		feature_changed.emit(feature_key, is_enabled(feature_key))
		return

	var requested := bool(enabled)
	if requested and _config != null and _config.is_feature_hard_disabled(feature_key):
		_overrides[feature_key] = false
	else:
		_overrides[feature_key] = requested

	feature_changed.emit(feature_key, is_enabled(feature_key))

## Clears all runtime overrides.
func reset_overrides() -> void:
	var keys: Array = _overrides.keys()
	_overrides.clear()
	for key_variant in keys:
		var key := str(key_variant)
		feature_changed.emit(key, is_enabled(key))
