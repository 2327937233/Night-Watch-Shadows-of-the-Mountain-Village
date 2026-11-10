shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wetness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_dirt_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 tile_repeat = vec2(0.92, 0.82);
uniform vec3 brick_tint : source_color = vec3(0.48, 0.53, 0.55);
uniform vec3 damp_tint : source_color = vec3(0.15, 0.20, 0.21);
uniform float albedo_gain : hint_range(0.5, 1.8) = 0.92;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.72;
uniform float wetness_amount : hint_range(0.0, 1.0) = 0.48;
uniform float side_dampness : hint_range(0.0, 1.0) = 0.38;
// Off by default in every other room. The hall encounter enables this only
// after the figure is hidden; wet marks share the brick's normals and joints.
uniform bool yuelan_footprints_active = false;
uniform vec4 yuelan_footprints[4];
uniform int yuelan_trail_count = 0;
uniform vec4 yuelan_trail[96];
uniform vec4 yuelan_trail_bounds = vec4(0.0);
uniform float yuelan_return_fade_seconds = -1.0;
uniform bool yuelan_return_hanging = false;
uniform vec2 yuelan_shoe_size = vec2(0.108, 0.236);
uniform float yuelan_water_contrast = 0.67;
// Second-visit stool scuffs use the original bricks' normals and joints.
// Default off, so all other rooms and the first visit remain unchanged.
uniform bool hanging_stool_drag_active = false;
uniform vec4 hanging_stool_drag_lines[4];

varying vec2 instance_offset;
varying float instance_value;
varying vec3 world_position;
varying float top_surface;

float hash21(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453123);
}

float wet_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float soft_shoe_mark(vec2 ground, vec4 mark, float mirror_side) {
	vec2 p = ground - mark.xy;
	float c = cos(mark.z), s = sin(mark.z);
	p = mat2(vec2(c, -s), vec2(s, c)) * p;
	// 24 cm long, 10-11 cm wide: round cloth toe, narrow heel, slight instep.
	p /= yuelan_shoe_size * 0.5;
	p.x *= mirror_side;
	float toe = length((p - vec2(-0.045, -0.32)) / vec2(0.95, 0.74)) - 1.0;
	float sole = length(p / vec2(0.80, 0.91)) - 1.0;
	float heel = length((p - vec2(0.02, 0.57)) / vec2(0.64, 0.42)) - 1.0;
	float edge = min(toe, min(sole, heel));
	edge += exp(-pow(p.y * 2.8, 2.0)) * smoothstep(0.12, 0.85, p.x) * 0.17;
	float grain = wet_noise(ground * 168.0);
	edge += (grain - 0.5) * 0.13;
	float core = 1.0 - smoothstep(-0.055, 0.13, edge);
	float seep = (1.0 - smoothstep(0.02, 0.31, edge)) * 0.12;
	float absorption = mix(0.82, 1.0, wet_noise(ground * 62.0 + 4.7));
	return max(core, seep) * absorption * mark.w;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	instance_value = hash21(origin.xz * 3.7 + vec2(2.4, 8.1));
	instance_offset = vec2(hash21(origin.xz + 1.7), hash21(origin.zx + 9.3)) * 1.9;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top_surface = step(0.7, NORMAL.y);
}

