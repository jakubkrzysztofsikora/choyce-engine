## Thin launcher: the very first thing the kid sees. One screen, one clear
## action — a big pulsing PLAY that drops straight into the Adventure world.
## Fully code-built (no fragile .tscn) and responsive: anchored controls +
## the project's canvas_items/expand stretch scale it to any viewport. Music
## via the AudioBank autoload; light Tween animation for life.
##
## Emits `play_pressed` — main.gd wires it to the proven direct-launch path
## (_on_world_card_pressed) so we reuse the whole play→win loop, no new
## composition root.
class_name LauncherOverlay
extends CanvasLayer

signal play_pressed

const REF := Vector2(1600.0, 960.0)  ## design reference; stretch scales from here
const ADVENTURE_TITLE := "Wyspa skarbów"
const _MUSIC := "adventure_island"

var _root: Control
var _title: Label
var _play_btn: Button
var _subtitle: Label
var _shapes: Array[Dictionary] = []      ## {node, speed, phase, base}
var _t: float = 0.0
var _localization = null


func setup(localization = null) -> LauncherOverlay:
	_localization = localization
	return self


func _ready() -> void:
	layer = 100  ## above every shell
	_build()
	_start_music()
	set_process(true)


func _build() -> void:
	_root = Control.new()
	_root.name = "LauncherRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  ## eat clicks behind us
	add_child(_root)

	# Animated gradient sky.
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.color = Color(0.15, 0.62, 0.86)
	sky.material = _make_gradient_material()
	_root.add_child(sky)

	# Floating shapes layer (drifting rounded rects — cheap "clouds/bubbles").
	var shapes_layer := Control.new()
	shapes_layer.name = "Shapes"
	shapes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	shapes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shapes_layer)
	_spawn_shapes(shapes_layer)

	# Centre column — anchored to viewport centre so it stays put on resize.
	var col := VBoxContainer.new()
	col.name = "CenterColumn"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	col.set_anchors_preset(Control.PRESET_CENTER)
	# Grow from the anchored centre; container sizes to content.
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(col)

	_title = Label.new()
	_title.name = "Title"
	_title.text = _tr("launcher.title", "Wyspa skarbów")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 96)
	_title.add_theme_color_override("font_color", Color(1, 1, 1))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	_title.add_theme_constant_override("shadow_offset_x", 4)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.pivot_offset = Vector2(0, 0)
	col.add_child(_title)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.text = _tr("launcher.subtitle", "Pokonaj 3 potwory i zdobądź skarb!")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 34)
	_subtitle.add_theme_color_override("font_color", Color(1, 1, 0.85))
	_subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	_subtitle.add_theme_constant_override("shadow_offset_x", 2)
	_subtitle.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_subtitle)

	# Spacer so the button sits below the titles.
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)

	_play_btn = Button.new()
	_play_btn.name = "PlayButton"
	_play_btn.text = _tr("launcher.play", "▶  GRAJ")
	_play_btn.custom_minimum_size = Vector2(420, 140)
	_play_btn.add_theme_font_size_override("font_size", 64)
	_play_btn.focus_mode = Control.FOCUS_ALL
	_style_play_button(_play_btn)
	# Center the button within the column regardless of its min-size.
	var btn_wrap := HBoxContainer.new()
	btn_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_wrap.set("size_flags_horizontal", Control.SIZE_SHRINK_CENTER)
	btn_wrap.add_child(_play_btn)
	col.add_child(btn_wrap)

	_play_btn.pressed.connect(_on_play)
	_play_btn.grab_focus()

	_animate_intro()


## Animated sky: vertical gradient + a soft radial sun glow that breathes +
## slow drifting light bands. Pure canvas_item shader, no texture assets.
func _make_gradient_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.16, 0.62, 0.95, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.58, 0.88, 0.72, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.96, 0.72, 1.0);
uniform vec2 sun_pos = vec2(0.80, 0.24);   // top-right, in UV space
uniform float band_speed : hint_range(0.0, 0.5) = 0.06;

