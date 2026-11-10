shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 stone_color : source_color = vec3(0.055, 0.065, 0.07);
uniform float wetness : hint_range(0.0, 1.0) = 0.86;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 cell = floor(VERTEX.xz * 1.35);
	float grout_x = smoothstep(0.42, 0.49, abs(fract(VERTEX.x * 1.35) - 0.5));
	float grout_z = smoothstep(0.43, 0.49, abs(fract(VERTEX.z * 0.92) - 0.5));
	float grout = max(grout_x, grout_z);
	float variation = hash21(cell) * 0.035;
	ALBEDO = stone_color + variation - grout * 0.032;
	ROUGHNESS = mix(0.56, 0.12, wetness) + grout * 0.34;
	METALLIC = 0.04;
	SPECULAR = 0.9;
}
