shader_type spatial;
render_mode unshaded, cull_disabled;

// Animation controls
uniform float collapse_progress : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float distortion_amount : hint_range(0.0, 2.0) = 0.5;

// Visual settings - Dark purple/black theme
uniform vec4 inner_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);  // Pure black center
uniform vec4 outer_color : source_color = vec4(0.3, 0.0, 0.5, 0.9);  // Deep purple edge
uniform vec4 accent_color : source_color = vec4(0.6, 0.0, 0.8, 1.0); // Bright purple for energy
uniform float emission_strength : hint_range(0.0, 10.0) = 2.0;
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.0;
uniform float darkness_factor : hint_range(0.0, 1.0) = 0.7; // How much it darkens the area

// Noise settings for distortion
uniform float noise_scale : hint_range(1.0, 20.0) = 8.0;
uniform float ring_count : hint_range(1.0, 10.0) = 5.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 original_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	original_pos = VERTEX;

	// Create collapsing distortion
	float dist_from_center = length(VERTEX);

	// Spherical ripples moving inward
	float ripple = sin(dist_from_center * ring_count - TIME * pulse_speed) * 0.5 + 0.5;
	ripple *= (1.0 - collapse_progress);

	// Noise-based vertex displacement
	vec3 noise_input = VERTEX * noise_scale + TIME * 0.5;
	float noise = sin(noise_input.x) * cos(noise_input.y) * sin(noise_input.z);

	// Combine distortions and scale down with progress
	float scale_factor = 1.0 - collapse_progress * 0.8; // Don't fully collapse to 0
	vec3 distorted_vertex = VERTEX * scale_factor;

	// Add rippling distortion that increases with collapse
	distorted_vertex += NORMAL * noise * distortion_amount * collapse_progress * ripple;

	// Pull vertices inward more at the poles for implosion effect
	float pole_factor = abs(VERTEX.y) / dist_from_center;
	distorted_vertex *= mix(1.0, 1.0 - collapse_progress * 0.3, pole_factor);

	VERTEX = distorted_vertex;
}

void fragment() {
	// Calculate fresnel for edge glow
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - max(dot(view_dir, world_normal), 0.0), fresnel_power);

	// Energy patterns on surface - creates dark veins
	float energy_pattern = sin(original_pos.x * noise_scale + TIME * pulse_speed) *
						  sin(original_pos.y * noise_scale - TIME * pulse_speed * 0.7) *
						  sin(original_pos.z * noise_scale + TIME * pulse_speed * 1.3);
	energy_pattern = energy_pattern * 0.5 + 0.5;

	// Inverted radial gradient - darker at center
	float radial = 1.0 - (length(original_pos) / 2.0); // Inverted for black hole effect
	radial = clamp(radial, 0.0, 1.0);
	radial = pow(radial, 2.0); // Make center even darker

	// Dark core with purple edges
	vec3 color = mix(outer_color.rgb, inner_color.rgb, radial);
	// Add purple energy veins
	color = mix(color, accent_color.rgb, energy_pattern * 0.3 * (1.0 - radial));

	// Darken the overall color to create void effect
	color *= (1.0 - darkness_factor * radial);

	// Increase intensity during collapse
	float collapse_intensity = 1.0 + collapse_progress * 2.0;

	// Fully opaque - no transparency
	ALBEDO = color;

	// Purple glow only on the edges, not the center
	vec3 final_emission = accent_color.rgb * emission_strength * fresnel * (1.0 - radial) * collapse_intensity;

	// Combine albedo and emission for final color since we're unshaded
	ALBEDO = color + final_emission;
}