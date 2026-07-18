// Re-colours only the blue uniform swatches in Kenney's shared toon atlas.
// It keeps the original skinned mesh, UVs, face and hands intact, while
// allowing the Adventure protagonists to read as their supplied concepts.
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform sampler2D source_albedo : source_color, filter_nearest;
uniform sampler2D hoodie_pattern : source_color, repeat_enable, filter_nearest;
uniform vec4 garment_color : source_color = vec4(0.15, 0.72, 0.71, 1.0);
uniform vec4 trouser_color : source_color = vec4(0.12, 0.14, 0.18, 1.0);
uniform float hoodie_pattern_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(source_albedo, UV);
	vec3 rgb = source.rgb;
	float blue_lead = max(rgb.b - max(rgb.r, rgb.g), 0.0);
	float cyan_lead = max(rgb.g - rgb.r, 0.0) * step(rgb.b * 0.82, rgb.g);
	float cloth_mask = smoothstep(0.035, 0.18, max(blue_lead, cyan_lead));
	// Dark blue textile swatches are deliberately included, but near-black
	// details remain untouched so shoes, hair seams and linework stay dark.
	float visible_value = smoothstep(0.075, 0.22, max(max(rgb.r, rgb.g), rgb.b));
	cloth_mask *= visible_value;
	// The shared Kenney atlas is vertically inverted relative to the rendered
	// body: treating its high-V region as trousers painted Ziemek's *torso*
	// cargo-grey in the live third-person view.  The low-V islands are the
	// legs; the head is a separate mesh/material so it remains unaffected.
	float trouser_mask = (1.0 - smoothstep(0.18, 0.24, UV.y)) * visible_value;
	// The player is most often viewed from several metres behind. Repeating the
	// fabric five times made its turquoise explorer motifs collapse into a plain
	// grey-blue uniform at that distance. Keep the supplied textile large enough
	// for the hoodie language to survive the real third-person camera.
	vec3 fabric = texture(hoodie_pattern, UV * 1.65).rgb;
	vec3 recoloured = mix(rgb, garment_color.rgb, 0.88);
	vec3 garment = mix(rgb, recoloured, cloth_mask);
	// The imported rig's visible back/arms do not consistently use the old
	// blue atlas islands. For Ziemek, cover the whole non-trouser garment
	// surface so the pattern is legible in the actual third-person camera.
	garment = mix(garment, fabric, hoodie_pattern_strength * (1.0 - trouser_mask) * 0.92);
	ALBEDO = mix(garment, trouser_color.rgb, trouser_mask * 0.9);
	ROUGHNESS = 0.82;
}
