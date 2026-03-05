extends SceneTree

var _test_scene

func _init() -> void:
    print("Testing Onboarding Integration...")
    call_deferred("_setup_and_run")

func _setup_and_run() -> void:
    _setup()
    await _run_tests()
    quit()

func _setup() -> void:
    # Force load dependencies
    var _dc = load("res://src/application/deployment_config.gd")
    var _ffs = load("res://src/application/feature_flag_service.gd")
    var _os = load("res://src/application/onboarding_service.gd")
    var _prof_script = load("res://src/domain/gameplay/player_profile.gd")
    var profile = _prof_script.new("test_kid", 0) # 0 = KID
    profile.preferences["onboarding_complete"] = false

    # Load scene from tscn to ensure nodes exist
    var scene_pkg = load("res://src/adapters/inbound/scenes/create/create_shell.tscn")
    _test_scene = scene_pkg.instantiate()
    root.add_child(_test_scene)

    # Inject mock ports - using dynamic mocks below
    _test_scene.setup(
        null, # Navigator
        profile,
        null, # Localization
        MockCreateProjectPort.new(),
        MockRunPlaytestPort.new(),
        MockApplyWorldEditPort.new()
    )

func _run_tests() -> void:
    await process_frame
    await process_frame
    
    if _test_scene._onboarding_service.is_onboarding_complete():
        print("FAIL: Should not be complete initially.")
        return
    
    # Welcome -> Place
    _test_scene._onboarding_service.acknowledge_welcome()
    await process_frame
    if _test_scene._onboarding_service._current_step != "place_first":
        print("FAIL: Did not advance to PLACE.")
        return
    print("PASS: Advanced to PLACE.")
    
    # Place -> Paint
    _test_scene._onboarding_service.record_action("place")
    await process_frame
    if _test_scene._onboarding_service._current_step != "paint_first":
        print("FAIL: PLACE action failed.")
        return
    print("PASS: PLACE -> PAINT.")
    
    # Paint -> Play
    _test_scene._onboarding_service.record_action("paint")
    await process_frame
    if _test_scene._onboarding_service._current_step != "test_play":
        print("FAIL: PAINT action failed.")
        return
    print("PASS: PAINT -> PLAY.")

    # Play -> Done
    # Try direct service action for play first to ensure logic works
    # If button exists, simulate press
    var play_btn = _test_scene.get_node_or_null("Layout/Actions/GoPlayButton")
    if play_btn:
        play_btn.pressed.emit()
    else:
        _test_scene._onboarding_service.record_action("play")

    await process_frame
    
    if not _test_scene._profile.preferences.get("onboarding_complete", false):
        print("FAIL: Play button failure.")
        return
    print("PASS: Onboarding completed.")

# -- Mocks --

class MockCreateProjectPort extends "res://src/ports/inbound/create_project_from_template_port.gd":
    func execute(_template: String, _profile):
        var p_script = load("res://src/domain/world_authoring/project.gd")
        var w_script = load("res://src/domain/world_authoring/world.gd")
        var p = p_script.new()
        p.worlds.append(w_script.new())
        return p

class MockRunPlaytestPort extends "res://src/ports/inbound/run_playtest_port.gd":
    func execute(_world_id: String, _players: Array):
        return null 

class MockApplyWorldEditPort extends "res://src/ports/inbound/apply_world_edit_command_port.gd":
    func execute(_world_id: String, _command, _profile) -> bool:
        return true
