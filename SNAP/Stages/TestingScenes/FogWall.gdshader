shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 fog_color : source_color = vec4(0.8,0.85,0.9,0.6);
uniform sampler2D noise_tex;

void fragment() {

    vec2 uv = UV;

    uv.x += TIME * 0.03;

    float noise = texture(noise_tex, uv * 2.5).r;

    ALBEDO = fog_color.rgb;

    ALPHA = fog_color.a * noise;
}