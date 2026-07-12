shader_type spatial;
// depth_prepass_alpha keeps mostly-opaque translucent surfaces self-occluding
// correctly instead of showing their own back faces through the front.
render_mode specular_disabled, ambient_light_disabled, depth_prepass_alpha;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.35;
uniform int bands : hint_range(2, 5) = 3;
uniform bool use_vertex_color = false;
// Sprite-artist palette trick: lit pixels lean warm, shadowed pixels lean cool.
uniform vec3 lit_tint : source_color = vec3(1.0, 0.97, 0.89);
uniform vec3 shadow_tint : source_color = vec3(0.78, 0.84, 1.0);
// Opt-in per material (world blocks yes, anything else no).
uniform bool cutaway_affected = false;
// Water material flag: goes semi-transparent while the player is submerged.
uniform bool is_water = false;

// Driven from player.gd / god_mode.gd:
global uniform float voxel_cutaway;
global uniform vec3 voxel_player_pos;
global uniform float voxel_water_reveal;
// Block-grid-aligned slice plane; blocks above it are affected.
global uniform float voxel_cut_height;
// Horizontal reach of the effect around voxel_player_pos.
global uniform float voxel_cut_radius;
// 1 = in-game soft cutaway (translucent walls, near-invisible ceilings);
// 0 = editor hard slice (blocks above the plane fully removed).
global uniform float voxel_cut_soft;

// interleaved gradient noise — stable per-pixel screen-door pattern
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	float alpha = 1.0;
	if (is_water && voxel_water_reveal > 0.001) {
		alpha = mix(1.0, 0.45, voxel_water_reveal);
	}
	if (cutaway_affected && voxel_cutaway > 0.001) {
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		if (wp.y > voxel_cut_height + 0.01) {
			float dist = distance(wp.xz, voxel_player_pos.xz);
			float factor = (1.0 - smoothstep(voxel_cut_radius, voxel_cut_radius + 4.0, dist)) * voxel_cutaway;
			if (factor > 0.001) {
				if (voxel_cut_soft > 0.5) {
					// translucent cutaway: horizontal cover (ceilings, roofs,
					// canopies) fades almost out; vertical walls stay readable
					float ny = abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
					float target = ny > 0.5 ? 0.06 : 0.35;
					alpha = min(alpha, mix(1.0, target, factor));
				} else if (factor > 0.999 || ign(FRAGCOORD.xy) < factor) {
					// editor floor slice: hard removal, dithered only at the
					// radius fringe
					discard;
				}
			}
		}
	}
	ALBEDO = use_vertex_color ? COLOR.rgb : albedo;
	ALPHA = alpha;
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
