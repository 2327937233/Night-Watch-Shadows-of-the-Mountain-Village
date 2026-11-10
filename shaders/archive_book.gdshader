shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 cover_tint : source_color = vec3(0.24, 0.18, 0.13);
uniform vec3 page_tint : source_color = vec3(0.52, 0.40, 0.27);
uniform vec3 half_extents = vec3(0.14, 0.16, 0.03);
uniform bool right_shelf = false;

varying vec3 book_pos;
varying vec3 book_normal;
varying vec3 world_pos;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	book_pos = VERTEX / half_extents;
	book_normal = NORMAL;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float top = abs(book_normal.y);
	float side = abs(book_normal.x);
	float spine = step(0.8, book_normal.x * (right_shelf ? -1.0 : 1.0));
	float paper_block = max(top, side * (1.0 - spine)) * (1.0 - smoothstep(0.82, 0.99, abs(book_pos.z)));
	float age = grain(world_pos.xz * 18.0 + vec2(world_pos.y * 14.0, -world_pos.y * 11.0));
	float fine = grain(UV * 250.0);
	float layers = sin(book_pos.z * 120.0 + sin(book_pos.x * 9.0) * 0.85) * 0.055;
	vec3 cloth = cover_tint * mix(0.57, 1.17, age) * mix(0.86, 1.13, fine);
	float edge_wear = smoothstep(0.82, 0.98, max(abs(book_pos.y), abs(book_pos.z)));
	cloth = mix(cloth, page_tint * 0.61, edge_wear * smoothstep(0.36, 0.74, age) * 0.42);
	float stitches = 1.0 - smoothstep(0.018, 0.048, abs(abs(book_pos.z) - 0.68));
	stitches *= 1.0 - smoothstep(0.043, 0.11, abs(fract((book_pos.y + 1.0) * 2.1) - 0.5));
	cloth = mix(cloth, page_tint * 0.75, spine * stitches * 0.6);
	vec3 paper = page_tint * (mix(0.56, 0.98, age) + layers);
	ALBEDO = mix(cloth, paper, paper_block);
	ROUGHNESS = 0.91;
	SPECULAR = 0.22;
}
