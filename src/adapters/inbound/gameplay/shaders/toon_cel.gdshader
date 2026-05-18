// Toon cel shader for choyce-engine (Godot 4.6)
// Applied via WorldRenderer to all MeshInstance3D nodes — both glTF props
// and primitive-mesh fallbacks (OBJECT, TERRAIN, DECORATION node types).
//
// light() quantises the NORMAL·LIGHT dot product into N discrete bands
// (light_steps uniform) to produce the classic two-tone cel-shading look.
// light_steps=2 → strong two-step shadow; 3 → softer three-step shadow.
//
// Outline: inverted-hull pass is deferred to v2. Not present here.

shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear, hint_default_white;
uniform float light_steps : hint_range(2.0, 6.0) = 2.0;
uniform vec4 shadow_color : source_color = vec4(0.85, 0.85, 0.95, 1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.55;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	// No vertex displacement for v1. Outline inverted-hull deferred to v2.
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	vec3 base = albedo.rgb * tex_color.rgb;
	ALBEDO = base;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	float band = floor(max(n_dot_l, 0.0) * light_steps) / light_steps;
	vec3 lit = ALBEDO * mix(shadow_color.rgb, vec3(1.0), band);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR;
}
