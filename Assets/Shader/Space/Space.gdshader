shader_type sky;

// Star parameters
uniform vec3 sky_color : source_color = vec3(0.01, 0.01, 0.02);
uniform vec3 star_color_1 : source_color = vec3(0.8, 0.85, 1.0);
uniform vec3 star_color_2 : source_color = vec3(1.0, 0.8, 0.7);
uniform vec3 star_color_3 : source_color = vec3(0.7, 0.8, 1.0);
uniform float star_density : hint_range(0.0, 1.0) = 0.4;
uniform float star_twinkle_speed : hint_range(0.0, 5.0) = 1.0;
uniform float star_twinkle_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float star_size : hint_range(0.1, 5.0) = 1.0;

// Galaxy parameters
uniform vec3 galaxy_color_1 : source_color = vec3(0.2, 0.4, 0.8);
uniform vec3 galaxy_color_2 : source_color = vec3(0.8, 0.2, 0.5);
uniform vec3 galaxy_color_3 : source_color = vec3(0.2, 0.8, 0.6);
uniform float galaxy_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float galaxy_size : hint_range(0.1, 5.0) = 1.0;
uniform float galaxy_complexity : hint_range(1.0, 10.0) = 3.0;
uniform float galaxy_distortion : hint_range(0.0, 5.0) = 2.0;

// Nebula parameters
uniform float nebula_density : hint_range(0.0, 1.0) = 0.3;
uniform float nebula_complexity : hint_range(1.0, 10.0) = 5.0;
uniform float nebula_speed : hint_range(0.0, 0.1) = 0.01;
uniform float nebula_fade_distance : hint_range(0.0, 10.0) = 2.0;

// General parameters
uniform float rotation_speed : hint_range(0.0, 0.1) = 0.002;

// Hash function for randomizing positions
float hash(vec3 p) {
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

// Improved hash for better randomness
vec3 hash3(vec3 p) {
    p = vec3(
        dot(p, vec3(127.1, 311.7, 74.7)),
        dot(p, vec3(269.5, 183.3, 246.1)),
        dot(p, vec3(113.5, 271.9, 124.6))
    );
    return fract(sin(p) * 43758.5453123);
}

// Smooth noise function
float smooth_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    
    // Smooth interpolation
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    
    float n000 = hash(i + vec3(0.0, 0.0, 0.0));
    float n001 = hash(i + vec3(0.0, 0.0, 1.0));
    float n010 = hash(i + vec3(0.0, 1.0, 0.0));
    float n011 = hash(i + vec3(0.0, 1.0, 1.0));
    float n100 = hash(i + vec3(1.0, 0.0, 0.0));
    float n101 = hash(i + vec3(1.0, 0.0, 1.0));
    float n110 = hash(i + vec3(1.0, 1.0, 0.0));
    float n111 = hash(i + vec3(1.0, 1.0, 1.0));
    
    float n00 = mix(n000, n001, u.z);
    float n01 = mix(n010, n011, u.z);
    float n10 = mix(n100, n101, u.z);
    float n11 = mix(n110, n111, u.z);
    
    float n0 = mix(n00, n01, u.y);
    float n1 = mix(n10, n11, u.y);
    
    return mix(n0, n1, u.x);
}

