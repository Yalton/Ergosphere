shader_type spatial;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture;
uniform sampler2D depth_tex : hint_depth_texture;
uniform float scale = 1.0;
uniform float distortion_strength = 0.1;

void vertex() {
	// Scale up the mesh slightly to create an outline
	VERTEX += NORMAL * scale * 0.1;
}

void fragment() {
	// This shader will render a slightly larger version of your object
	// creating a distortion field around it
	
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	
	// Get the original object's screen position
	vec4 original_pos = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vec2 object_screen_pos = (original_pos.xy / original_pos.w) * 0.5 + 0.5;
	
	// Calculate distance from object center in screen space
	float screen_dist = length(SCREEN_UV - object_screen_pos);
	
	// Create distortion that decreases with distance
	float distortion = smoothstep(scale * 0.3, 0.0, screen_dist);
	
	// Direction from current pixel to object center
	vec2 dir = normalize(object_screen_pos - SCREEN_UV);
	
	// Apply distortion
	vec2 distorted_uv = SCREEN_UV + dir * distortion * distortion_strength;
	
	// Sample screen with distortion
	vec3 color = texture(screen_tex, distorted_uv).rgb;
	
	// Make the center black
	if (screen_dist < scale * 0.1) {
		color = vec3(0.0);
	}
	
	ALBEDO = color;
}