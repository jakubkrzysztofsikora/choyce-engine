extends SceneTree

const DeploymentConfigScn = preload("res://src/application/deployment_config.gd")
const FeatureFlagServiceScn = preload("res://src/application/feature_flag_service.gd")

func _init() -> void:
    print("Testing Feature Flag Service & Deployment Config...")
    _test_deployment_modes()
    _test_feature_service()
    quit()

func _test_deployment_modes() -> void:
    # 1. Family Cloud (Default)
    var family_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.FAMILY_CLOUD)
    _assert(family_config.is_feature_enabled("online_multiplayer") == true, "FAMILY_CLOUD enables multiplayer")
    _assert(family_config.is_feature_enabled("cloud_sync") == true, "FAMILY_CLOUD enables sync")
    
    # 2. Local Only
    var local_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
    _assert(not local_config.is_feature_enabled("online_multiplayer"), "LOCAL_ONLY disables multiplayer")
    _assert(not local_config.is_feature_enabled("cloud_sync"), "LOCAL_ONLY disables sync")
    _assert(local_config.is_feature_enabled("ai_generation") == true, "LOCAL_ONLY keeps AI (local LLM)")

    # 3. Classroom
    var classroom_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.CLASSROOM)
    _assert(classroom_config.is_feature_enabled("ai_generation") == true, "CLASSROOM enables AI")
    _assert(not classroom_config.is_feature_enabled("online_multiplayer"), "CLASSROOM disables arbitrary multiplayer")
    _assert(classroom_config.is_feature_enabled("cloud_sync") == true, "CLASSROOM enables managed sync")

func _test_feature_service() -> void:
    var base_config = DeploymentConfigScn.new(DeploymentConfigScn.Mode.LOCAL_ONLY)
    var service = FeatureFlagServiceScn.new(base_config)
    
    # Verify base (Local Only)
    _assert(not service.is_enabled("online_multiplayer"), "Default is disabled (Local)")
    
    # Enable override
    service.set_override("online_multiplayer", true)
    _assert(service.is_enabled("online_multiplayer"), "Override to true works")
    
    # Disable override
    service.set_override("online_multiplayer", false)
    _assert(not service.is_enabled("online_multiplayer"), "Override to false works")
    
    # Clear override
    service.set_override("online_multiplayer", null)
    _assert(not service.is_enabled("online_multiplayer"), "Clearing override reverts to base")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL: %s" % message)
    else:
        print("PASS: %s" % message)
