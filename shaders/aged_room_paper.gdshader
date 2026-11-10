shader_type spatial;
render_mode diffuse_burley;

uniform vec3 paper_tint : source_color = vec3(0.62, 0.48, 0.27);
varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise21(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz + world_pos.y * vec2(0.49, 1.03);
	float stain = smoothstep(0.36, 0.78, noise21(p * 17.0) * 0.73 + noise21(p * 74.0) * 0.27);
	float fiber = noise21(p * vec2(480.0, 142.0));
	ALBEDO = paper_tint * (1.02 - stain * 0.40 + (fiber - 0.5) * 0.16);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
