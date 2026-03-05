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

func _init(p_mode: Mode = Mode.FAMILY_CLOUD) -> void:
	mode = p_mode
	_apply_defaults()

## Detects the deployment mode from environment variables or feature files.
static func from_environment() -> DeploymentConfig:
	var mode_str = OS.get_environment(ENV_VAR_MODE).to_upper()
	var selected_mode = Mode.FAMILY_CLOUD
	
	if mode_str == "LOCAL":
		selected_mode = Mode.LOCAL_ONLY
	elif mode_str == "CLASSROOM":
		selected_mode = Mode.CLASSROOM
	
	return DeploymentConfig.new(selected_mode)

func is_feature_enabled(feature_key: String) -> bool:
	return features.get(feature_key, false)

func _apply_defaults() -> void:
	# Default feature set
	features = {
		"ai_generation": true,
		"online_multiplayer": true,
		"cloud_sync": true,
		"advanced_debug": false,
		"telemetry": true
	}
	
	match mode:
		Mode.LOCAL_ONLY:
			features["online_multiplayer"] = false
			features["cloud_sync"] = false
			features["telemetry"] = false # Local only implies no phone home
			
		Mode.CLASSROOM:
			features["ai_generation"] = true # Often managed
			features["online_multiplayer"] = false # Usually blocked unless local
			features["cloud_sync"] = true # Managed sync
			features["advanced_debug"] = false
			
		Mode.FAMILY_CLOUD:
			# Maximally permissive defaults
			pass
