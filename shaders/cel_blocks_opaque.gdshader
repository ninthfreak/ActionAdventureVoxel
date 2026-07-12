shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
// Opaque-pipeline twin of cel_blocks.gdshader. Blocks run on this shader by
// default (full early-Z, no transparent pass); BlockRegistry hot-swaps the
// shared material to cel_blocks.gdshader only while a translucent cutaway or
// water reveal is active. Uniform values persist across the swap, so both
// shaders declare the same set.

uniform vec3 albedo : source_color = vec3(1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.35;
uniform int bands : hint_range(2, 5) = 3;
uniform bool use_vertex_color = false;
uniform vec3 lit_tint : source_color = vec3(1.0, 0.97, 0.89);
uniform vec3 shadow_tint : source_color = vec3(0.78, 0.84, 1.0);
uniform bool cutaway_affected = false;
uniform bool is_water = false;

global uniform float voxel_cutaway;
global uniform vec3 voxel_player_pos;
global uniform float voxel_water_reveal;
global uniform float voxel_cut_height;
global uniform float voxel_cut_radius;
global uniform float voxel_cut_soft;

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	// editor hard floor slice (voxel_cut_soft == 0) works in the opaque
	// pipeline via discard; the soft translucent cutaway is handled by the
	// cel_blocks shader after the pipeline swap.
	if (cutaway_affected && voxel_cutaway > 0.001 && voxel_cut_soft < 0.5) {
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		if (wp.y > voxel_cut_height + 0.01) {
			float dist = distance(wp.xz, voxel_player_pos.xz);
			float factor = (1.0 - smoothstep(voxel_cut_radius, voxel_cut_radius + 4.0, dist)) * voxel_cutaway;
			if (factor > 0.999 || (factor > 0.001 && ign(FRAGCOORD.xy) < factor)) {
				discard;
			}
		}
	}
	ALBEDO = use_vertex_color ? COLOR.rgb : albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float x = ndl * float(bands);
	float aa = clamp(fwidth(x), 0.001, 0.45);
	float stepped = clamp((floor(x) + smoothstep(0.5 - aa, 0.5 + aa, fract(x))) / float(bands), 0.0, 1.0);
	float shadow = smoothstep(0.25, 0.75, ATTENUATION);
	float s = stepped * shadow;
	vec3 shade = mix(shadow_tint * (1.0 - shadow_strength), lit_tint, s);
	DIFFUSE_LIGHT = ALBEDO * shade;
}
