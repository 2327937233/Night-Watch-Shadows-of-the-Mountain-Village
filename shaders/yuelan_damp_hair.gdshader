shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

void vertex() {
	// Hair ends move a millimetre or two; the roots remain on the bowed cap.
	float end_weight = COLOR.r * (1.0 - smoothstep(1.16,1.54,VERTEX.y));
	VERTEX.x += sin(TIME * .79 + UV.x * 3.2 + UV.y * 5.0) * .0022 * end_weight;
	VERTEX.z += cos(TIME * .61 + UV.x * 4.1) * .0010 * end_weight;
}
void fragment() {
	float fibres = UV.x * 40.0 + sin(UV.y * 17.0) * .14;
	float visible_fibres = 1.0 - smoothstep(.30,.82,fwidth(fibres));
	float grain = sin(fibres * 6.28318) * visible_fibres;
	float tint = .78 + .23 * COLOR.g + grain * .085;
	ALBEDO = vec3(.016,.0145,.014) * tint;
	ROUGHNESS = .83 + grain * .042;
	SPECULAR = .15;
}
