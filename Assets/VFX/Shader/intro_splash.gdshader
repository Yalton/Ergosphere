shader_type canvas_item;

uniform float time_scale : hint_range(0.1, 3.0) = 0.5;
uniform float swirl_intensity : hint_range(1.0, 10.0) = 3.0;
uniform float noise_scale : hint_range(0.5, 5.0) = 2.0;
uniform vec4 color_dark : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 color_mid : source_color = vec4(0.15, 0.15, 0.18, 1.0);
uniform vec4 color_light : source_color = vec4(0.25, 0.25, 0.3, 1.0);
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.8;

// Simple noise function
vec2 random2(vec2 st) {
    st = vec2(dot(st, vec2(127.1, 311.7)),
              dot(st, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(st) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(dot(random2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
                   dot(random2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
               mix(dot(random2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
                   dot(random2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    vec2 uv = UV;
    vec2 centered_uv = uv - vec2(0.5);

    // Create swirling motion
    float angle = atan(centered_uv.y, centered_uv.x);
    float radius = length(centered_uv);

    // Add time-based rotation that varies with distance from center
    angle += TIME * time_scale * (1.0 - radius * 0.5);

    // Create spiral coordinates
    vec2 spiral_coords = vec2(
        cos(angle) * radius,
        sin(angle) * radius
    );

    // Layer multiple noise octaves for complexity
    float n1 = noise(spiral_coords * noise_scale + TIME * 0.1);
    float n2 = noise(spiral_coords * noise_scale * 2.0 - TIME * 0.15);
    float n3 = noise(spiral_coords * noise_scale * 0.5 + TIME * 0.05);

    // Combine noise layers with swirl distortion
    float swirl = sin(radius * swirl_intensity + angle * 2.0 + TIME * time_scale);
    float combined = (n1 * 0.5 + n2 * 0.3 + n3 * 0.2) + swirl * 0.3;

    // Remap to 0-1 range
    combined = combined * 0.5 + 0.5;

    // Create smooth gradient between colors
    vec4 color;
    if (combined < 0.33) {
        color = mix(color_dark, color_mid, combined * 3.0);
    } else if (combined < 0.66) {
        color = mix(color_mid, color_light, (combined - 0.33) * 3.0);
    } else {
        color = mix(color_light, color_mid, (combined - 0.66) * 3.0);
    }

    // Add vignette effect
    float vignette = 1.0 - length(centered_uv) * vignette_strength;
    vignette = clamp(vignette, 0.0, 1.0);

    // Apply vignette to darken edges
    color.rgb *= vignette;

    COLOR = color;
}