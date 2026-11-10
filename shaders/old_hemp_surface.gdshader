shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 room_pos;

void vertex() {
	room_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float winding = UV.x * 3.0 + room_pos.y * 16.0 + room_pos.x * 5.3;
	float strand = sin(winding * 6.283);
	float fibers = sin(UV.x * 176.0 + room_pos.y * 84.0 + strand) *
		sin(room_pos.y * 187.0 + UV.x * 25.0);
	float wear = sin(room_pos.y * 37.0 + room_pos.z * 48.0) * 0.055;
	ALBEDO = vec3(0.173, 0.113, 0.064) * (0.93 + 0.16 * strand + 0.095 * fibers + wear);
	ROUGHNESS = 0.90 + strand * 0.048;
	SPECULAR = 0.23;
}
