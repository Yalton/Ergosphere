shader_type canvas_item;

// Effect progress (0.0 = no effect, 1.0 = full effect)
uniform float effect_progress : hint_range(0.0, 1.0) = 0.0;

// Effect intensity multiplier
uniform float intensity : hint_range(0.5, 3.0) = 1.0;

// Distortion parameters
uniform float wave_frequency : hint_range(1.0, 20.0) = 5.0;
uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.05;
uniform float spiral_strength : hint_range(0.0, 2.0) = 0.5;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.01;

// Time for animation (optional, can be set via GDScript)
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = UV;
    
    // Calculate distance and angle from center
    vec2 delta = uv - center;
    float dist = length(delta);
    float angle = atan(delta.y, delta.x);
    
    // Apply effect based on progress
    float effect_amount = effect_progress * intensity;
    
    // Wave distortion (creates the wonky stretch)
    float wave = sin(dist * wave_frequency + TIME + time_offset) * wave_amplitude;
    
    // Spiral distortion
    float spiral = spiral_strength * effect_amount;
    angle += spiral * dist * effect_amount;
    
    // Radial stretch/compression
    float radial_distort = 1.0 + (dist * dist * effect_amount * 0.5);
    dist *= radial_distort;
    
    // Apply wave to distance
    dist += wave * effect_amount;
    
    // Reconstruct UV coordinates
    vec2 distorted_uv = center + vec2(cos(angle), sin(angle)) * dist;
    
    // Chromatic aberration for extra wonkiness
    vec2 r_offset = distorted_uv + vec2(chromatic_aberration * effect_amount, 0.0);
    vec2 g_offset = distorted_uv;
    vec2 b_offset = distorted_uv - vec2(chromatic_aberration * effect_amount, 0.0);
    
    // Sample texture with chromatic aberration
    vec4 color;
    color.r = texture(TEXTURE, r_offset).r;
    color.g = texture(TEXTURE, g_offset).g;
    color.b = texture(TEXTURE, b_offset).b;
    color.a = texture(TEXTURE, distorted_uv).a;
    
    // Edge darkening for tunnel vision effect
    float vignette = 1.0 - (dist * dist * effect_amount * 0.3);
    vignette = clamp(vignette, 0.0, 1.0);
    color.rgb *= vignette;
    
    COLOR = color;
}