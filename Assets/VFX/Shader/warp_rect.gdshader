shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float warp_strength : hint_range(0.0, 1.0) = 0.5;
uniform float wave_speed : hint_range(0.0, 10.0) = 3.0;
uniform float wave_frequency : hint_range(0.0, 50.0) = 20.0;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.02;
uniform float blur_amount : hint_range(0.0, 5.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 uv = SCREEN_UV;
    float time = TIME * wave_speed;
    
    // Create warping effect
    float warp_x = sin(uv.y * wave_frequency + time) * warp_strength * 0.05;
    float warp_y = cos(uv.x * wave_frequency + time * 1.3) * warp_strength * 0.05;
    
    vec2 warped_uv = uv + vec2(warp_x, warp_y);
    
    // Add chromatic aberration
    vec4 color;
    color.r = texture(screen_texture, warped_uv + vec2(chromatic_aberration * warp_strength, 0.0)).r;
    color.g = texture(screen_texture, warped_uv).g;
    color.b = texture(screen_texture, warped_uv - vec2(chromatic_aberration * warp_strength, 0.0)).b;
    color.a = 1.0;
    
    // Add simple blur effect
    if (blur_amount > 0.0) {
        vec4 blur_color = vec4(0.0);
        float blur_size = blur_amount * warp_strength * 0.002;
        int samples = 0;
        
        for (int x = -2; x <= 2; x++) {
            for (int y = -2; y <= 2; y++) {
                vec2 offset = vec2(float(x), float(y)) * blur_size;
                blur_color += texture(screen_texture, warped_uv + offset);
                samples++;
            }
        }
        color = mix(color, blur_color / float(samples), 0.5);
    }
    
    // Add vignette effect
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(uv, center);
    float vignette = 1.0 - smoothstep(0.4, 0.8, dist) * vignette_strength * warp_strength;
    color.rgb *= vignette;
    
    // Add a subtle color tint when warped
    color.rgb = mix(color.rgb, vec3(0.8, 0.6, 1.0) * color.rgb, warp_strength * 0.2);
    
    COLOR = color;
}