extends Control
## Per-pane HUD. Lives INSIDE the player's SubViewport, so it is drawn only in
## that player's pane and needs no per-player culling.

var player_id: int = -1

@onready var _prompt: Label = get_node_or_null("Prompt")
@onready var _name: Label = get_node_or_null("NameLabel")


func _process(_delta: float) -> void:
	var reg := PlayerRegistrySystem.instance
	if reg == null:
		return
	var profile := reg.get_profile(player_id)
	if profile == null:
		return

	var line := profile.display_name

	var health := Components.get_comp(profile.body, Components.HEALTH) as HealthComponent
	if health:
		line += "   HP %d" % int(round(health.current))

	if _name:
		_name.text = line

	if _prompt == null:
		return

	var text := ""

	# Build mode readout: without this the player cannot tell what block is
	# selected or which placement mode they are in.
	var build_ctl: BuildController = null
	if is_instance_valid(profile.body) and profile.body.has_method("build_controller"):
		build_ctl = profile.body.call("build_controller")
	if build_ctl and build_ctl.active:
		var mode_names := ["GRID", "SURFACE", "FREE"]
		text = "[BUILD] %s   mode %s   (Tab next / R rotate / M mode)" % [
			String(build_ctl.selected_block()), mode_names[int(build_ctl.mode)]]
	else:
		var sys := InteractionSystem.instance
		var focus := sys.focused_for(player_id) if sys else null
		if focus:
			text = focus.prompt_text

	_prompt.text = text
	_prompt.add_theme_color_override("font_color", profile.colour)
