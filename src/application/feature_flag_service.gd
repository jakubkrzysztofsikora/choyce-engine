class_name FeatureFlagService
extends RefCounted

## Service managing feature availability across deployment modes and runtime overrides.
## Decouples application code from deployment specifics.
##
## Hexagonal: application layer — no adapter imports allowed.
## Call setup(env) before querying. Querying pre-setup emits one push_warning and
## returns base-config behavior (no overrides applied).

signal feature_changed(feature_key: String, enabled: bool)

const ENV_VAR_OVERRIDES := "CHOYCE_FEATURE_OVERRIDES"

var _config: DeploymentConfig
var _env: EnvironmentPort
var _overrides: Dictionary = {}
var _setup_called: bool = false
var _pre_setup_warned: bool = false

func _init(config: DeploymentConfig = null) -> void:
	if config:
		_config = config
	else:
		_config = DeploymentConfig.new()
	# _overrides start empty; no env loading here.
	# setup(env) is the ONLY place that loads env overrides.

## Dependency-injection entry point. Call after _init() to supply the port.
## Returns self for chaining: FeatureFlagService.new(config).setup(env_port)
func setup(env: EnvironmentPort) -> FeatureFlagService:
	if env == null:
		push_error("FeatureFlagService.setup() called with null EnvironmentPort — setup rejected")
		return self
	_env = env
	_setup_called = true
	# Load overrides from the injected port (replaces any stale state).
	_overrides.clear()
	_load_environment_overrides()
	return self

func _load_environment_overrides() -> void:
	# _env must be non-null; callers must guard.
	var overrides_str := _env.get_env(ENV_VAR_OVERRIDES, "")
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
## If setup() has not been called, emits push_warning ONCE and returns base-config behavior.
func is_enabled(feature_key: String) -> bool:
	if not _setup_called and not _pre_setup_warned:
		push_warning(
			"FeatureFlagService.is_enabled() called before setup(env) — " +
			"no env overrides applied; returning base-config values"
		)
		_pre_setup_warned = true
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
