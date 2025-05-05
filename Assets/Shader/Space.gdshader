shader_type sky;

// Star parameters
uniform vec3 sky_color : source_color = vec3(0.01, 0.01, 0.02);
uniform vec3 star_color_1 : source_color = vec3(0.8, 0.85, 1.0);
uniform vec3 star_color_2 : source_color = vec3(1.0, 0.8, 0.7);
uniform vec3 star_color_3 : source_color = vec3(0.7, 0.8, 1.0);
uniform float star_density : hint_range(0.0, 1.0) = 0.4;
uniform float star_twinkle_speed : hint_range(0.0, 5.0) = 1.0;
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

// Value noise function
float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    
    // Cubic interpolation
    vec3 u = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(
            mix(hash(i + vec3(0.0, 0.0, 0.0)), hash(i + vec3(1.0, 0.0, 0.0)), u.x),
            mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), u.x), 
            u.y
        ),
        mix(
            mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), u.x),
            mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), u.x), 
            u.y
        ),
        u.z
    );
}

// Fractional Brownian Motion (fBm) for layered noise
float fbm(vec3 p, float octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    // Add multiple layers of noise with different frequencies
    for (float i = 0.0; i < 10.0; i++) {
        if (i >= octaves) break;
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

// Star function - similar to original
float star(vec3 dir, float size, float t) {
    vec3 p = dir * 100.0;
    
    // Grid-based position
    vec3 grid_pos = floor(p);
    vec3 fpos = fract(p) - 0.5;
    
    // Check if this grid cell should have a star
    float rnd = hash(grid_pos);
    if (rnd > star_density) {
        return 0.0;
    }
    
    // Determine star brightness with some twinkling
    float bright = 1.0 - length(fpos) * 2.0;
    bright = smoothstep(0.0, 0.5, bright);
    
    // Add twinkling effect
    float twinkle = sin(t * star_twinkle_speed * (rnd * 3.0 + 0.5)) * 0.5 + 0.5;
    bright *= mix(0.6, 1.0, twinkle);
    
    // Apply size
    bright = pow(bright, 1.0 / size);
    
    return bright;
}

// Procedural galaxy function
vec3 galaxy(vec3 dir, float time) {
    // Let's simplify by using the matrix multiplication directly
    vec3 p = dir;
    float rotation_angle = time * 0.05;
    mat2 rotation_matrix = mat2(
        vec2(cos(rotation_angle), sin(rotation_angle)),
        vec2(-sin(rotation_angle), cos(rotation_angle))
    );
    
    // Create a vec2 from the x and z components, apply rotation, and store back
    vec2 rotated = rotation_matrix * vec2(p.x, p.z);
    p.x = rotated.x;
    p.z = rotated.y;
    
    // Create galaxy plane - stronger near XZ plane (y near 0)
    float galaxy_plane = exp(-abs(p.y) * 8.0 * galaxy_size);
    
    // Create galaxy spiral arms using noise
    vec3 spiral_pos = p * 2.0;
    spiral_pos.y *= 5.0;  // Flatten in Y axis
    
    // Add some spiral distortion
    float angle = atan(p.z, p.x);
    float dist = length(p.xz);
    float spiral = sin(angle * 3.0 + dist * galaxy_distortion - time * 0.1);
    
    // Create the galaxy using layered noise
    float galaxy_noise = fbm(spiral_pos + vec3(spiral * 0.5, 0.0, time * 0.1), galaxy_complexity);
    galaxy_noise = pow(galaxy_noise, 1.5) * galaxy_plane;
    
    // Create color variation based on position and noise
    vec3 color_variation = mix(
        mix(galaxy_color_1, galaxy_color_2, noise(p * 2.0)),
        galaxy_color_3,
        noise(p * 3.0 + vec3(0.0, time * 0.1, 0.0))
    );
    
    // Brighten the center of the galaxy
    float center_glow = exp(-length(p.xz) * 5.0);
    
    // Combine all elements
    return color_variation * galaxy_noise * galaxy_intensity + vec3(1.0, 0.9, 0.8) * center_glow * galaxy_intensity;
}

// Procedural nebula function
vec3 nebula(vec3 dir, float time) {
    // Create multiple layers of noise with different settings
    vec3 p = dir * 2.0;
    
    // Slow rotation for nebula
    float slow_time = time * nebula_speed;
    mat2 nebula_rotation = mat2(
        vec2(cos(slow_time), sin(slow_time)),
        vec2(-sin(slow_time), cos(slow_time))
    );
    
    // Apply rotation directly using matrix multiplication
    vec2 rotated = nebula_rotation * vec2(p.x, p.z);
    p.x = rotated.x;
    p.z = rotated.y;
    
    // Create main nebula shape
    float nebula_shape = fbm(p * 1.5, nebula_complexity);
    
    // Create color variation
    vec3 nebula_col1 = mix(vec3(0.2, 0.0, 0.5), vec3(0.1, 0.4, 0.6), fbm(p + 1.0, 3.0));
    vec3 nebula_col2 = mix(vec3(0.8, 0.2, 0.3), vec3(0.4, 0.1, 0.2), fbm(p + 2.0, 3.0));
    
    // Create patchy, cloud-like appearance with threshold
    float nebula_clouds = smoothstep(1.0 - nebula_density, 1.0, nebula_shape);
    
    // Add some depth with additional noise
    float detail_noise = fbm(p * 4.0, 3.0);
    
    // Final nebula color
    vec3 final_color = mix(nebula_col1, nebula_col2, detail_noise) * nebula_clouds * 0.6;
    
    return final_color;
}

// Rotation function for slow rotation of the sky
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
    // Initial direction
    vec3 dir = EYEDIR;
    
    // Apply rotation over time
    dir = get_rotation_matrix(TIME) * dir;
    
    // Start with base sky color
    vec3 col = sky_color;
    
    // Add stars
    float s1 = star(dir, star_size, TIME);
    float s2 = star(dir * 1.5, star_size * 0.8, TIME * 1.2);
    float s3 = star(dir * 0.7, star_size * 1.2, TIME * 0.7);
    
    // Mix star colors
    col += s1 * star_color_1;
    col += s2 * star_color_2;
    col += s3 * star_color_3;
    
    // Add procedural galaxy
    col += galaxy(dir, TIME);
    
    // Add procedural nebula 
    col += nebula(dir * 1.5, TIME);
    
    // Output the final color
    COLOR = col;
}