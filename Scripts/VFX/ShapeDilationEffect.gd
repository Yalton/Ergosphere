@tool
extends PostProcessShader
class_name ShapeDilationShaderAnimated

## Shape dilation/black hole distortion effect with moving distortion points
## Creates reality-warping distortions that pull and stretch the image

func _init():
	super._init()
	
	shader_code = """
	// Get normalized UV
	vec2 normalized_uv = vec2(uv) / vec2(size);
	
	// Sample original color
	vec4 original = imageLoad(color_image, uv);
	
	// Create pseudo-time based on screen position for animation
	// This creates a rolling effect across the screen
	float pseudo_time = (normalized_uv.x + normalized_uv.y) * 10.0;
	
	// Use noise function for more organic movement
	float noise1 = fract(sin(pseudo_time * 1.17) * 43758.5453);
	float noise2 = fract(sin(pseudo_time * 2.35) * 23421.6313);
	float noise3 = fract(sin(pseudo_time * 0.89) * 54327.8951);
	
	// Create moving distortion points (black holes)
	// Each hole follows a different pattern
	
	// Hole 1 - Circular orbit
	float orbit1 = pseudo_time * 0.5;
	vec2 hole1 = vec2(0.5, 0.5) + vec2(
		cos(orbit1) * 0.25,
		sin(orbit1) * 0.25
	);
	
	// Hole 2 - Figure-8 pattern
	float orbit2 = pseudo_time * 0.7;
	vec2 hole2 = vec2(0.5, 0.5) + vec2(
		sin(orbit2) * 0.3,
		sin(orbit2 * 2.0) * 0.2
	);
	
	// Hole 3 - Chaotic movement
	vec2 hole3 = vec2(
		0.5 + sin(pseudo_time * 0.3) * 0.4 * noise3,
		0.5 + cos(pseudo_time * 0.4) * 0.3 * (1.0 - noise3)
	);
	
	// Add secondary movement layer for more organic feel
	hole1.x += sin(pseudo_time * 3.0) * 0.05;
	hole1.y += cos(pseudo_time * 2.5) * 0.05;
	
	hole2.x += cos(pseudo_time * 2.2) * 0.03;
	hole2.y += sin(pseudo_time * 3.7) * 0.03;
	
	hole3.x += sin(pseudo_time * 4.1 + noise1 * 6.28) * 0.08;
	hole3.y += cos(pseudo_time * 3.3 + noise2 * 6.28) * 0.08;
	
	// Calculate distortion from each hole
	vec2 total_distortion = vec2(0.0);
	
	// Hole 1 - Strong pull with varying strength
	float dist1 = distance(normalized_uv, hole1);
	float radius1 = 0.2 + sin(pseudo_time * 2.0) * 0.1; // Pulsing radius
	if (dist1 < radius1) {
		float strength1 = 1.0 - (dist1 / radius1);
		strength1 = pow(strength1, 2.0);
		vec2 direction1 = normalize(hole1 - normalized_uv);
		total_distortion += direction1 * strength1 * 0.15;
		
		// Create swirl effect with varying speed
		float angle1 = atan(normalized_uv.y - hole1.y, normalized_uv.x - hole1.x);
		angle1 += strength1 * (3.14159 + sin(pseudo_time) * 1.5);
		float radius = dist1;
		vec2 swirl1 = hole1 + vec2(cos(angle1), sin(angle1)) * radius;
		total_distortion = mix(total_distortion, swirl1 - normalized_uv, strength1 * 0.5);
	}
	
	// Hole 2 - Medium pull with ripples
	float dist2 = distance(normalized_uv, hole2);
	float radius2 = 0.15 + cos(pseudo_time * 1.5) * 0.08;
	if (dist2 < radius2) {
		float strength2 = 1.0 - (dist2 / radius2);
		strength2 = pow(strength2, 1.5);
		vec2 direction2 = normalize(hole2 - normalized_uv);
		// Animated ripple effect
		float ripple = sin(dist2 * 30.0 - pseudo_time * 5.0) * 0.5 + 0.5;
		total_distortion += direction2 * strength2 * ripple * 0.1;
	}
	
	// Hole 3 - Weak but wide pull with chaotic behavior
	float dist3 = distance(normalized_uv, hole3);
	float radius3 = 0.25 + noise3 * 0.15;
	if (dist3 < radius3) {
		float strength3 = 1.0 - (dist3 / radius3);
		vec2 direction3 = normalize(hole3 - normalized_uv);
		// Add some chaos to the pull
		direction3 = mix(direction3, vec2(noise1 - 0.5, noise2 - 0.5), 0.3);
		total_distortion += direction3 * strength3 * 0.08;
	}
	
	// Edge detection for shape emphasis
	vec4 right = imageLoad(color_image, clamp(uv + ivec2(1, 0), ivec2(0), size - ivec2(1)));
	vec4 down = imageLoad(color_image, clamp(uv + ivec2(0, 1), ivec2(0), size - ivec2(1)));
	vec4 left = imageLoad(color_image, clamp(uv - ivec2(1, 0), ivec2(0), size - ivec2(1)));
	vec4 up = imageLoad(color_image, clamp(uv - ivec2(0, 1), ivec2(0), size - ivec2(1)));
	
	// Calculate edge strength
	float edge_h = length((right.rgb - left.rgb) * 0.5);
	float edge_v = length((down.rgb - up.rgb) * 0.5);
	float edge_strength = edge_h + edge_v;
	
	// Amplify distortion at edges
	total_distortion *= (1.0 + edge_strength * 2.0);
	
	// Apply animated wave distortion
	float wave_time = pseudo_time * 2.0;
	float wave = sin(normalized_uv.y * 20.0 + wave_time) * cos(normalized_uv.x * 15.0 - wave_time * 0.7) * 0.01;
	total_distortion.x += wave;
	total_distortion.y += wave * 0.5;
	
	// Calculate final sample position
	vec2 distorted_uv = normalized_uv + total_distortion;
	
	// Clamp to valid range
	distorted_uv = clamp(distorted_uv, 0.0, 1.0);
	
	// Sample from distorted position
	ivec2 sample_coord = ivec2(distorted_uv * vec2(size));
	sample_coord = clamp(sample_coord, ivec2(0), size - ivec2(1));
	vec4 distorted_color = imageLoad(color_image, sample_coord);
	
	// Create black hole centers (event horizons)
	vec3 final_color = distorted_color.rgb;
	
	// Darken areas near black hole centers with pulsing intensity
	float dark_pulse1 = 0.7 + sin(pseudo_time * 3.0) * 0.2;
	float dark_pulse2 = 0.6 + cos(pseudo_time * 2.5) * 0.2;
	float dark_pulse3 = 0.5 + sin(pseudo_time * 4.0) * 0.2;
	
	if (dist1 < 0.05) {
		float darkness1 = 1.0 - (dist1 / 0.05);
		final_color *= (1.0 - darkness1 * dark_pulse1);
	}
	if (dist2 < 0.03) {
		float darkness2 = 1.0 - (dist2 / 0.03);
		final_color *= (1.0 - darkness2 * dark_pulse2);
	}
	if (dist3 < 0.04) {
		float darkness3 = 1.0 - (dist3 / 0.04);
		final_color *= (1.0 - darkness3 * dark_pulse3);
	}
	
	// Add gravitational lensing effect
	float total_dist_strength = length(total_distortion);
	if (total_dist_strength > 0.01 && total_dist_strength < 0.1) {
		float lens_effect = smoothstep(0.01, 0.1, total_dist_strength);
		// Animated brightness
		float lens_brightness = 1.3 + sin(pseudo_time * 5.0) * 0.2;
		final_color = mix(final_color, final_color * lens_brightness, lens_effect * 0.5);
	}
	
	// Add chromatic aberration for more distortion
	if (total_dist_strength > 0.02) {
		// Animated aberration strength
		float aberration_amount = 1.0 + sin(pseudo_time * 7.0) * 0.2;
		
		vec2 r_uv = normalized_uv + total_distortion * (1.0 + aberration_amount * 0.1);
		vec2 g_uv = normalized_uv + total_distortion;
		vec2 b_uv = normalized_uv + total_distortion * (1.0 - aberration_amount * 0.1);
		
		ivec2 r_coord = clamp(ivec2(r_uv * vec2(size)), ivec2(0), size - ivec2(1));
		ivec2 g_coord = clamp(ivec2(g_uv * vec2(size)), ivec2(0), size - ivec2(1));
		ivec2 b_coord = clamp(ivec2(b_uv * vec2(size)), ivec2(0), size - ivec2(1));
		
		vec3 aberrated = vec3(
			imageLoad(color_image, r_coord).r,
			imageLoad(color_image, g_coord).g,
			imageLoad(color_image, b_coord).b
		);
		
		final_color = mix(final_color, aberrated, 0.5);
	}
	
	// Output
	color.rgb = final_color;
	color.a = original.a;
	"""
