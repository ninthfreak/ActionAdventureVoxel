shader_type spatial;
// Placement preview: the block in full color, unshaded and see-through, so
// it reads unmistakably as a "ghost" of what will be placed.
render_mode unshaded, cull_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform bool use_vertex_color = false;
uniform sampler2D albedo_tex : filter_nearest;
uniform bool use_texture = false;
uniform float alpha : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec3 c = use_texture ? texture(albedo_tex, UV).rgb : (use_vertex_color ? COLOR.rgb : albedo);
	ALBEDO = c;
	ALPHA = alpha;
}
