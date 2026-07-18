// Soft-edged packed-earth overlay for the curated opening routes.
// The opening terrain is intentionally flat; feathering prevents the route
// from reading as a rectangular decal while native Terrain3D painting remains
// the long-term terrain workflow for hills and distant biomes.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_roughness : repeat_enable, filter_linear_mipmap;
uniform vec4 earth_color : source_color = vec4(0.39, 0.27, 0.15, 1.0);
uniform float detail_scale : hint_range(0.2, 12.0) = 3.2;
uniform float edge_feather : hint_range(0.01, 0.35) = 0.16;

void fragment() {
	vec2 detail_uv = UV * detail_scale;
	vec3 earth = texture(detail_albedo, detail_uv).rgb * 1.08;
	ALBEDO = earth_color.rgb * mix(vec3(1.0), earth, 0.68);
	ROUGHNESS = mix(0.76, texture(detail_roughness, detail_uv).r, 0.74);
	NORMAL_MAP = texture(detail_normal, detail_uv).rgb;
	NORMAL_MAP_DEPTH = 0.26;
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	ALPHA = smoothstep(0.0, edge_feather, edge) * 0.88;
}
