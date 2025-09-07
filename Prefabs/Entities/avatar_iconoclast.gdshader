shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Collapse animation control
uniform float collapse_progress : hint_range(0.0, 1.0) = 0.0;

// Ink flow properties (matching creature body)
uniform float darkness : hint_range(0.0, 1.0) = 0.1;
uniform float flow_speed : hint_range(0.0, 5.0) = 1.0;
uniform float distortion_amount : hint_range(0.0, 0.3) = 0.05;
uniform float pattern_scale : hint_range(0.1, 10.0) = 2.0;
uniform float edge_dissolution : hint_range(0.0, 1.0) = 0.3;

// Color settings - matching creature's ink aesthetic
uniform vec3 ink_color : source_color = vec3(0.05, 0.0, 0.1);
uniform vec3 void_color : source_color = vec3(0.0, 0.0, 0.0); // Black center during collapse
uniform float emission_strength : hint_range(0.0, 1.0) = 0.1;

// Material properties
uniform float metallic : hint_range(0.0, 1.0) = 0.8;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;

// Collapse-specific effects
uniform float collapse_distortion : hint_range(0.0, 2.0) = 0.8;
uniform float collapse_pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float ring_count : hint_range(1.0, 10.0) = 5.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 original_pos;
varying float vertex_displacement;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    original_pos = VERTEX;

    float time = TIME * flow_speed;
    float dist_from_center = length(VERTEX);

    // Create swirling ink displacement (from creature shader)
    float swirl1 = sin(world_pos.x * pattern_scale + time) * cos(world_pos.z * pattern_scale - time * 0.7);
    float swirl2 = sin(world_pos.y * pattern_scale * 1.3 - time * 0.5) * cos(world_pos.x * pattern_scale + time);
    float ink_displacement = (swirl1 + swirl2) * 0.5;

    // Edge dissolution effect
    float edge_factor = length(VERTEX) * edge_dissolution * 0.1;
    float edge_wave = sin(time * 3.0 + edge_factor) * edge_factor * 0.1;

    // Collapse-specific distortions
    float collapse_scale = 1.0 - collapse_progress * 0.85; // Don't fully collapse

    // Spherical ripples moving inward during collapse
    float ripple = sin(dist_from_center * ring_count - TIME * collapse_pulse_speed) * 0.5 + 0.5;
    ripple *= (1.0 - collapse_progress);

    // Combine ink flow with collapse
    vec3 base_displacement = NORMAL * ink_displacement * distortion_amount * (1.0 - collapse_progress * 0.5);
    vec3 edge_displacement = NORMAL * edge_wave;

    // Add collapse rippling that intensifies
    vec3 collapse_displacement = NORMAL * ripple * collapse_distortion * collapse_progress * 0.2;

    // Scale down during collapse with ink-like undulation
    VERTEX *= collapse_scale;

    // Apply combined displacements
    VERTEX += base_displacement + edge_displacement + collapse_displacement;

    // Pull vertices inward more at the poles for implosion effect
    float pole_factor = abs(VERTEX.y) / max(dist_from_center, 0.01);
    VERTEX *= mix(1.0, 1.0 - collapse_progress * 0.3, pole_factor);

    // Store displacement for fragment shader
    vertex_displacement = length(base_displacement + edge_displacement);
}

void fragment() {
    float time = TIME * flow_speed;

    // Create flowing ink pattern (from creature shader)
    vec3 flow_coords = world_pos * pattern_scale;

    // Multiple layers of swirling patterns
    float pattern1 = sin(flow_coords.x + time) * cos(flow_coords.y - time * 0.8);
    float pattern2 = sin(flow_coords.z * 1.5 - time * 0.6) * cos(flow_coords.x + time * 1.2);
    float pattern3 = sin(length(flow_coords.xy) * 2.0 - time * 2.0);

    // Combine patterns
    float ink_pattern = (pattern1 * 0.4 + pattern2 * 0.4 + pattern3 * 0.2);
    ink_pattern = (ink_pattern + 1.0) * 0.5;

    // Create swirling vortex effect
    float vortex = sin(atan(flow_coords.x, flow_coords.z) * 3.0 + time + length(flow_coords.xz) * 2.0);
    ink_pattern = mix(ink_pattern, vortex * 0.5 + 0.5, 0.3);

    // Edge detection for dissolution
    float fresnel = 1.0 - dot(normalize(VIEW), NORMAL);
    fresnel = pow(fresnel, 1.5);

    // Collapse vortex pattern - creates dark veins pulling inward
    float collapse_vortex = sin(length(original_pos.xy) * ring_count - TIME * collapse_pulse_speed);
    collapse_vortex = collapse_vortex * 0.5 + 0.5;

    // Mix ink pattern with collapse vortex
    float combined_pattern = mix(ink_pattern, collapse_vortex, collapse_progress * 0.7);

    // Apply edge dissolution
    float dissolution = mix(1.0, combined_pattern, 1.0 - (fresnel * edge_dissolution));

    // Radial gradient for collapse - darker at center
    float radial = length(original_pos) / 2.0;
    radial = clamp(radial, 0.0, 1.0);
    float darkness_gradient = mix(1.0, 0.2, (1.0 - radial) * collapse_progress);

    // Final color calculation
    vec3 final_color = ink_color * darkness;
    final_color = mix(final_color, ink_color * 0.3, combined_pattern);

    // During collapse, gradually mix with void color at center
    final_color = mix(final_color, void_color, (1.0 - radial) * collapse_progress * 0.8);

    // Apply darkness gradient
    final_color *= darkness_gradient;

    // Apply to material
    ALBEDO = final_color * dissolution;
    METALLIC = metallic * (1.0 - collapse_progress * 0.5); // Reduce metallic during collapse
    ROUGHNESS = mix(roughness, 1.0, combined_pattern * 0.3);

    // Emission - ink patterns glow subtly, intensifying during collapse
    float emission_intensity = mix(emission_strength, emission_strength * 3.0, collapse_progress);
    EMISSION = ink_color * combined_pattern * emission_intensity * fresnel;

    // Make edges slightly transparent, more so during collapse
    ALPHA = mix(1.0, 0.7, fresnel * edge_dissolution * (1.0 + collapse_progress));
}