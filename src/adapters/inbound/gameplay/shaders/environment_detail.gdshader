// Shared PBR detail layer for environment meshes that ship with only a flat
// palette material. It keeps each asset's authored colour while adding the
// local CC0 albedo/roughness/normal detail, so rocks, hills and Builder pieces
// no longer read as untextured primitives.
shader_type spatial;
render_mode depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_roughness : repeat_enable, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float detail_scale : hint_range(0.2, 12.0) = 2.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.35;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.32;
uniform float roughness_strength : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	vec2 detail_uv = UV * detail_scale;
	vec3 detail = texture(detail_albedo, detail_uv).rgb;
	vec3 variation = mix(vec3(1.0), detail * 1.18, detail_strength);
	ALBEDO = albedo.rgb * variation;
	ROUGHNESS = clamp(mix(0.74, texture(detail_roughness, detail_uv).r, roughness_strength), 0.32, 0.92);
	NORMAL_MAP = texture(detail_normal, detail_uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
