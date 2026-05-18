class_name MaterialLibrary extends RefCounted

static var _cache: Dictionary = {}

static func get_material(name: String, color: Color = Color.WHITE) -> StandardMaterial3D:
    var key := "%s_%s" % [name, color.to_html()]
    if _cache.has(key):
        return _cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.8
    _cache[key] = mat
    return mat

static func get_preset(preset_name: String) -> StandardMaterial3D:
    match preset_name:
        "object": return get_material("object", Color(0.75, 0.75, 0.75))
        "terrain": return get_material("terrain", Color(0.2, 0.6, 0.2))
        "light": return get_material("light", Color(1.0, 0.9, 0.5))
        "spawn": return get_material("spawn", Color(0.2, 0.4, 1.0))
        "trigger": return get_material("trigger", Color(1.0, 0.2, 0.2))
        "decoration": return get_material("decoration", Color(0.9, 0.5, 0.8))
    return get_material("default", Color.WHITE)
