shader_type spatial;
render_mode unshaded, cull_front, blend_mix;
uniform sampler2D noise_texture;

//
// Sky colors
//
uniform vec3 sky_color : source_color = vec3(0.01, 0.005, 0.02);
uniform vec3 cloud_dark : source_color = vec3(0.05, 0.02, 0.06);
uniform vec3 cloud_mid : source_color = vec3(0.3, 0.1, 0.3);
uniform vec3 cloud_bright : source_color = vec3(0.85, 0.8, 0.8);
uniform vec3 cloud_red : source_color = vec3(0.6, 0.08, 0.08);
uniform vec3 cloud_teal : source_color = vec3(0.1, 0.5, 0.5);

//
// Cloud controls
//
uniform float cloud_scale = 0.0025;
uniform float cloud_contrast = 1.4;
uniform float warp_strength = 0.6;
uniform float scroll_speed = 0.003;

varying vec3 world_position;

void vertex()
{
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float sample_noise(vec2 uv)
{
	return texture(noise_texture, uv).r;
}

// Fractal noise: layers multiple frequencies for wispy detail
float fbm(vec2 uv)
{
	float value = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 4; i++)
	{
		value += amp * sample_noise(uv * freq);
		freq *= 2.17; // irrational-ish multiplier avoids visible tiling
		amp *= 0.5;
	}
	return value;
}

void fragment()
{
	vec2 base_uv = vec2(world_position.x, world_position.z) * cloud_scale;
	base_uv += TIME * scroll_speed;

	// Domain warp: distort the sampling coords with noise for organic swirls
	vec2 warp = vec2(
		fbm(base_uv + vec2(1.7, 9.2)),
		fbm(base_uv + vec2(8.3, 2.8))
	);
	vec2 warped_uv = base_uv + (warp - 0.5) * warp_strength;

	float density = fbm(warped_uv);
	density = pow(clamp(density, 0.0, 1.0), cloud_contrast);

	//
	// Smooth color blending instead of hard bands
	//
	vec3 color = mix(sky_color, cloud_dark, smoothstep(0.2, 0.45, density));
	color = mix(color, cloud_mid, smoothstep(0.45, 0.65, density));
	color = mix(color, cloud_bright, smoothstep(0.78, 0.92, density));

	// Independent red/teal accent patches, masked to only show inside cloud areas
	float red_mask = fbm(warped_uv * 1.3 + vec2(23.1, 7.7));
	float teal_mask = fbm(warped_uv * 1.6 + vec2(-14.4, 31.2));
	float in_cloud = smoothstep(0.3, 0.6, density);

	color = mix(color, cloud_red, smoothstep(0.62, 0.85, red_mask) * in_cloud);
	color = mix(color, cloud_teal, smoothstep(0.62, 0.85, teal_mask) * in_cloud);

	ALBEDO = color;

	//
	// Soft corner/edge fade
	//
	float edge_x = smoothstep(0.0,0.15,UV.x) * smoothstep(0.0,0.15,1.0-UV.x);
	float edge_y = smoothstep(0.0,0.15,UV.y) * smoothstep(0.0,0.15,1.0-UV.y);
	ALPHA = max(edge_x * edge_y, 0.05);
}