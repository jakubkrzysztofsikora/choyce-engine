class_name ThemeManager
extends RefCounted

static var _cached_palettes: Dictionary = {}

static func get_palettes() -> Dictionary:
	if _cached_palettes.is_empty():
		var file := FileAccess.open("res://data/themes/palettes.json", FileAccess.READ)
		if file:
			var json := JSON.new()
			var err := json.parse(file.get_as_text())
			if err == OK:
				var data: Dictionary = json.data
				_cached_palettes = data.get("palettes", {})
	return _cached_palettes.duplicate(true)


static func apply_palette_to_theme(theme: Theme, palette_id: String) -> void:
	var palettes := get_palettes()
	if not palettes.has(palette_id):
		push_warning("ThemeManager: unknown palette '%s'" % palette_id)
		return

	var palette: Dictionary = palettes[palette_id]
	var colors: Array = palette.get("colors", [])
	if colors.is_empty():
		return

	# Primary accent = first color
	var primary := _hex_to_color(str(colors[0]))
	var secondary := primary
	if colors.size() > 1:
		secondary = _hex_to_color(str(colors[1]))
	var bg := Color(0.945, 0.973, 1.0)
	if colors.size() > 3:
		bg = _hex_to_color(str(colors[3])).lightened(0.35)

	# Update Button primary styles
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := theme.get_stylebox(state, "Button")
		if sb is StyleBoxFlat:
			match state:
				"normal":
					sb.bg_color = primary
					sb.border_color = primary.darkened(0.2)
				"hover", "focus":
					sb.bg_color = primary.lightened(0.08)
					sb.border_color = primary.darkened(0.15)
				"pressed":
					sb.bg_color = primary.darkened(0.1)
					sb.border_color = primary.darkened(0.25)

	# Update Panel styles
	var panel_sb := theme.get_stylebox("panel", "PanelContainer")
	if panel_sb is StyleBoxFlat:
		panel_sb.bg_color = bg
		panel_sb.border_color = primary.lightened(0.35)

	# Update ProgressBar fill
	var fill_sb := theme.get_stylebox("fill", "ProgressBar")
	if fill_sb is StyleBoxFlat:
		fill_sb.bg_color = secondary

	# Update ItemList selection
	for style_name in ["selected", "selected_focus", "cursor"]:
		var item_sb := theme.get_stylebox(style_name, "ItemList")
		if item_sb is StyleBoxFlat:
			item_sb.bg_color = Color(primary.r, primary.g, primary.b, 0.25)
			item_sb.border_color = Color(primary.r, primary.g, primary.b, 0.6)

	# Update ScrollBar grabbers
	for bar in ["HScrollBar", "VScrollBar"]:
		var grabber := theme.get_stylebox("grabber", bar)
		if grabber is StyleBoxFlat:
			grabber.bg_color = secondary.darkened(0.1)
		var grabber_hl := theme.get_stylebox("grabber_highlight", bar)
		if grabber_hl is StyleBoxFlat:
			grabber_hl.bg_color = secondary.darkened(0.2)


static func _hex_to_color(hex: String) -> Color:
	if hex.begins_with("#"):
		hex = hex.substr(1)
	if hex.length() == 6:
		return Color(
			hex.substr(0, 2).hex_to_int() / 255.0,
			hex.substr(2, 2).hex_to_int() / 255.0,
			hex.substr(4, 2).hex_to_int() / 255.0
		)
	return Color.WHITE
