// Lightweight Godot 4 water surface for the streamed Adventure world.
// Inspired by the supplied MIT simple-water project's moving-distortion idea,
// but intentionally keeps this runtime self-contained: no reflection
// viewports, no editor plugin, and no dependency on a Godot 3 asset pipeline.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.42, 0.52, 0.82);
uniform vec4 deep_color : source_color = vec4(0.035, 0.17, 0.27, 0.90);
uniform float wave_height : hint_range(0.0, 0.20) = 0.035;
// The runtime river is deliberately large. Keep wavelengths broad enough for
// its streamed-friendly surface tessellation; tiny 4m waves on 36m quads
// alias into flat/faceted water.
uniform float wave_scale : hint_range(0.02, 2.0) = 0.16;
uniform float wave_speed : hint_range(0.0, 4.0) = 0.70;

varying float wave_mix;

void vertex() {
	float a = sin((VERTEX.x * wave_scale) + TIME * wave_speed);
	float b = cos((VERTEX.z * wave_scale * 0.73) + TIME * wave_speed * 0.83);
	wave_mix = (a + b) * 0.25 + 0.5;
	VERTEX.y += (a + b) * wave_height;
}

void fragment() {
	vec3 albedo = mix(deep_color.rgb, shallow_color.rgb, wave_mix);
	ALBEDO = albedo;
	METALLIC = 0.05;
	ROUGHNESS = 0.18;
	SPECULAR = 0.72;
	ALPHA = mix(deep_color.a, shallow_color.a, wave_mix);
}
