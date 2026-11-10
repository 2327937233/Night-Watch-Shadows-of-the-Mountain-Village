shader_type canvas_item;

uniform vec2 scroll_speed = vec2(-0.035, 0.55);
uniform float rain_alpha : hint_range(0.0, 1.0) = 0.30;

void fragment() {
	vec2 moving_uv = fract(UV + scroll_speed * TIME);
	vec4 rain = texture(TEXTURE, moving_uv);
	COLOR = vec4(rain.rgb, rain.a * rain_alpha);
}
