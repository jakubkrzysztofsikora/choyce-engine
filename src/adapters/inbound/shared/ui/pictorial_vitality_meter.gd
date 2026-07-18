## Compact, word-free vitality indicator for the child-facing adventure HUD.
##
## The meter intentionally uses shape, colour, and a familiar centre glyph
## rather than a percentage, level number, or text label. It only appears
## after damage, leaving exploration frames available to the world itself.
extends Control

var _vitality := 1.0
var _accent := Color(0.46, 0.94, 0.58)


func _ready() -> void:
	custom_minimum_size = Vector2(76.0, 76.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_vitality(value: float, accent: Color) -> void:
	_vitality = clampf(value, 0.0, 1.0)
	_accent = accent
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(12.0, minf(size.x, size.y) * 0.38)
	# A dark, translucent well prevents the bright status indicator from reading
	# as a floating editor bar against sky or foliage.
	draw_circle(center, radius + 7.0, Color(0.015, 0.025, 0.045, 0.78), true)
	draw_arc(center, radius + 3.5, 0.0, TAU, 48, Color(0.10, 0.16, 0.23, 0.96), 4.0, true)
	var start := -PI * 0.5
	draw_arc(center, radius + 3.5, start, start + TAU * _vitality, 48,
		_accent, 5.0, true)
	# Five short pips preserve an at-a-glance low-health cue for children who do
	# not yet map a continuous ring to a number. Their fade remains meaningful to
	# colour-blind players even when the accent changes to amber/red.
	for pip in range(5):
		var angle := start + TAU * float(pip) / 5.0
		var point := center + Vector2(cos(angle), sin(angle)) * (radius + 3.5)
		var active := _vitality > float(pip) / 5.0
		draw_circle(point, 2.2, _accent if active else Color(0.18, 0.22, 0.27, 0.88), true)
