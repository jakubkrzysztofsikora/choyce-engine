// Lightweight Godot 4 water surface for the streamed Adventure world.
// Inspired by the supplied MIT simple-water project's moving-distortion idea,
// but intentionally keeps this runtime self-contained: no reflection
// viewports, no editor plugin, and no dependency on a Godot 3 asset pipeline.
shader_type spatial;
// The player can enter the river. The surface must NEVER disappear when the
// player wades in, and it must never render through the bridge or terrain
// either: normal depth testing is kept (the old depth_test_disabled drew the
// river over every wall). The water still WRITES depth (depth_draw_always),
// so objects behind the water (player's legs, riverbed) are correctly
// occluded. The ribbon is terrain-conformed with a 5cm lift, so no
// z-fighting with the riverbed can hide the surface.
render_mode cull_disabled, depth_draw_always, unshaded, fog_disabled;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.42, 0.55, 1.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.18, 0.32, 1.0);
uniform vec4 foam_color : source_color = vec4(0.85, 0.92, 0.95, 1.0);
uniform vec4 sky_reflection_color : source_color = vec4(0.35, 0.55, 0.70, 1.0);
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
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	// Restrained Fresnel — at top-down camera angles the dot(NORMAL, VIEW)=-1,
	// clamped to 0, gave pow(1.0, 3) = 1.0 fresnel which mixed 32% to a near-
	// black sky_reflection_color. That is why the river 'disappeared' when the
	// player walked into it: the camera looked straight down, the fresnel
	// maxed, the dark reflection won, and the water read as a black void
	// against the riverbed. Cap the fresnel contribution at 0.10 max and keep
	// a brighter base albedo so the surface stays visibly blue from every angle.
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	fresnel = mix(0.03, 0.10, fresnel);
albedo = mix(albedo, sky_reflection_color.rgb, fresnel);
	ALBEDO = mix(albedo, foam_color.rgb, foam);
	// A small emissive lift keeps the river readable in shadow without washing
	// it into the old grey-blue floor at noon.
	EMISSION = albedo * 0.025;
	ALPHA = 1.0;
}
