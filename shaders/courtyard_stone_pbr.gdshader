shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wetness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D puddle_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_dirt_texture : filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec2 tile_repeat = vec2(2.5, 3.0);
uniform vec3 stone_tint : source_color = vec3(0.86, 0.92, 0.98);
uniform vec3 moss_tint : source_color = vec3(0.18, 0.23, 0.17);
uniform vec3 dirt_tint : source_color = vec3(0.19, 0.15, 0.12);
uniform float albedo_gain : hint_range(0.5, 2.0) = 1.24;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.82;
uniform float height_scale : hint_range(0.0, 0.08) = 0.028;
uniform float wetness_amount : hint_range(0.0, 1.0) = 0.82;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.72;
uniform float moss_dirt_amount : hint_range(0.0, 1.0) = 0.36;
uniform float dry_roughness_floor : hint_range(0.0, 1.0) = 0.58;
uniform float wet_roughness : hint_range(0.0, 1.0) = 0.31;
uniform float puddle_roughness : hint_range(0.0, 1.0) = 0.11;
uniform float puddle_threshold : hint_range(0.0, 1.0) = 0.16;
uniform float color_variation : hint_range(0.0, 0.25) = 0.075;

varying vec3 ground_position;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 value) {
	vec2 cell = floor(value);
	vec2 fraction = fract(value);
	vec2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
}

void vertex() {
	vec2 stone_uv = UV * tile_repeat;
	float height_value = textureLod(height_texture, stone_uv, 0.0).r;
	float puddle_value = textureLod(puddle_texture, stone_uv, 0.0).r;
	float puddle_flattening = 1.0 - smoothstep(puddle_threshold, puddle_threshold + 0.13, puddle_value) * 0.5;
	VERTEX.y += (height_value - 0.52) * height_scale * puddle_flattening;
	ground_position = VERTEX;
}

void fragment() {
	vec2 stone_uv = UV * tile_repeat;
	vec3 base_color = texture(albedo_texture, stone_uv).rgb * stone_tint * albedo_gain;
	float roughness_map = texture(roughness_texture, stone_uv).r;
	float ao_map = texture(ao_texture, stone_uv).r;
	float wetness_map = texture(wetness_texture, stone_uv).r;
	float puddle_map = texture(puddle_texture, stone_uv).r;
	float moss_dirt_map = texture(moss_dirt_texture, stone_uv).r;

	float wetness = smoothstep(0.13, 0.68, wetness_map) * wetness_amount;
	float puddle = smoothstep(puddle_threshold, puddle_threshold + 0.13, puddle_map) * puddle_amount;
	float moss_dirt = smoothstep(0.16, 0.78, moss_dirt_map) * moss_dirt_amount;
	float broad_variation = value_noise(ground_position.xz * 0.31);
	base_color *= mix(1.0 - color_variation, 1.0 + color_variation, broad_variation);

	float moss_bias = smoothstep(0.36, 0.8, moss_dirt_map);
	vec3 weather_tint = mix(dirt_tint, moss_tint, moss_bias);
	base_color = mix(base_color, weather_tint, moss_dirt * 0.38);
	base_color *= mix(1.0, 0.82, wetness);
	base_color = mix(base_color, base_color * vec3(0.76, 0.84, 0.9), puddle * 0.55);

	vec3 normal_sample = texture(normal_texture, stone_uv).rgb;
	normal_sample.xy = mix(vec2(0.5), normal_sample.xy, normal_strength);
	float rain_ripple = sin((stone_uv.x * 31.0 + stone_uv.y * 19.0) + TIME * 3.2);
	rain_ripple *= sin((stone_uv.x * 13.0 - stone_uv.y * 27.0) - TIME * 2.6);
	normal_sample.xy += vec2(rain_ripple, -rain_ripple) * 0.006 * puddle;

	float dry_roughness = max(roughness_map, dry_roughness_floor);
	float surface_roughness = mix(dry_roughness, wet_roughness, wetness);
	surface_roughness = mix(surface_roughness, puddle_roughness, puddle);

	ALBEDO = base_color;
	NORMAL_MAP = normal_sample;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = clamp(surface_roughness, 0.07, 0.94);
	METALLIC = 0.0;
	SPECULAR = mix(0.46, 0.88, max(wetness, puddle));
	AO = mix(1.0, ao_map, 0.78);
}
