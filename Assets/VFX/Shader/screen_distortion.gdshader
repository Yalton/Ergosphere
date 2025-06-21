shader_type canvas_item;

// Corruption intensity and timing
uniform float corruption_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float glitch_speed : hint_range(0.1, 10.0) = 3.0;
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.1;

// Colors for corruption effect
uniform vec4 corruption_color1 : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Red
uniform vec4 corruption_color2 : source_color = vec4(0.8, 0.0, 0.8, 1.0); // Magenta
uniform vec4 corruption_color3 : source_color = vec4(0.0, 1.0, 0.0, 1.0); // Green

// Noise functions
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    float time = TIME * glitch_speed;

    // Create multiple layers of distortion
    vec2 distorted_uv = uv;

    // Horizontal glitch lines
    float line_noise = noise(vec2(uv.y * 50.0, time));
    if (line_noise > 0.7) {
        distorted_uv.x += sin(time * 20.0 + uv.y * 100.0) * distortion_strength;
    }

    // Vertical scan lines
    float scan_line = sin(uv.y * 800.0) * 0.04;
    distorted_uv.x += scan_line;

    // Digital block corruption
    vec2 block_uv = floor(uv * 40.0) / 40.0;
    float block_noise = noise(vec2(block_uv.x * 10.0, block_uv.y * 10.0 + time));

    // Color channel separation (chromatic aberration)
    vec2 red_offset = distorted_uv + vec2(0.01, 0.0) * corruption_intensity;
    vec2 green_offset = distorted_uv;
    vec2 blue_offset = distorted_uv - vec2(0.01, 0.0) * corruption_intensity;

    // Sample colors with distortion
    float red = corruption_color1.r;
    float green = corruption_color2.g;
    float blue = corruption_color3.b;

    // Add random pixel corruption
    float pixel_corruption = random(floor(uv * 200.0));
    if (pixel_corruption > 0.95) {
        red = 1.0;
        green = 1.0;
        blue = 1.0;
    }

    // Add data corruption blocks
    if (block_noise > 0.8) {
        vec3 corrupt_color = mix(corruption_color1.rgb, corruption_color2.rgb, random(block_uv));
        red = corrupt_color.r;
        green = corrupt_color.g;
        blue = corrupt_color.b;
    }

    // Static noise overlay
    float static_noise = random(uv + time) * 0.3;

    // Combine everything
    vec3 final_color = vec3(red, green, blue);
    final_color += static_noise;

    // Add flickering effect
    float flicker = sin(time * 60.0) * 0.1 + 0.9;
    final_color *= flicker;

    // Ensure high contrast corruption
    final_color = mix(final_color, vec3(1.0), step(0.9, random(uv + time * 0.1)));

    COLOR = vec4(final_color, 1.0);
}