// Fractional Brownian Motion (fBm) for layered noise
float fbm(vec3 p, float octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (float i = 0.0; i < 10.0; i++) {
        if (i >= octaves) break;
        value += amplitude * smooth_noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

// Improved star function with better twinkling
float star(vec3 dir, float size, float t, float seed) {
    // Use spherical projection to avoid seams
    vec3 p = normalize(dir) * 100.0;
    
    // Grid-based position
    vec3 grid_pos = floor(p);
    vec3 fpos = fract(p) - 0.5;
    
    // Check if this grid cell should have a star
    float rnd = hash(grid_pos);
    if (rnd > star_density) {
        return 0.0;
    }
    
    // Star shape - sharper falloff for point-like stars
    float dist = length(fpos);
    float bright = 1.0 - dist * 2.0;
    bright = smoothstep(0.0, 0.5, bright);
    bright = pow(bright, 2.0 / size);
    
    // Improved twinkling with multiple frequencies
    float twinkle_base = hash(grid_pos + seed);
    float twinkle1 = sin(t * star_twinkle_speed * (twinkle_base * 2.0 + 1.0)) * 0.5 + 0.5;
    float twinkle2 = sin(t * star_twinkle_speed * 2.3 * (twinkle_base * 1.5 + 0.5)) * 0.5 + 0.5;
    float twinkle3 = sin(t * star_twinkle_speed * 0.7 * (twinkle_base * 3.0 + 2.0)) * 0.5 + 0.5;
    
    // Combine twinkle effects
    float twinkle = twinkle1 * 0.5 + twinkle2 * 0.3 + twinkle3 * 0.2;
    
    // Apply twinkle intensity
    bright *= mix(1.0 - star_twinkle_intensity, 1.0, twinkle);
    
    return bright;
}

// Procedural galaxy function
vec3 galaxy(vec3 dir, float time) {
    // Normalize direction to work on unit sphere
    vec3 p = normalize(dir);
    
    float rotation_angle = time * 0.05;
    mat2 rotation_matrix = mat2(
        vec2(cos(rotation_angle), sin(rotation_angle)),
        vec2(-sin(rotation_angle), cos(rotation_angle))
    );

    vec2 rotated = rotation_matrix * vec2(p.x, p.z);
    p.x = rotated.x;
    p.z = rotated.y;

    // Create galaxy plane
    float galaxy_plane = exp(-abs(p.y) * 8.0 * galaxy_size);

    // Create galaxy spiral arms
    vec3 spiral_pos = p * 2.0;
    spiral_pos.y *= 5.0;

    float angle = atan(p.z, p.x);
    float dist = length(p.xz);
    float spiral = sin(angle * 3.0 + dist * galaxy_distortion - time * 0.1);

    float galaxy_noise = fbm(spiral_pos + vec3(spiral * 0.5, 0.0, time * 0.1), galaxy_complexity);
    galaxy_noise = pow(galaxy_noise, 1.5) * galaxy_plane;

    vec3 color_variation = mix(
        mix(galaxy_color_1, galaxy_color_2, smooth_noise(p * 2.0)),
        galaxy_color_3,
        smooth_noise(p * 3.0 + vec3(0.0, time * 0.1, 0.0))
    );

    float center_glow = exp(-length(p.xz) * 5.0);

    return color_variation * galaxy_noise * galaxy_intensity + vec3(1.0, 0.9, 0.8) * center_glow * galaxy_intensity;
}

// Improved nebula function with fade
vec3 nebula(vec3 dir, float time) {
    // Normalize and apply fade based on viewing angle
    vec3 p = normalize(dir);
    
    // Fade nebula near horizon and poles to prevent interior bleeding
    float fade_factor = 1.0;
    fade_factor *= smoothstep(0.0, 0.3, abs(p.y)); // Fade near horizon
    fade_factor *= smoothstep(1.0, 0.7, abs(p.y)); // Fade near poles
    
    // Scale for nebula
    p *= nebula_fade_distance;

    float slow_time = time * nebula_speed;
    mat2 nebula_rotation = mat2(
        vec2(cos(slow_time), sin(slow_time)),
        vec2(-sin(slow_time), cos(slow_time))
    );

    vec2 rotated = nebula_rotation * vec2(p.x, p.z);
    p.x = rotated.x;
    p.z = rotated.y;

    // Create main nebula shape with smoother noise
    float nebula_shape = fbm(p * 1.5, nebula_complexity);

    vec3 nebula_col1 = mix(vec3(0.2, 0.0, 0.5), vec3(0.1, 0.4, 0.6), fbm(p + 1.0, 3.0));
    vec3 nebula_col2 = mix(vec3(0.8, 0.2, 0.3), vec3(0.4, 0.1, 0.2), fbm(p + 2.0, 3.0));

    // Adjust density threshold to prevent over-saturation
    float density_threshold = 1.0 - (nebula_density * 0.7); // Cap effective density
    float nebula_clouds = smoothstep(density_threshold, density_threshold + 0.1, nebula_shape);

    float detail_noise = fbm(p * 4.0, 3.0);

    vec3 final_color = mix(nebula_col1, nebula_col2, detail_noise) * nebula_clouds * 0.4 * fade_factor;

    return final_color;
}

// Smoother rotation function
mat3 get_rotation_matrix(float time) {
    float angle = time * rotation_speed;
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        vec3(c, 0.0, -s),
        vec3(0.0, 1.0, 0.0),
        vec3(s, 0.0, c)
    );
}

void sky() {
    // Use normalized direction to prevent seams
    vec3 dir = normalize(EYEDIR);

    // Apply rotation
    dir = get_rotation_matrix(TIME) * dir;

    // Start with base sky color
    vec3 col = sky_color;

    // Add stars with different seeds for varied twinkling
    float s1 = star(dir, star_size, TIME, 0.0);
    float s2 = star(dir * 1.5, star_size * 0.8, TIME * 1.2, 1.0);
    float s3 = star(dir * 0.7, star_size * 1.2, TIME * 0.7, 2.0);

    // Mix star colors
    col += s1 * star_color_1;
    col += s2 * star_color_2;
    col += s3 * star_color_3;

    // Add procedural galaxy
    col += galaxy(dir, TIME);

    // Add procedural nebula with fade
    col += nebula(dir, TIME);

    // Apply subtle overall brightness modulation to prevent oversaturation
    col = col / (1.0 + col * 0.1);

    // Output the final color
    COLOR = col;
}