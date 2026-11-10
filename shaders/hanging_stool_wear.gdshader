shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform bool worn_leg = false;
varying vec3 surface_pos;
varying vec3 surface_normal;

float grain(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 h = fract(sin(vec4(dot(c, vec2(23.71, 71.13)), dot(c + vec2(1,0), vec2(23.71, 71.13)),
		dot(c + vec2(0,1), vec2(23.71, 71.13)), dot(c + vec2(1), vec2(23.71, 71.13)))) * 9137.67);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

void vertex() {
	surface_pos = VERTEX;
	surface_normal = NORMAL;
}

void fragment() {
	if (worn_leg) {
		float across = surface_pos.x + surface_pos.z;
		float chips = grain(vec2(across * 225.0, surface_pos.y * 48.0));
		float end_wear = 1.0 - smoothstep(-0.305, -0.215, surface_pos.y);
		ALBEDO = mix(vec3(0.16, 0.105, 0.064), vec3(0.30, 0.22, 0.15), chips);
		ALPHA = end_wear * smoothstep(0.29, 0.78, chips) * 0.69;
	} else {
		vec2 p = surface_pos.xz;
		float islands = grain(p * 10.0 + vec2(2.3, 0.7));
		float flecks = grain(p * 232.0);
		float corner = smoothstep(0.12, 0.37, length(p + vec2(-0.05, 0.045)));
		ALBEDO = mix(vec3(0.17, 0.15, 0.12), vec3(0.27, 0.25, 0.21), flecks);
		ALPHA = step(0.5, surface_normal.y) * (0.09 + corner * 0.13) * smoothstep(0.24, 0.81, islands * 0.71 + flecks * 0.29);
	}
	ROUGHNESS = 0.97;
	SPECULAR = 0.12;
}
