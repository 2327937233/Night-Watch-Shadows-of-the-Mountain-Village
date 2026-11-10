shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform float phase = 0.0;

void vertex() {
	// Camera-facing visual only; the candle, wick and light remain in world space.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float tip = clamp(UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * 3.2 + phase) * 0.006 * (1.0 - tip);
}

void fragment() {
	float height = 1.0 - UV.y;
	float center = 0.5 + sin(height * 5.0 + TIME * 2.1 + phase) * 0.045 * height;
	float width = 0.34 * pow(max(0.0, sin(height * 3.14159)), 0.85) * (1.0 - 0.55 * height);
	float edge = 1.0 - smoothstep(width * 0.5, width + 0.018, abs(UV.x - center));
	float ends = smoothstep(0.0, 0.09, height) * (1.0 - smoothstep(0.87, 1.0, height));
	float core = (1.0 - smoothstep(0.025, 0.11, abs(UV.x - center))) * (1.0 - smoothstep(0.25, 0.7, height));
	ALBEDO = mix(vec3(0.92, 0.40, 0.085), vec3(1.0, 0.83, 0.43), core);
	ALPHA = edge * ends * 0.88;
}
