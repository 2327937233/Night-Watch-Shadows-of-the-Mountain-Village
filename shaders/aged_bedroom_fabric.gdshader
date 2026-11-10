shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 fabric_tint : source_color = vec3(0.32, 0.27, 0.24);
uniform vec3 damp_tint : source_color = vec3(0.16, 0.17, 0.17);
uniform float weave_scale = 18.0;
uniform float damage_amount : hint_range(0.0, 1.0) = 0.35;
uniform float roughness_value : hint_range(0.4, 1.0) = 0.92;
uniform float faint_self_light : hint_range(0.0, 0.25) = 0.0;
uniform float hem_pattern : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying vec3 vertex_color;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_color = COLOR.rgb;
}

void fragment() {
	vec2 fibre = world_pos.xz * weave_scale + world_pos.y * vec2(5.1, 7.7);
	float warp = sin(fibre.x * 6.283) * 0.025;
	float weft = sin(fibre.y * 6.283) * 0.021;
	float discolor = noise21(world_pos.xz * 2.4 + world_pos.y * 1.1);
	float blotch = smoothstep(0.59, 0.82, noise21(world_pos.xz * 1.13 + world_pos.y * 0.77));
	vec3 color = fabric_tint * mix(0.78, 1.10, discolor) * (1.0 + warp + weft);
	color = mix(color, damp_tint, blotch * damage_amount * 0.52);
	// Worn woven edging, attached to the curtain UV so it follows the folds.
	float hem = (1.0 - smoothstep(0.005, 0.014, abs(UV.y - 0.89))) +
		(1.0 - smoothstep(0.005, 0.012, abs(UV.y - 0.96)));
	vec2 stitch = vec2(fract(UV.x * 8.0) - 0.5, (UV.y - 0.926) * 10.0);
	float chain = 1.0 - smoothstep(0.028, 0.09, abs(abs(stitch.x) + abs(stitch.y) - 0.22));
	float faded_thread = (hem * 0.42 + chain * 0.52) * hem_pattern * mix(0.24, 0.76, discolor);
	color = mix(color, vec3(0.29, 0.20, 0.14), faded_thread);
	ALBEDO = max(color * vertex_color, vec3(0.025));
	EMISSION = ALBEDO * faint_self_light;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.32;
}
