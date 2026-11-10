shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 mirror_pos;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float mottling(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(grain(i), grain(i + vec2(1.0, 0.0)), f.x),
		mix(grain(i + vec2(0.0, 1.0)), grain(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	mirror_pos = VERTEX;
}

void fragment() {
	vec2 p = mirror_pos.zy;
	float border = smoothstep(0.30, 0.58, length(p));
	float bloom = smoothstep(0.46, 0.76, 0.56 * mottling(p * 15.0) + 0.44 * mottling(p * 51.0) + border * 0.16);
	float scratches = smoothstep(0.72, 0.98, mottling((p + p.yx * 0.07) * vec2(192.0, 7.0))) * 0.032;
	ALBEDO = mix(vec3(0.13, 0.149, 0.146), vec3(0.038, 0.068, 0.059), bloom) + scratches;
	METALLIC = mix(0.43, 0.15, bloom);
	ROUGHNESS = mix(0.61, 0.94, bloom);
	SPECULAR = 0.24;
}
