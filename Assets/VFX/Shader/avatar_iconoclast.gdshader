shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

uniform float darkness : hint_range(0.0, 1.0) = 0.1;

uniform float flow_speed : hint_range(0.0, 5.0) = 1.0;

uniform float distortion_amount : hint_range(0.0, 0.3) = 0.05;

// Scale of the swirling pattern
uniform float pattern_scale : hint_range(0.1, 10.0) = 2.0;

// How much the edges of the model seem to dissolve
uniform float edge_dissolution : hint_range(0.0, 1.0) = 0.3;

// Color tint for the ink (allows for deep purples, blues, etc)
uniform vec3 ink_color : source_color = vec3(0.05, 0.0, 0.1);

// Subtle emission for an otherworldly glow
uniform float emission_strength : hint_range(0.0, 1.0) = 0.1;

// Metallic value for reflections
uniform float metallic : hint_range(0.0, 1.0) = 0.8;

// Roughness for surface appearance
uniform float roughness : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    
    // Vertex displacement for spatial deformation
    float time = TIME * flow_speed;
    
    // Create swirling displacement
    float swirl1 = sin(world_pos.x * pattern_scale + time) * cos(world_pos.z * pattern_scale - time * 0.7);
    float swirl2 = sin(world_pos.y * pattern_scale * 1.3 - time * 0.5) * cos(world_pos.x * pattern_scale + time);
    
    // Combine swirls for complex motion
    float displacement = (swirl1 + swirl2) * 0.5;
    
    // Apply displacement along normal
    VERTEX += NORMAL * displacement * distortion_amount;
    
    // Edge dissolution effect - vertices further from origin get more unstable
    float edge_factor = length(VERTEX) * edge_dissolution * 0.1;
    VERTEX += NORMAL * sin(time * 3.0 + edge_factor) * edge_factor * 0.1;
}

void fragment() {
    float time = TIME * flow_speed;
    
    // Create flowing ink pattern
    vec3 flow_coords = world_pos * pattern_scale;
    
    // Multiple layers of swirling patterns
    float pattern1 = sin(flow_coords.x + time) * cos(flow_coords.y - time * 0.8);
    float pattern2 = sin(flow_coords.z * 1.5 - time * 0.6) * cos(flow_coords.x + time * 1.2);
    float pattern3 = sin(length(flow_coords.xy) * 2.0 - time * 2.0);
    
    // Combine patterns with different weights
    float ink_pattern = (pattern1 * 0.4 + pattern2 * 0.4 + pattern3 * 0.2);
    
    // Normalize to 0-1 range
    ink_pattern = (ink_pattern + 1.0) * 0.5;
    
    // Create swirling vortex effect
    float vortex = sin(atan(flow_coords.x, flow_coords.z) * 3.0 + time + length(flow_coords.xz) * 2.0);
    ink_pattern = mix(ink_pattern, vortex * 0.5 + 0.5, 0.3);
    
    // Edge detection for dissolution
    float fresnel = 1.0 - dot(normalize(VIEW), NORMAL);
    fresnel = pow(fresnel, 1.5);
    
    // Apply edge dissolution
    float dissolution = mix(1.0, ink_pattern, 1.0 - (fresnel * edge_dissolution));
    
    // Final color calculation
    vec3 final_color = ink_color * darkness;
    final_color = mix(final_color, ink_color * 0.3, ink_pattern);
    
    // Apply to material
    ALBEDO = final_color * dissolution;
    METALLIC = metallic;
    ROUGHNESS = mix(roughness, 1.0, ink_pattern * 0.3);
    
    // Subtle emission on the patterns
    EMISSION = ink_color * ink_pattern * emission_strength;
    
    // Make edges slightly transparent
    ALPHA = mix(1.0, 0.7, fresnel * edge_dissolution);
}