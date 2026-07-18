// Readable, two-sided foliage for the imported CC0 Quaternius forest trees.
// Their authored canopy normals are intentionally varied; applying the main
// two-band cel shader made whole crowns collapse to near-black at the opening
// camera.  This retains the local leaf texture and its depth while providing a
// bounded minimum light response, so the forest is legible from its bright
// clearing without becoming an unshaded flat cutout.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 foliage_floor : source_color = vec4(0.12, 0.28, 0.10, 1.0);
uniform vec4 foliage_tint : source_color = vec4(1.18, 1.28, 1.08, 1.0);
uniform float texture_detail : hint_range(0.0, 1.0) = 0.78;
uniform float minimum_light : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	vec3 texture_color = texture(albedo_texture, UV).rgb * foliage_tint.rgb;
	ALBEDO = mix(foliage_floor.rgb, texture_color, texture_detail);
	ROUGHNESS = 0.88;
}

void light() {
	// The authored crowns contain many side-facing facets. Keep their direct
	// response, but never quantise them down to a black silhouette as the main
	// two-band cel shader did. This retains sunlight direction and material
	// depth across a forest rather than making it a uniform unlit hedge.
	float directional = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float bounded_light = mix(minimum_light, 1.0, smoothstep(0.0, 1.0, directional));
	DIFFUSE_LIGHT += ALBEDO * bounded_light * ATTENUATION * LIGHT_COLOR;
}
