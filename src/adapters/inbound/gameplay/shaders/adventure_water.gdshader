// Lightweight Godot 4 water surface for the streamed Adventure world.
// Inspired by the supplied MIT simple-water project's moving-distortion idea,
// but intentionally keeps this runtime self-contained: no reflection
// viewports, no editor plugin, and no dependency on a Godot 3 asset pipeline.
shader_type spatial;
// The player can enter the river. Keep the surface opaque in the depth pass so
// it never vanishes through transparent-sort ambiguity when camera, avatar and
// terrain overlap at the shore.
// River readability must not depend on the active directional-light grade.
// The lit PBR path can blow the broad PlaneMesh out to near white in the
// launcher/direct-session path, hiding water altogether. Keep the water
// opaque and use its authored colour/foam directly; wave displacement still
// provides motion while water stays visibly blue at all times of day.
render_mode cull_disabled, depth_draw_opaque, unshaded, fog_disabled;

uniform vec4 shallow_color : source_color = vec4(0.012, 0.145, 0.19, 1.0);
uniform vec4 deep_color : source_color = vec4(0.003, 0.045, 0.085, 1.0);
uniform vec4 foam_color : source_color = vec4(0.14, 0.34, 0.33, 1.0);
uniform vec4 sky_reflection_color : source_color = vec4(0.08, 0.22, 0.28, 1.0);
// This is cosmetic water, not a dynamic collision surface. Keep its peak-to-
// trough movement inside the shallow-volume contact tolerance at the bank.
uniform float wave_height : hint_range(0.0, 0.20) = 0.012;
// The runtime river is deliberately large. Keep wavelengths broad enough for
// its streamed-friendly surface tessellation; tiny 4m waves on 36m quads
// alias into flat/faceted water.
uniform float wave_scale : hint_range(0.02, 2.0) = 0.16;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.70;
// MIT SimpleWater DUDV source texture, supplied locally by the project owner.
// This is a Godot 4 port of the texture-distortion idea, not the obsolete
// Godot 3 reflection viewport implementation bundled with the original pack.
uniform sampler2D dudv_map : source_color, repeat_enable, filter_linear_mipmap;
// DUDV uses local river metres (flow_position), not normalized full-ribbon UV.
// At 0.12 it repeats roughly every eight metres in the actual bridge view.
uniform float dudv_tiling : hint_range(0.01, 2.0) = 0.12;
uniform float dudv_strength : hint_range(0.0, 0.12) = 0.028;

varying float wave_mix;
varying vec2 wave_gradient;
varying float river_depth;
varying float river_bank;
varying vec2 flow_position;

void vertex() {
	// Use world-space coordinates for flow to ensure DUDV distortion is based on
	// local/world metres rather than normalized 0-1 UVs. This prevents the full-river
	// length from compressing the flow pattern into a single repeat.
	vec3 world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float a = sin((world_pos.x * wave_scale) + TIME * wave_speed);
	float b = cos((world_pos.z * wave_scale * 0.73) + TIME * wave_speed * 0.83);
	wave_mix = (a + b) * 0.25 + 0.5;
	// Analytic slopes keep the moving surface lit as water rather than as a
	// flat tinted plane. It is deliberately gentle: this is a stream, not sea.
	wave_gradient = vec2(
		cos((world_pos.x * wave_scale) + TIME * wave_speed) * wave_scale * wave_height,
		-sin((world_pos.z * wave_scale * 0.73) + TIME * wave_speed * 0.83) * wave_scale * 0.73 * wave_height);
	VERTEX.y += (a + b) * wave_height;
	// flow_position is now in world XZ metres to ensure DUDV distortion scales
	// with actual river length rather than normalizing across the entire mesh.
	// This addresses the finding: "Normalized full-river UVs leave no legible flow
	// pattern in the bridge camera".
	flow_position = world_pos.xz;
	// The ribbon supplies stable bank-to-bank UVs even as it curves across the
	// island. Bright shallow edges and a dark central channel give visual depth
	// without expensive screen-space reflections or terrain-depth sampling.
	river_depth = smoothstep(0.28, 0.92, 1.0 - abs(UV.y - 0.5) * 2.0);
	river_bank = abs(UV.y - 0.5) * 2.0;
}

void fragment() {
	vec2 flow_uv = flow_position * dudv_tiling;
	vec2 dudv_a = texture(dudv_map, flow_uv + vec2(TIME * 0.020, TIME * 0.011)).rg * 2.0 - 1.0;
	vec2 dudv_b = texture(dudv_map, flow_uv * 1.73 - vec2(TIME * 0.014, TIME * 0.022)).rg * 2.0 - 1.0;
	float dudv_flow = (dudv_a.x + dudv_a.y + dudv_b.x + dudv_b.y) * 0.25;
	// Compute the channel directly from the bank-to-bank UV in the fragment as
	// well as the vertex varying. This remains stable with generated ArrayMesh
	// interpolation and produces an obvious darker centre instead of one flat
	// cyan sheet.
	float channel_depth = smoothstep(0.18, 0.90, 1.0 - abs(UV.y - 0.5) * 2.0);
	vec3 bank_color = mix(shallow_color.rgb, deep_color.rgb, max(river_depth, channel_depth));
	// Two stretched, offset ripple fields make the current legible from a
	// third-person camera. They follow the river UV rather than world X so the
	// highlight does not cut sideways across the meandering surface.
	float flow_streak_a = sin(flow_position.x * 0.72 + UV.y * 7.0 - TIME * 2.2 + dudv_flow * 5.0) * 0.5 + 0.5;
	float flow_streak_b = sin(flow_position.x * 0.38 - UV.y * 12.0 - TIME * 1.35 - dudv_flow * 3.0) * 0.5 + 0.5;
	float flow_streak = mix(flow_streak_a, flow_streak_b, 0.42);
	vec3 albedo = mix(bank_color * 0.70, bank_color * 1.18,
		clamp(wave_mix + dudv_flow * dudv_strength * 5.0 + flow_streak * 0.22, 0.0, 1.0));
	// PlaneMesh UV orientation is importer/platform dependent in the runtime
	// scene. Deriving a shore band from UV.y therefore turned the *entire* river
	// into bright foam on the launcher path. Keep foam tied only to the animated
	// crest until a real bank-depth mask is available.
	float crest_foam = smoothstep(0.78, 0.96, wave_mix + dudv_flow * dudv_strength * 3.0) * 0.24;
float bank_foam = smoothstep(0.70, 0.96, river_bank) * 0.08;
	float foam = crest_foam + bank_foam;
	NORMAL = normalize(vec3(-wave_gradient.x, 1.0, -wave_gradient.y));
	// A restrained Fresnel reflection is the inexpensive Godot 4 equivalent of
	// the supplied Simple Water material's reflection pass. It gives the river
	// a changing sky-facing surface without transparent sorting or extra cameras.
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	// A small base sky response avoids the dead dark strip visible from the
	// normal gameplay camera; Fresnel still strengthens it toward the horizon.
albedo = mix(albedo, sky_reflection_color.rgb, 0.08 + fresnel * 0.24);
	ALBEDO = mix(albedo, foam_color.rgb, foam);
	// A small emissive lift keeps the river readable in shadow without washing
	// it into the old grey-blue floor at noon.
	EMISSION = albedo * 0.025;
	ALPHA = 1.0;
}
