shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.35;
uniform int bands : hint_range(2, 5) = 3;
uniform bool use_vertex_color = false;
// Sprite-artist palette trick: lit pixels lean warm, shadowed pixels lean cool.
uniform vec3 lit_tint : source_color = vec3(1.0, 0.97, 0.89);
uniform vec3 shadow_tint : source_color = vec3(0.78, 0.84, 1.0);

void fragment() {
	ALBEDO = use_vertex_color ? COLOR.rgb : albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	// Quantize into bands, but anti-alias the band edges so tiny normal
	// changes on rough voxel surfaces don't flicker between bands.
	float x = ndl * float(bands);
	float aa = clamp(fwidth(x), 0.001, 0.45);
	float stepped = clamp((floor(x) + smoothstep(0.5 - aa, 0.5 + aa, fract(x))) / float(bands), 0.0, 1.0);
	// Cast shadows snap toward the shadow band with a soft edge.
	float shadow = smoothstep(0.25, 0.75, ATTENUATION);
	float s = stepped * shadow;
	vec3 shade = mix(shadow_tint * (1.0 - shadow_strength), lit_tint, s);
	DIFFUSE_LIGHT = ALBEDO * shade;
}
