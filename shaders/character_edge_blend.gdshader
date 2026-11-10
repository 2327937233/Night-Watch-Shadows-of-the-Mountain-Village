shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D frame_texture : source_color, filter_linear, repeat_disable;
uniform vec4 character_tint : source_color = vec4(1.0);

void vertex() {
	// Match SpriteBase3D's full billboard while preserving the sprite's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0] *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1] *= length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX[2] *= length(MODEL_MATRIX[2].xyz);
}

void fragment() {
	vec4 sample_color = texture(frame_texture, UV);
	vec2 texel = 1.0 / vec2(textureSize(frame_texture, 0));
	// Source sheets carry a pale cutout line around trousers and soles.
	// Examine only a two-pixel silhouette band, never blur across the leg gap.
	float neighbor_alpha = 1.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			neighbor_alpha = min(neighbor_alpha, texture(frame_texture, UV + vec2(float(x), float(y)) * texel * 2.0).a);
		}
	}
	float legs = smoothstep(0.62, 0.67, UV.y);
	float edge = (1.0 - smoothstep(0.10, 0.90, neighbor_alpha)) * legs;
	vec3 subdued = min(sample_color.rgb * 0.38, vec3(0.055, 0.065, 0.074));
	ALBEDO = mix(sample_color.rgb, subdued, edge * 0.90) * character_tint.rgb;
	ALPHA = sample_color.a * character_tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.16;
}
