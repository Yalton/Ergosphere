// Accretion disk shader with fire-like effect
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Standard material uniforms
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);
uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);
uniform sampler2D texture_emission : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 emission : source_color;
uniform float emission_energy : hint_range(0.0, 100.0, 0.01);
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// Animation parameters
uniform float rotation_speed : hint_range(0.0, 2.0) = 0.2;
uniform float pulse_speed : hint_range(0.0, 2.0) = 0.5;
uniform float pulse_amplitude : hint_range(0.0, 1.0) = 0.2;
uniform bool enable_animation = true;

// Fire effect parameters
uniform bool enable_fire_effect = true;
uniform float fire_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float fire_speed : hint_range(0.0, 2.0) = 0.3;
uniform vec4 fire_color_inner : source_color = vec4(1.0, 0.7, 0.0, 1.0); // Yellow-orange
uniform vec4 fire_color_outer : source_color = vec4(1.0, 0.3, 0.0, 1.0); // Deep orange-red

// Noise for fire effect
uniform sampler2D noise_texture : hint_default_white;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
    // Original vertex code
    UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
    vec2 base_uv = UV;

    // Simple animation: rotate the UVs around center
    if (enable_animation) {
        // Center UVs around origin
        vec2 centered_uv = base_uv - vec2(0.5, 0.5);

        // Rotate the UVs
        float rotation_angle = TIME * rotation_speed;
        float sin_rot = sin(rotation_angle);
        float cos_rot = cos(rotation_angle);
        vec2 rotated_uv = vec2(
            centered_uv.x * cos_rot - centered_uv.y * sin_rot,
            centered_uv.x * sin_rot + centered_uv.y * cos_rot
        );

        // Shift back to 0-1 range
        base_uv = rotated_uv + vec2(0.5, 0.5);
    }

    // Calculate distance from center for ring-like effects
    vec2 centered_uv = base_uv - vec2(0.5, 0.5);
    float dist_from_center = length(centered_uv) * 2.0; // Scale to 0-1 range for unit circle

    // Standard material code
    vec4 albedo_tex = texture(texture_albedo, base_uv);
    ALBEDO = albedo.rgb * albedo_tex.rgb;

    float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
    METALLIC = metallic_tex * metallic;

    SPECULAR = specular;

    vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
    float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
    ROUGHNESS = roughness_tex * roughness;

    // Emission with pulsing and fire effects
    vec3 emission_tex = texture(texture_emission, base_uv).rgb;
    float pulse_factor = 1.0;

    if (enable_animation) {
        // Add pulsing to emission
        pulse_factor = 1.0 + sin(TIME * pulse_speed) * pulse_amplitude;
    }

    // Base emission
    vec3 final_emission = (emission.rgb + emission_tex) * emission_energy * pulse_factor;

    // Add fire-like effect
    if (enable_fire_effect) {
        // Create fire flickering and movement
        float angle = atan(centered_uv.y, centered_uv.x);

        // Create distortion in the UV coordinates for fire effect
        vec2 fire_uv = base_uv;
        fire_uv.x += sin(fire_uv.y * 10.0 + TIME * fire_speed) * 0.01 * fire_intensity;
        fire_uv.y += cos(fire_uv.x * 10.0 + TIME * fire_speed * 0.7) * 0.01 * fire_intensity;

        // Sample noise texture for random variation
        float noise = texture(noise_texture, fire_uv + vec2(TIME * 0.1, 0.0)).r;

        // Create radial gradient for fire color transition
        vec3 fire_color = mix(fire_color_inner.rgb, fire_color_outer.rgb, dist_from_center);

        // Add fire effect to emission
        float fire_factor = (1.0 - dist_from_center) * fire_intensity * (0.8 + 0.4 * noise);
        fire_factor *= (1.0 + 0.2 * sin(angle * 8.0 + TIME * 2.0)); // Add angular variation

        // Only apply fire effect in a ring (not at center or outer edges)
        fire_factor *= smoothstep(0.0, 0.3, dist_from_center) * smoothstep(1.0, 0.7, dist_from_center);

        // Add fire to emission
        final_emission += fire_color * fire_factor * emission_energy;
    }

    EMISSION = final_emission;
}