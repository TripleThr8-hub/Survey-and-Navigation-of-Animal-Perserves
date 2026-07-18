shader_type spatial;
render_mode unshaded, cull_front, blend_mix;
uniform sampler2D noise_texture;

uniform vec3 sky_color : source_color = vec3(0.01, 0.005, 0.02);
uniform vec3 cloud_dark : source_color = vec3(0.05, 0.02, 0.06);
uniform vec3 cloud_mid : source_color = vec3(0.3, 0.1, 0.3);
uniform vec3 cloud_bright : source_color = vec3(0.85, 0.75, 0.75);
uniform vec3 cloud_red : source_color = vec3(0.55, 0.1, 0.1);
uniform vec3 cloud_teal : source_color = vec3(0.2, 0.45, 0.45);

uniform float cloud_scale : hint_range(0.001, 0.05) = 0.005;
uniform float cloud_contrast : hint_range(0.5, 3.0) = 1.3;
uniform float accent_scale : hint_range(0.001, 0.05) = 0.013;
uniform float accent_strength : hint_range(0.0, 1.0) = 0.6;

uniform float radial_inner : hint_range(0.0, 200.0) = 30.0;
uniform float radial_outer : hint_range(0.0, 700.0) = 130.0;

uniform float alpha_start : hint_range(0.0, 1.0) = 0.15;
uniform float alpha_end : hint_range(0.0, 1.0) = 0.5;

// Drift controls -- direction + speed the clouds slowly scroll on their own
uniform vec2 scroll_direction = vec2(1.0, 0.3);
uniform float scroll_speed : hint_range(0.0, 0.05) = 0.004;

varying vec3 world_position;
varying vec2 local_xz;

void vertex()
{
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_xz = VERTEX.xz;
}

void fragment()
{
	vec2 scroll_offset = normalize(scroll_direction) * TIME * scroll_speed;
	
	vec2 uv = vec2(world_position.x, world_position.z) * cloud_scale + scroll_offset;
	float density = texture(noise_texture, uv).r;
	density = pow(clamp(density, 0.0, 1.0), cloud_contrast);
	
	float dist_from_center = length(local_xz);
	float radial_mask = 1.0 - smoothstep(radial_inner, radial_outer, dist_from_center);
	density *= radial_mask;
	
	vec3 color = sky_color;
	color = mix(color, cloud_dark, smoothstep(0.25, 0.42, density));
	color = mix(color, cloud_mid, smoothstep(0.42, 0.6, density));
	color = mix(color, cloud_bright, smoothstep(0.78, 0.92, density));
	
	// Accent noise scrolls too, at the same offset, so red/teal move with the clouds
	vec2 accent_uv = vec2(world_position.x, world_position.z) * accent_scale + scroll_offset;
	float accent_noise = texture(noise_texture, accent_uv).r;
	
	float in_cloud = smoothstep(0.32, 0.55, density);
	
	float teal_amount = (1.0 - smoothstep(0.3, 0.45, accent_noise)) * in_cloud * accent_strength;
	float red_amount = smoothstep(0.55, 0.7, accent_noise) * in_cloud * accent_strength;
	
	color = mix(color, cloud_teal, teal_amount);
	color = mix(color, cloud_red, red_amount);
	
	ALBEDO = color;
	ALPHA = smoothstep(alpha_start, alpha_end, density);
}