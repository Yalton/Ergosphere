shader_type spatial;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float wave_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float wave_thickness : hint_range(0.0, 0.5) = 0.1;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec4 wave_color : source_color = vec4(0.0, 0.7, 1.0, 0.1);
uniform bool color_enabled = false;
uniform float max_wave_radius : hint_range(0.1, 2.0) = 1.0;

uniform float time_offset = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform bool continuous_wave = false;
uniform float wave_frequency : hint_range(0.1, 5.0) = 1.0;
uniform int num_waves : hint_range(1, 10) = 1;

uniform float distortion_strength : hint_range(0.0, 1.0) = 0.2;
uniform int distortion_mode : hint_range(0, 3) = 0; // 0: Radial, 1: Directional, 2: Spiral, 3: Ripple

uniform float fade_out_start : hint_range(0.0, 1.0) = 0.7;
uniform float wave_smoothness : hint_range(0.0, 0.1) = 0.02;
uniform float noise_influence : hint_range(0.0, 1.0) = 0.0;

varying float time;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void vertex() {
    time = TIME * wave_speed + time_offset;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center_uv = uv - center;
    
    float dist = length(center_uv);
    
    vec4 original_color = texture(screen_texture, uv);
    vec4 final_color = original_color;
    
    for (int i = 0; i < num_waves; i++) {
        float wave_time;
        if (continuous_wave) {
            wave_time = mod(time - float(i) / wave_frequency, max_wave_radius);
        } else {
            wave_time = time - float(i) / wave_frequency;
            if (wave_time < 0.0 || wave_time > max_wave_radius) continue;
        }
        float wave_front = wave_time / max_wave_radius;
        

        float wave_mask = smoothstep(wave_front - wave_thickness - wave_smoothness, 
                                    wave_front - wave_thickness + wave_smoothness, 
                                    dist) 
                        - smoothstep(wave_front - wave_smoothness, 
                                    wave_front + wave_smoothness, 
                                    dist);
        

        if (wave_mask > 0.01) {
            float noise = 1.0;
            if (noise_influence > 0.0) {
                noise = 1.0 + (random(uv + vec2(time * 0.1, time * 0.1)) * 2.0 - 1.0) * noise_influence;
            }
            
            vec2 distortion_dir;
            if (distortion_mode == 0) { 
                distortion_dir = normalize(center_uv);
            } else if (distortion_mode == 1) { 
                distortion_dir = vec2(0.0, 1.0);
            } else if (distortion_mode == 2) { 
                float angle = atan(center_uv.y, center_uv.x);
                distortion_dir = vec2(cos(angle + wave_time), sin(angle + wave_time));
            } else { 
                distortion_dir = normalize(center_uv) * sin(dist * 20.0 - wave_time * 5.0);
            }
            
           
            vec2 offset = distortion_dir * wave_mask * wave_intensity * distortion_strength * noise;
            vec4 distorted_color = texture(screen_texture, uv + offset);
            
            float fade_factor = 1.0;
            if (wave_front > fade_out_start) {
                fade_factor = 1.0 - smoothstep(fade_out_start, 1.0, wave_front);
            }
            
            if (color_enabled) {
                final_color = mix(final_color, mix(distorted_color, wave_color, wave_color.a * wave_mask), wave_mask * fade_factor);
            } else {
                final_color = mix(final_color, distorted_color, wave_mask * fade_factor);
            }
        }
    }
    
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
}