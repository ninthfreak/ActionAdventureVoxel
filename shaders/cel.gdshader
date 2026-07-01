shader_type spatial;
render_mode specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.4;
uniform int bands : hint_range(2, 5) = 3;
// Set true on meshes that supply COLOR per-vertex (e.g. the character model).
uniform bool use_vertex_color = false;

void fragment() {
	if (use_vertex_color) {
		ALBEDO = COLOR.rgb;
	} else {
		ALBEDO = albedo;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float stepped = floor(clamp(NdotL, 0.0, 1.0) * float(bands) + 0.5) / float(bands);
	float shading = mix(1.0 - shadow_strength, 1.0, stepped);
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * shading * ALBEDO;
}
