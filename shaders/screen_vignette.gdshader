shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float radius : hint_range(0.0, 1.0) = 0.18;
uniform float softness : hint_range(0.01, 1.0) = 0.74;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(vec2(centered_uv.x, centered_uv.y * 1.18));
	float mask = smoothstep(radius, radius + softness, dist);
	COLOR = vec4(vignette_color.rgb, vignette_color.a * mask * strength);
}
