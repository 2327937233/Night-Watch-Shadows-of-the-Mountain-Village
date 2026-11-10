shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 cloth_color : source_color = vec3(.40,.39,.37);
uniform float base_roughness = .96;
uniform float cut = 0.0;
varying float height_on_body;

float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float grain(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i),hash21(i + vec2(1,0)),f.x), mix(hash21(i + vec2(0,1)),hash21(i + vec2(1,1)),f.x), f.y);
}
void vertex() {
	height_on_body = VERTEX.y;
	float breathing = sin(TIME * 1.35) * .0019 * COLOR.g;
	VERTEX.z += breathing * sin(UV.x * 6.28318);
	VERTEX.y += breathing * .34;
	VERTEX.x += sin(TIME * .68 + UV.x * 9.0 + height_on_body * 4.0) * COLOR.r * .0018;
}
void fragment() {
	vec2 cloth = UV * vec2(2.0,1.4);
	float n = grain(cloth * 15.0) * .62 + grain(cloth * 47.0 + 7.4) * .38;
	float damp = (1.0 - smoothstep(.11,.44,height_on_body + grain(cloth * 7.8) * .085)) * step(1.5,cut);
	float old = smoothstep(.48,.79,grain(cloth * vec2(5.0,8.0) + 2.8)) * (.11 + .11 * damp);
	vec2 fibres = cloth * 211.0;
	vec2 filter_width = fwidth(fibres);
	float visible_fibres = 1.0 - smoothstep(.24,.82,max(filter_width.x,filter_width.y));
	vec2 thread = sin(fibres * 6.28318 + (n - .5) * 1.7) * visible_fibres;
	float seam = (1.0 - smoothstep(.0011,.005,abs(UV.x - .25))) * .065;
	float hem = mix(1.0, .86, (1.0 - smoothstep(.825,.853,height_on_body)) * step(.5,cut) * (1.0 - step(1.5,cut)));
	float cuff = (1.0 - smoothstep(.008,.030,abs(height_on_body - .850))) * step(.88,COLOR.b) * .12;
	ALBEDO = cloth_color * (0.86 + n * .22 + (thread.x + thread.y) * .022 - old - damp * .21 - seam - cuff) * hem;
	ROUGHNESS = base_roughness - damp * .04;
	SPECULAR = .11;
	NORMAL_MAP = vec3(.5 + thread.x * .042, .5 + thread.y * .037, 1.0);
	NORMAL_MAP_DEPTH = .4;
}
