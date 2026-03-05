class_name FeatureFlagService
extends RefCounted

## Service managing feature availability across deployment modes and runtime overrides.
## Decouples application code from deployment specifics.

signal feature_changed(feature_key: String, enabled: bool)

var _config: DeploymentConfig
var _overrides: Dictionary = {}

func _init(config: DeploymentConfig = null) -> void:
    if config:
        _config = config
    else:
        _config = DeploymentConfig.new()

## Returns true if the feature is available.
## Checks overrides first, then deployment defaults.
func is_enabled(feature_key: String) -> bool:
    if _overrides.has(feature_key):
        return _overrides[feature_key]
    return _config.is_feature_enabled(feature_key)

## Sets a runtime override for a feature flag.
## Used for dev tools or remote config updates.
func set_override(feature_key: String, enabled: Variant) -> void:
    if enabled == null:
        _overrides.erase(feature_key)
    else:
        _overrides[feature_key] = bool(enabled)
    feature_changed.emit(feature_key, is_enabled(feature_key))

## Clears all runtime overrides.
func reset_overrides() -> void:
    var keys = _overrides.keys()
    _overrides.clear()
    for key in keys:
        feature_changed.emit(key, is_enabled(key))
