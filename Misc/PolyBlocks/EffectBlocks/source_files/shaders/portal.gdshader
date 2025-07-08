shader_type spatial;
render_mode blend_mix,cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D gradient_texture;

uniform sampler2D noise_texture : hint_normal;

uniform float rotation_speed = 1.0;
uniform float noise_strength = 0.2;
uniform float noise_scale = 4.0;
uniform float displacement_strength = 0.03;
uniform float glow_strength = 2.0;
uniform vec4 inner_glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 outer_glow_color : source_color = vec4(0.5, 0.5, 1.0, 1.0);
uniform float inner_radius = 0.3;
uniform float edge_softness = 0.2;
uniform float noise_time_scale = 0.2;

varying vec2 uv_var;
varying float radius_var;

void vertex() {
    uv_var = UV;

    radius_var = 1.0 - UV.y;

    float time = TIME * noise_time_scale;
    vec2 noise_uv = UV * noise_scale + vec2(sin(time * 0.7), cos(time * 0.5)) * 0.3;
    float noise_val = texture(noise_texture, noise_uv).r * 2.0 - 1.0;


    float edge_factor = smoothstep(inner_radius, 1.0, radius_var);

    VERTEX += NORMAL * noise_val * displacement_strength * edge_factor;
}

void fragment() {
    float rotation = TIME * rotation_speed;
    float cos_rot = cos(rotation);
    float sin_rot = sin(rotation);

    float radius = radius_var;

    vec2 noise_uv = uv_var * noise_scale + vec2(cos(TIME * 0.5), sin(TIME * 0.7)) * 0.2;
    float noise_val = texture(noise_texture, noise_uv).r;
    radius += (noise_val * 2.0 - 1.0) * noise_strength * smoothstep(0.0, 0.8, radius);

    radius = clamp(radius, 0.0, 1.0);

    vec4 gradient_color = texture(gradient_texture, vec2(radius, 0.5));

    float angle = atan(uv_var.x - 0.5, uv_var.y - 0.5) + rotation;

    vec4 glow = mix(inner_glow_color, outer_glow_color, smoothstep(inner_radius, inner_radius + edge_softness, radius));

    float alpha = smoothstep(1.0, 1.0 - edge_softness, radius);

    vec4 final_color = gradient_color * glow;

    ALBEDO = final_color.rgb;

    EMISSION = final_color.rgb * glow_strength;

    ALPHA = alpha * final_color.a;
}