shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.35;
uniform int bands : hint_range(2, 5) = 3;
uniform bool use_vertex_color = false;
// Sprite-artist palette trick: lit pixels lean warm, shadowed pixels lean cool.
uniform vec3 lit_tint : source_color = vec3(1.0, 0.97, 0.89);
uniform vec3 shadow_tint : source_color = vec3(0.78, 0.84, 1.0);
// Opt-in per material (world blocks yes, the character no).
uniform bool cutaway_affected = false;
// 1.0 = shade the whole mesh as if it faced straight up (sprite-style flat
// lighting). Kills normal-driven band flicker on animated models.
uniform float normal_flatten : hint_range(0.0, 1.0) = 0.0;
// Off = ignore cast shadows (use for characters — stops shadow-map shimmer).
uniform bool receive_shadows = true;
// Water material flag: dithers semi-transparent while the player is submerged.
uniform bool is_water = false;

// Driven from player.gd: 1.0 while the player is indoors / underwater.
global uniform float voxel_cutaway;
global uniform vec3 voxel_player_pos;
global uniform float voxel_water_reveal;
// Block-grid-aligned slice plane: indoors, everything above this is hidden.
// Snapped to integer Y so no block is ever half-cut — the remaining wall
// row shows clean block tops, like a dollhouse floor slice.
global uniform float voxel_cut_height;

// interleaved gradient noise — stable per-pixel screen-door pattern
float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	if (is_water && voxel_water_reveal > 0.001) {
		// semi-transparent water while swimming: drop ~55% of pixels
		if (ign(FRAGCOORD.xy) < voxel_water_reveal * 0.55) {
			discard;
		}
	}
	if (cutaway_affected && voxel_cutaway > 0.001) {
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		if (wp.y > voxel_cut_height + 0.01) {
			// full discard near the player (clean slice showing block tops),
			// dithering out only in a thin ring so distant roofs stay whole
			float dist = distance(wp.xz, voxel_player_pos.xz);
			float factor = (1.0 - smoothstep(10.0, 14.0, dist)) * voxel_cutaway;
			if (factor > 0.999) {
				discard;
			} else if (factor > 0.001 && ign(FRAGCOORD.xy) < factor) {
				discard;
			}
		}
	}
	ALBEDO = use_vertex_color ? COLOR.rgb : albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (normal_flatten > 0.001) {
		vec3 up_view = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		NORMAL = normalize(mix(NORMAL, up_view, normal_flatten));
	}
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	// Quantize into bands, but anti-alias the band edges so tiny normal
	// changes on rough voxel surfaces don't flicker between bands.
	float x = ndl * float(bands);
	float aa = clamp(fwidth(x), 0.001, 0.45);
	float stepped = clamp((floor(x) + smoothstep(0.5 - aa, 0.5 + aa, fract(x))) / float(bands), 0.0, 1.0);
	// Cast shadows snap toward the shadow band with a soft edge.
	float shadow = receive_shadows ? smoothstep(0.25, 0.75, ATTENUATION) : 1.0;
	float s = stepped * shadow;
	vec3 shade = mix(shadow_tint * (1.0 - shadow_strength), lit_tint, s);
	DIFFUSE_LIGHT = ALBEDO * shade;
}