void fragment() {
	vec2 sample_uv = UV * tile_repeat + instance_offset;
	vec3 base = texture(albedo_texture, sample_uv).rgb * brick_tint * albedo_gain;
	float roughness_map = texture(roughness_texture, sample_uv).r;
	float ao = texture(ao_texture, sample_uv).r;
	float wet_map = texture(wetness_texture, sample_uv).r;
	float dirt_map = texture(moss_dirt_texture, sample_uv).r;

	// The walked centre remains slightly drier and clearer; moisture gathers
	// beside the walls and toward the abandoned altar end.
	float side = smoothstep(1.20, 2.48, abs(world_position.x));
	float rear = 1.0 - smoothstep(-10.8, -4.0, world_position.z);
	float wetness = clamp(smoothstep(0.22, 0.72, wet_map) * wetness_amount + side * side_dampness + rear * 0.12, 0.0, 0.86);
	float dirt = smoothstep(0.24, 0.76, dirt_map) * mix(0.18, 0.42, max(side, rear));
	base *= mix(0.90, 1.06, instance_value);
	base = mix(base, damp_tint, wetness * 0.20 + dirt * 0.22);
	float aisle = 1.0 - smoothstep(0.55, 1.50, abs(world_position.x));
	base *= mix(1.0, 1.045, aisle);

	vec3 normal_sample = texture(normal_texture, sample_uv).rgb;
	normal_sample.xy = mix(vec2(0.5), normal_sample.xy, normal_strength);
	float roughness = max(roughness_map, 0.62);
	roughness = mix(roughness, 0.34, wetness);
	float shoe_wetness = 0.0;
	if (yuelan_footprints_active && top_surface > 0.5 && abs(world_position.x + 3.90) < 0.75 && abs(world_position.z + 6.54) < 0.75) {
		for (int i = 0; i < 4; i++) {
			float remaining = 1.0 - smoothstep(8.0 + float(i) * 0.45, 12.2 + float(i) * 0.45, yuelan_return_fade_seconds);
			shoe_wetness = max(shoe_wetness, soft_shoe_mark(world_position.xz, yuelan_footprints[i], (i == 0 || i == 2) ? -1.0 : 1.0) * remaining);
		}
	}
	if (yuelan_footprints_active && top_surface > 0.5 && yuelan_trail_count > 0 &&
		world_position.x > yuelan_trail_bounds.x && world_position.z > yuelan_trail_bounds.y &&
		world_position.x < yuelan_trail_bounds.z && world_position.z < yuelan_trail_bounds.w) {
		for (int i = 0; i < yuelan_trail_count; i++) {
			vec4 mark = yuelan_trail[i];
			// Only evaluate absorption noise near an actual sole; the rest of
			// the room pays for four bounds checks, not 96 noise samples.
			if (abs(world_position.x - mark.x) < 0.18 && abs(world_position.z - mark.y) < 0.18) {
				float fraction = float(i) / max(1.0, float(yuelan_trail_count - 1));
				float delay = yuelan_return_hanging ? fraction * 2.0 : (1.0 - fraction) * 7.7;
				float remaining = 1.0 - smoothstep(delay - 1.3, delay + 3.1, yuelan_return_fade_seconds);
				if (yuelan_return_fade_seconds < 0.0) {
					remaining = 1.0;
				}
				shoe_wetness = max(shoe_wetness, soft_shoe_mark(world_position.xz, mark, i % 2 == 0 ? -1.0 : 1.0) * remaining);
			}
		}
	}
	base *= 1.0 - yuelan_water_contrast * shoe_wetness;
	roughness = mix(roughness, 0.29, shoe_wetness * 0.55);
	if (hanging_stool_drag_active && top_surface > 0.5 &&
		world_position.x > -0.1 && world_position.x < 1.2 &&
		world_position.z > -4.8 && world_position.z < -3.6) {
		float scuff = 0.0;
		for (int i = 0; i < 4; i++) {
			vec4 line = hanging_stool_drag_lines[i];
			vec2 segment = line.zw - line.xy;
			float t = clamp(dot(world_position.xz - line.xy, segment) / max(dot(segment, segment), 0.00001), 0.0, 1.0);
			float d = length(world_position.xz - line.xy - segment * t);
			float grain = wet_noise(world_position.xz * 180.0);
			scuff = max(scuff, (1.0 - smoothstep(0.003, 0.016, d)) * mix(0.35, 0.85, grain));
		}
		base = mix(base, base * 1.22 + vec3(0.009, 0.008, 0.006), scuff);
		roughness = mix(roughness, 0.86, scuff * 0.6);
	}

	ALBEDO = base;
	NORMAL_MAP = normal_sample;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = clamp(roughness, 0.28, 0.94);
	METALLIC = 0.0;
	SPECULAR = min(0.64, mix(0.40, 0.60, wetness) + shoe_wetness * 0.055);
	AO = mix(1.0, ao, 0.62);
}
