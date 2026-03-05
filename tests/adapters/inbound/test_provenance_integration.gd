extends SceneTree

const ProvenanceBadge = preload("res://src/adapters/inbound/shared/ui/provenance_badge.gd")

var _store: FilesystemProjectStore
var _temp_dir: String = "user://test_provenance"
var _exit_code := 0

func _init() -> void:
    # Use call_deferred to ensure the scene tree is ready if needed, 
    # though with --script it's initialized.
    call_deferred("_run_tests")

func _assert(condition: bool, message: String) -> void:
    if not condition:
        print("FAIL: %s" % message)
        _exit_code = 1
    else:
        print("PASS: %s" % message)

func _run_tests() -> void:
    print("Running Provenance Tests...")
    
    # 1. Test Project Store Serialization
    _store = FilesystemProjectStore.new(_temp_dir)
    # Ensure dir exists for the test
    DirAccess.make_dir_recursive_absolute(_temp_dir)
    
    var prov_source = ProvenanceData.SourceType.AI_VISUAL
    var prov = ProvenanceData.new(
        prov_source,
        "test-model-v1",
        "audit-123"
    )
    
    var node = SceneNode.new("node_1", SceneNode.NodeType.OBJECT)
    node.display_name = "AI Generated Tree"
    node.provenance = prov
    
    # Serialize (calling private method for testing purpose)
    var serialized = _store._serialize_scene_node(node)
    
    # Deserialize
    var new_node = _store._deserialize_scene_node(serialized)
    
    if new_node.provenance == null:
        _assert(false, "Provenance should not be null after deserialization")
    else:
        _assert(new_node.provenance.source == ProvenanceData.SourceType.AI_VISUAL, "Source type matches")
        _assert(new_node.provenance.generator_model == "test-model-v1", "Model matches")
        _assert(new_node.provenance.audit_id == "audit-123", "Audit ID matches")
        _assert(new_node.provenance.timestamp > 0, "Timestamp should be valid")
    
    # Cleanup file system (basic attempt)
    var dir = DirAccess.open(_temp_dir)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not file_name.begins_with(".") and not file_name.begins_with(".."):
                dir.remove(file_name)
            file_name = dir.get_next()
        dir.remove(_temp_dir)

    # 2. Test Badge UI
    var badge = ProvenanceBadge.new()
    get_root().add_child(badge) 
    
    var prov_ui = ProvenanceData.new(ProvenanceData.SourceType.HUMAN)
    badge.set_provenance(prov_ui)
    
    _assert(badge.visible == true, "Badge should be visible")
    # Accessing private members via loose typing for test verification or checking children
    # Since _label is var, we can access it
    var label_text = badge._label.text
    var label_modulate = badge._label.modulate
    
    _assert(label_text == "Human", "Badge text is 'Human' (Found: " + label_text + ")")
    # Approx comparison for color if needed, but exact should work
    _assert(label_modulate.is_equal_approx(badge.COLOR_HUMAN), "Badge color is correct for Human")
    
    var prov_ai = ProvenanceData.new(ProvenanceData.SourceType.AI_TEXT, "gpt-4", "audit-999")
    badge.set_provenance(prov_ai)
    
    label_text = badge._label.text
    _assert(label_text == "AI (Text)", "Badge text is 'AI (Text)'")
    
    var tooltip = badge.tooltip_text
    var has_model = tooltip.find("gpt-4") != -1
    _assert(has_model, "Tooltip contains model name")

    badge.queue_free()
    
    quit(_exit_code)