void fragment() {
	// Base vertical gradient.
	vec3 col = mix(top_color.rgb, bottom_color.rgb, UV.y);

	// Breathing radial sun glow (aspect-corrected so it stays round-ish).
	vec2 d = UV - sun_pos;
	d.x *= 1.7;
	float dist = length(d);
	float breath = 0.5 + 0.5 * sin(TIME * 0.8);
	float glow = smoothstep(0.55, 0.0, dist) * (0.55 + 0.25 * breath);
	col = mix(col, sun_color.rgb, glow);

	// Slow drifting diagonal light bands for gentle motion.
	float band = sin((UV.x + UV.y) * 6.0 - TIME * band_speed * 10.0);
	col += band * 0.015;

	COLOR = vec4(col, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _spawn_shapes(parent: Control) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260719
	for i in range(7):
		var c := ColorRect.new()
		c.name = "Shape%d" % i
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := rng.randf_range(90.0, 220.0)
		c.size = Vector2(s, s * 0.62)
		c.color = Color(1, 1, 1, rng.randf_range(0.10, 0.22))
		var base := Vector2(
			rng.randf_range(0.0, REF.x),
			rng.randf_range(0.0, REF.y)
		)
		c.position = base
		parent.add_child(c)
		_shapes.append({
			"node": c,
			"speed": rng.randf_range(12.0, 34.0),
			"phase": rng.randf_range(0.0, TAU),
			"base": base,
		})


func _style_play_button(btn: Button) -> void:
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(70)
		sb.set_border_width_all(6)
		sb.border_color = border
		sb.set_content_margin_all(24)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 8)
		return sb
	btn.add_theme_stylebox_override("normal", mk.call(Color(0.16, 0.78, 0.42), Color(1, 1, 1, 0.9)))
	btn.add_theme_stylebox_override("hover", mk.call(Color(0.20, 0.88, 0.50), Color(1, 1, 1)))
	btn.add_theme_stylebox_override("pressed", mk.call(Color(0.12, 0.64, 0.34), Color(1, 1, 1, 0.8)))
	btn.add_theme_stylebox_override("focus", mk.call(Color(0.20, 0.88, 0.50), Color(1, 1, 0.6)))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.92, 1, 0.92))


func _animate_intro() -> void:
	# Title + button pop in.
	_title.scale = Vector2(0.6, 0.6)
	_title.modulate.a = 0.0
	_play_btn.scale = Vector2(0.6, 0.6)
	_play_btn.pivot_offset = _play_btn.custom_minimum_size * 0.5
	_title.pivot_offset = Vector2(_title.size.x * 0.5, _title.size.y * 0.5)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "scale", Vector2.ONE, 0.6)
	tw.tween_property(_title, "modulate:a", 1.0, 0.5)
	tw.chain().tween_property(_play_btn, "scale", Vector2.ONE, 0.5).set_delay(0.15)


func _process(delta: float) -> void:
	_t += delta
	# Gentle idle pulse on the PLAY button so it reads as "tap me".
	if _play_btn != null and is_instance_valid(_play_btn):
		var pulse := 1.0 + sin(_t * 2.4) * 0.04
		_play_btn.scale = Vector2(pulse, pulse)
	# Drift floating shapes; wrap across the reference width.
	for s in _shapes:
		var node: ColorRect = s["node"]
		if not is_instance_valid(node):
			continue
		var base: Vector2 = s["base"]
		var x := base.x + fmod(_t * float(s["speed"]), REF.x + 240.0) - 120.0
		var y := base.y + sin(_t * 0.6 + float(s["phase"])) * 18.0
		node.position = Vector2(x, y)


func _on_play() -> void:
	set_process(false)
	if _play_btn != null:
		_play_btn.disabled = true
	# Quick press feedback, then hand off.
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_stop_music()
		play_pressed.emit()
		queue_free()
	)


func _start_music() -> void:
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("play_music"):
		bank.play_music(_MUSIC, true)


func _stop_music() -> void:
	var bank := get_node_or_null("/root/AudioBank")
	if bank != null and bank.has_method("stop_music"):
		bank.stop_music(true)


func _tr(key: String, fallback: String) -> String:
	if _localization != null and _localization.has_method("translate"):
		var v: String = _localization.translate(key)
		if v != "" and v != key:
			return v
	return fallback
