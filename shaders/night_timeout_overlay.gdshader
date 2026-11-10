shader_type canvas_item;
render_mode unshaded;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float lightning : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.77778;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
		mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 st = UV;
	vec2 centered = (st - vec2(0.5)) * 2.0;
	float age = noise2(st * vec2(16.0, 12.0)) * 0.64 + noise2(st * 101.0) * 0.36;
	float grain = hash21(FRAGCOORD.xy) - 0.5;
	float rim = max(abs(centered.x) * 0.95, abs(centered.y));
	float edge = smoothstep(0.49, 1.08, rim + (age - 0.5) * 0.17);
	float vignette = smoothstep(0.29, 1.37, length(centered * vec2(0.98, 0.88)));
	float title_shadow = 1.0 - smoothstep(0.04, 0.58, length((st - vec2(0.5, 0.276)) * vec2(1.45, 1.1)));
	float footer_shadow = smoothstep(0.62, 1.0, st.y) * 0.11;
	vec2 seal = (st - vec2(0.5, 0.259)) * vec2(aspect, 1.0);
	float direction = atan(seal.y, seal.x);
	float radius = length(seal);
	float broken_ink = noise2(vec2(direction * 13.0, radius * 211.0)) * 0.7 + grain * 0.3;
	float ring_center = 0.114 + sin(direction * 4.0 + 0.6) * 0.004 + sin(direction * 11.0) * 0.002;
	float brush = (1.0 - smoothstep(0.003, 0.012, abs(radius - ring_center)))
		* smoothstep(0.25, 0.58, broken_ink) * smoothstep(-0.97, -0.62, cos(direction - 0.85));
	float red = max(edge * (0.70 + age * 0.32), brush * 0.40);
	vec3 color = mix(vec3(0.015, 0.012, 0.012), vec3(0.24, 0.035, 0.022), red);
	color += grain * edge * 0.043;
	float dim = 0.24 + vignette * 0.28 + title_shadow * 0.19 + edge * 0.30 + footer_shadow;
	dim = max(dim, brush * 0.62);
	color = mix(color, vec3(0.57, 0.67, 0.81), lightning * 0.77);
	COLOR = vec4(color, max(clamp(dim * reveal, 0.0, 0.91), lightning * 0.41));
}
