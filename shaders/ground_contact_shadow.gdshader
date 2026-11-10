shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 shadow_color : source_color = vec4(0.005, 0.007, 0.009, 0.38);
uniform float motion : hint_range(0.0, 1.0) = 0.0;
uniform float stride_phase : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * vec2(2.0, 2.0);
	float body_distance = length(point / vec2(1.0, 0.68));
	float body = 1.0 - smoothstep(0.18, 1.0, body_distance);

	// Two low-opacity contact lobes follow the walk cycle. They keep the boots
	// attached to the wet ground without creating the hard detached oval that a
	// single billboard shadow produces.
	float stride = sin(stride_phase * 6.2831853) * 0.20 * motion;
	vec2 foot_a_point = (point - vec2(-0.19, stride)) / vec2(0.42, 0.28);
	vec2 foot_b_point = (point - vec2(0.19, -stride)) / vec2(0.42, 0.28);
	float foot_a = 1.0 - smoothstep(0.28, 1.0, length(foot_a_point));
	float foot_b = 1.0 - smoothstep(0.28, 1.0, length(foot_b_point));
	float contact = max(foot_a, foot_b) * mix(0.32, 0.58, motion);
	float fade = max(body * mix(1.0, 0.78, motion), contact);
	ALBEDO = shadow_color.rgb;
	ALPHA = fade * shadow_color.a;
}
