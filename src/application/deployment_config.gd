class_name DeploymentConfig
extends RefCounted

## Defines the runtime deployment mode and associated default feature flags.
## This configuration is determined at startup and is generally immutable during a session.

enum Mode {
	LOCAL_ONLY,     # Offline, single-device. No outbound network.
	FAMILY_CLOUD,   # Standard consumer mode with optional cloud features.
	CLASSROOM       # Managed educational environment with strict policy controls.
}

const ENV_VAR_MODE := "CHOYCE_DEPLOYMENT_MODE"

var mode: Mode
var features: Dictionary = {}
var _hard_disabled_features: Dictionary = {}

func _init(p_mode: Mode = Mode.FAMILY_CLOUD) -> void:
	mode = p_mode
	_apply_defaults()

## Detects the deployment mode from an EnvironmentPort.
## Pass an OSEnvironmentAdapter in production; pass a stub in tests.
static func from_environment(env: EnvironmentPort = null) -> DeploymentConfig:
	var _env: EnvironmentPort = env if env != null else OSEnvironmentAdapter.new()
	var mode_str := _env.get_env(ENV_VAR_MODE, "").strip_edges().to_lower()
	var selected_mode := _mode_from_string(mode_str)
	return DeploymentConfig.new(selected_mode)


static func _mode_from_string(value: String) -> Mode:
	match value:
		"local", "local_only", "local-only", "offline":
			return Mode.LOCAL_ONLY
		"classroom", "school", "education":
			return Mode.CLASSROOM
		"family", "family_cloud", "family-cloud", "cloud", "":
			return Mode.FAMILY_CLOUD
		_:
			return Mode.FAMILY_CLOUD


func is_feature_enabled(feature_key: String) -> bool:
	return features.get(feature_key, false)


func is_feature_hard_disabled(feature_key: String) -> bool:
	return bool(_hard_disabled_features.get(feature_key, false))


func _apply_defaults() -> void:
	_hard_disabled_features = {}

	# Default feature set
	features = {
		"ai_generation": true,
		"ai_experimental_tools": false,
		"ai_beta_features": false,
		"online_multiplayer": true,
		"online_family_sessions": true,
		"cloud_sync": true,
		"advanced_debug": false,
		"telemetry": true
	}
	
	match mode:
		Mode.LOCAL_ONLY:
			_hard_disable("online_multiplayer")
			_hard_disable("online_family_sessions")
			_hard_disable("cloud_sync")
			_hard_disable("telemetry") # Local only implies no phone home
			_hard_disable("ai_experimental_tools")
			_hard_disable("ai_beta_features")
			
		Mode.CLASSROOM:
			features["ai_generation"] = true # Often managed
			_hard_disable("ai_experimental_tools") # Strict safety
			_hard_disable("ai_beta_features")
			_hard_disable("online_multiplayer") # Usually blocked unless local
			_hard_disable("online_family_sessions")
			features["cloud_sync"] = true # Managed sync
			_hard_disable("advanced_debug")
			
		Mode.FAMILY_CLOUD:
			# Maximally permissive defaults, but experimental still defaults to false
			pass


func _hard_disable(feature_key: String) -> void:
	features[feature_key] = false
	_hard_disabled_features[feature_key] = true
