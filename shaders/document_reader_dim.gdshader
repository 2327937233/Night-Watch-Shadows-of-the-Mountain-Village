shader_type canvas_item;

uniform sampler2D scene_screen : hint_screen_texture, filter_linear_mipmap;
uniform vec3 night_tint : source_color = vec3(0.014, 0.012, 0.010);
uniform float darkness : hint_range(0.0, 1.0) = 0.69;
uniform float blur_lod : hint_range(0.0, 5.0) = 2.5;

void fragment() {
	vec3 blurred = textureLod(scene_screen, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(blurred, night_tint, darkness), 1.0);
}
