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

uniform vec2 uv_repeat = vec2(1.0);
uniform vec2 weathering_repeat = vec2(1.25, 1.0);
uniform vec3 material_tint : source_color = vec3(1.0);
uniform vec3 moss_tint : source_color = vec3(0.18, 0.22, 0.16);
uniform float albedo_gain : hint_range(0.5, 1.8) = 0.9;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.78;
uniform float wetness_amount : hint_range(0.0, 1.0) = 0.62;
uniform float moss_amount : hint_range(0.0, 1.0) = 0.3;
uniform float wet_roughness : hint_range(0.05, 0.65) = 0.34;
uniform float roughness_floor : hint_range(0.1, 1.0) = 0.48;
uniform float weathering_strength : hint_range(0.0, 1.0) = 0.55;
uniform float wall_root_dampness : hint_range(0.0, 1.0) = 0.68;
uniform float rain_streak_strength : hint_range(0.0, 1.0) = 0.42;
uniform float crack_strength : hint_range(0.0, 1.0) = 0.28;

varying vec2 instance_weathering_offset;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	// Shared wall materials receive a stable per-mesh offset, preventing the
	// same mold patch or paper remnant from lining up across every wall section.
	vec3 instance_origin = MODEL_MATRIX[3].xyz;
	instance_weathering_offset = vec2(
		hash21(instance_origin.xz + vec2(3.1, 7.7)),
		hash21(instance_origin.zy + vec2(11.4, 2.6))
	);
}

void fragment() {
	vec2 material_uv = UV * uv_repeat;
	vec3 base_color = texture(albedo_texture, material_uv).rgb * material_tint * albedo_gain;
	float height_value = texture(height_texture, material_uv).r;
	float wetness = smoothstep(0.18, 0.78, texture(wetness_texture, material_uv).r) * wetness_amount;
	float moss_dirt = smoothstep(0.26, 0.8, texture(moss_dirt_texture, material_uv).r) * moss_amount;
	float roughness_map = texture(roughness_texture, material_uv).r;
	float ao_map = texture(ao_texture, material_uv).r;

	vec2 weathering_uv = material_uv * weathering_repeat + instance_weathering_offset;
	vec3 weathering_color = texture(weathering_overlay, weathering_uv).rgb;
	float weathering_luma = dot(weathering_color, vec3(0.299, 0.587, 0.114));
	float aged_black_stain = 1.0 - smoothstep(0.20, 0.62, weathering_luma);
	float mold_bias = clamp((weathering_color.g - weathering_color.r * 0.78) * 2.4, 0.0, 1.0);
	float faded_paper = smoothstep(0.025, 0.16, weathering_color.r - weathering_color.b)
		* smoothstep(0.26, 0.64, weathering_luma);

	// Lower-wall moisture rises irregularly instead of forming a clean stripe.
	float root_shape = mix(0.72, 1.22, hash21(floor(weathering_uv * vec2(11.0, 3.0))));
	float wall_root = (1.0 - smoothstep(0.04, 0.39 * root_shape, UV.y)) * wall_root_dampness;
	float streak_sample = 1.0 - texture(weathering_overlay, weathering_uv * vec2(1.8, 0.48) + vec2(0.17, 0.31)).r;
	float rain_streak = smoothstep(0.44, 0.78, streak_sample) * rain_streak_strength
		* smoothstep(0.18, 0.92, UV.y);

	base_color *= mix(0.94, 1.04, height_value);
	base_color = mix(base_color, moss_tint, moss_dirt * 0.28);
	base_color *= mix(1.0, 0.88, wetness);
	base_color *= mix(1.0, 0.60, aged_black_stain * weathering_strength);
	base_color = mix(base_color, moss_tint * 0.72, mold_bias * weathering_strength * 0.24);
	base_color = mix(base_color, vec3(0.28, 0.21, 0.12), faded_paper * weathering_strength * 0.22);
	base_color *= mix(1.0, 0.54, clamp(wall_root + rain_streak * 0.42, 0.0, 1.0));

	vec3 normal_sample = texture(normal_texture, material_uv).rgb;
	normal_sample.xy = mix(vec2(0.5), normal_sample.xy, normal_strength);
	float height_edge = length(vec2(dFdx(height_value), dFdy(height_value)));
	float fine_crack = smoothstep(0.035, 0.12, height_edge) * crack_strength;
	base_color *= mix(1.0, 0.62, fine_crack);
	float surface_roughness = max(roughness_map, roughness_floor);
	float total_wetness = clamp(wetness + wall_root * 0.68 + rain_streak * 0.22, 0.0, 1.0);
	surface_roughness = mix(surface_roughness, wet_roughness, total_wetness);

	ALBEDO = base_color;
	NORMAL_MAP = normal_sample;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = clamp(surface_roughness, 0.08, 0.96);
	METALLIC = 0.0;
	SPECULAR = mix(0.42, 0.72, total_wetness);
	AO = mix(1.0, ao_map, 0.72);
}
