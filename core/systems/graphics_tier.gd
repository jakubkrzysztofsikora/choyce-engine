class_name GraphicsTier
extends RefCounted
## Applies a GraphicsProfile to a live World3D based on active player count.
##
## Called by SplitScreenManager whenever the roster changes. Kept as a plain
## RefCounted (not an autoload) because it is a pure function over the scene: it
## reads nothing and owns nothing.

static func apply(profile: GraphicsProfile, world_root: Node3D,
		viewports: Array, player_count: int) -> Dictionary:
	if profile == null or world_root == null:
		return {}

	var applied := {
		"players": player_count,
		"splits": profile.splits_for(player_count),
		"shadow_distance": profile.shadow_distance_for(player_count),
		"ssao": profile.ssao_for(player_count),
		"ssil": profile.ssil_for(player_count),
		"fog": profile.fog_for(player_count),
		"sdfgi": profile.sdfgi_for(player_count),
		"render_scale": profile.scale_for(player_count),
		"lights_touched": 0,
		"viewports_touched": 0,
	}

	# Shadow cascades first — this is the measured high-leverage lever.
	for light in _find_all(world_root, "DirectionalLight3D"):
		var d := light as DirectionalLight3D
		d.directional_shadow_mode = _mode_for(applied["splits"])
		d.directional_shadow_max_distance = applied["shadow_distance"]
		applied["lights_touched"] += 1

	for we in _find_all(world_root, "WorldEnvironment"):
		var env := (we as WorldEnvironment).environment
		if env == null:
			continue
		env.ssao_enabled = applied["ssao"]
		env.ssil_enabled = applied["ssil"]
		env.volumetric_fog_enabled = applied["fog"]
		env.sdfgi_enabled = applied["sdfgi"]

	# Directional shadows use a GLOBAL atlas, not the per-viewport positional
	# one. Setting SubViewport.positional_shadow_atlas_size did nothing for the
	# DirectionalLight3D shadows this whole tier system exists to tune — and on
	# a level with no omni/spot lights it was a pure no-op.
	RenderingServer.directional_shadow_atlas_set_size(profile.atlas_for(player_count), true)

	for vp in viewports:
		if vp is SubViewport:
			(vp as SubViewport).scaling_3d_scale = applied["render_scale"]
			applied["viewports_touched"] += 1

	return applied


static func _mode_for(splits: int) -> DirectionalLight3D.ShadowMode:
	match splits:
		1: return DirectionalLight3D.SHADOW_ORTHOGONAL
		2: return DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_: return DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


static func _find_all(root: Node, type_name: String) -> Array[Node]:
	var out: Array[Node] = []
	if root.is_class(type_name):
		out.append(root)
	for child in root.get_children():
		out.append_array(_find_all(child, type_name))
	return out
