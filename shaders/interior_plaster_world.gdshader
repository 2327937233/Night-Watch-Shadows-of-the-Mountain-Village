shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wetness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_dirt_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D weathering_overlay : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec2 world_tile_scale = vec2(0.43, 0.52);
uniform vec3 plaster_tint : source_color = vec3(0.57, 0.565, 0.52);
uniform vec3 damp_tint : source_color = vec3(0.105, 0.125, 0.115);
uniform float albedo_gain : hint_range(0.5, 1.5) = 0.96;
uniform float minimum_base_brightness : hint_range(0.0, 0.6) = 0.0;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.38;
uniform float weathering_strength : hint_range(0.0, 1.0) = 0.62;
uniform float root_dampness : hint_range(0.0, 1.0) = 0.72;
uniform float streak_strength : hint_range(0.0, 1.0) = 0.46;
uniform float wet_roughness : hint_range(0.15, 0.7) = 0.42;
uniform float dry_roughness_floor : hint_range(0.35, 1.0) = 0.72;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	// The room is assembled from long axis-aligned wall boxes. Projecting in
	// world metres keeps the same texel density on every wall and inset bay.
	vec3 facing = abs(world_normal);
	vec2 wall_meters = facing.x > facing.z
		? vec2(world_position.z, world_position.y)
		: vec2(world_position.x, world_position.y);
	vec2 detail_uv = wall_meters * world_tile_scale;

	vec3 base_sample = texture(albedo_texture, detail_uv).rgb;
	// Optional study-room-only floor for crushed-black source plaster patches.
	base_sample = max(base_sample, vec3(minimum_base_brightness));
	float height_value = texture(height_texture, detail_uv).r;
	float roughness_map = texture(roughness_texture, detail_uv).r;
	float ao_map = texture(ao_texture, detail_uv).r;
	float wet_map = texture(wetness_texture, detail_uv).r;
	float moss_map = texture(moss_dirt_texture, detail_uv).r;

	// Large stains use a deliberately different physical scale. They remain
	// continuous between wall modules without becoming repeated horizontal bars.
	vec2 broad_uv = wall_meters * vec2(0.105, 0.17) + vec2(0.31, 0.57);
	vec3 broad_weather = texture(weathering_overlay, broad_uv).rgb;
	float broad_luma = dot(broad_weather, vec3(0.299, 0.587, 0.114));
	float block_mold = 1.0 - smoothstep(0.20, 0.62, broad_luma);
	float green_mold = clamp((broad_weather.g - broad_weather.r * 0.76) * 2.1, 0.0, 1.0);

	// Moisture height is evaluated in metres rather than each mesh's local UV.
	float root_noise = texture(weathering_overlay, vec2(wall_meters.x * 0.18, 0.23)).g;
	float root_height = mix(0.34, 0.82, root_noise);
	float root_mask = (1.0 - smoothstep(root_height, root_height + 0.44, world_position.y)) * root_dampness;

	// Tall narrow streaks are broken up at two scales and never span the whole bay.
	float streak_noise = 1.0 - texture(weathering_overlay,
		vec2(wall_meters.x * 0.92 + 0.17, world_position.y * 0.115 + 0.41)).r;
	float streak_breakup = texture(weathering_overlay,
		vec2(wall_meters.x * 0.21 + 0.73, world_position.y * 0.47)).g;
	float rain_streak = smoothstep(0.56, 0.82, streak_noise)
		* smoothstep(0.32, 0.66, streak_breakup)
		* smoothstep(0.62, 1.25, world_position.y)
		* streak_strength;

	float map_wetness = smoothstep(0.34, 0.78, wet_map) * 0.38;
	float mold = clamp(block_mold * 0.58 + green_mold * 0.34 + smoothstep(0.55, 0.88, moss_map) * 0.18, 0.0, 1.0);
	float total_damp = clamp(root_mask + rain_streak * 0.50 + map_wetness, 0.0, 1.0);

	vec3 base_color = base_sample * plaster_tint * albedo_gain;
	base_color *= mix(0.94, 1.05, height_value);
	base_color = mix(base_color, damp_tint, mold * weathering_strength * 0.42);
	base_color *= mix(1.0, 0.74, total_damp);
	// Preserve material information in shadow: no generated stain reaches black.
	base_color = max(base_color, vec3(0.032, 0.036, 0.034));

	vec3 normal_sample = texture(normal_texture, detail_uv).rgb;
	normal_sample.xy = mix(vec2(0.5), normal_sample.xy, normal_strength);
	float roughness = max(roughness_map, dry_roughness_floor);
	roughness = mix(roughness, wet_roughness, total_damp);

	ALBEDO = base_color;
	NORMAL_MAP = normal_sample;
	NORMAL_MAP_DEPTH = 0.72;
	ROUGHNESS = clamp(roughness, 0.18, 0.96);
	METALLIC = 0.0;
	SPECULAR = mix(0.38, 0.54, total_damp);
	AO = mix(1.0, ao_map, 0.55);
}
