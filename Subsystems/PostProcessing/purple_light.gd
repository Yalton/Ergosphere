@tool
extends PostProcessShader
class_name PurpleChromeShader

## Purple chrome/liquid metal effect - makes everything look like reflective purple chrome
## Creates a dramatic, mirror-like purple metallic finish

func _init():
	super._init()
	
	shader_code = """
	// Get normalized UV
	vec2 normalized_uv = vec2(uv) / vec2(size);
	
	// Sample original and neighboring pixels for edge detection
	vec4 original = imageLoad(color_image, uv);
	vec4 right = imageLoad(color_image, clamp(uv + ivec2(1, 0), ivec2(0), size - ivec2(1)));
	vec4 down = imageLoad(color_image, clamp(uv + ivec2(0, 1), ivec2(0), size - ivec2(1)));
	vec4 left = imageLoad(color_image, clamp(uv - ivec2(1, 0), ivec2(0), size - ivec2(1)));
	vec4 up = imageLoad(color_image, clamp(uv - ivec2(0, 1), ivec2(0), size - ivec2(1)));
	
	// Calculate gradients for surface normals (fake reflection)
	vec3 dx = (right.rgb - left.rgb) * 0.5;
	vec3 dy = (down.rgb - up.rgb) * 0.5;
	vec3 normal = normalize(vec3(dx.r + dx.g + dx.b, dy.r + dy.g + dy.b, 1.0));
	
	// Calculate luminance
	float luminance = dot(original.rgb, vec3(0.299, 0.587, 0.114));
	
	// Chrome color palette - purple to gold
	vec3 chrome_dark = vec3(0.1, 0.0, 0.2);    // Almost black purple
	vec3 chrome_shadow = vec3(0.3, 0.05, 0.5); // Dark purple chrome
	vec3 chrome_mid = vec3(0.6, 0.2, 0.8);     // Purple chrome
	vec3 chrome_light = vec3(0.9, 0.5, 1.0);   // Light purple chrome
	vec3 chrome_bright = vec3(1.0, 0.7, 0.9);  // Purple-tinted gold chrome
	vec3 chrome_spec = vec3(1.2, 0.9, 1.1);    // Over-bright specular
	
	// Create chrome gradient with sharp transitions
	vec3 chrome_color;
	float adjusted_lum = pow(luminance, 0.5); // Adjust curve for more metallic look
	
	if (adjusted_lum < 0.15) {
		chrome_color = chrome_dark;
	} else if (adjusted_lum < 0.3) {
		// Sharp transition from dark to shadow
		float t = smoothstep(0.15, 0.3, adjusted_lum);
		chrome_color = mix(chrome_dark, chrome_shadow, t);
	} else if (adjusted_lum < 0.5) {
		// Gradual mid-tone transition
		float t = (adjusted_lum - 0.3) / 0.2;
		chrome_color = mix(chrome_shadow, chrome_mid, t);
	} else if (adjusted_lum < 0.7) {
		// Sharp highlight transition
		float t = smoothstep(0.5, 0.7, adjusted_lum);
		chrome_color = mix(chrome_mid, chrome_light, t * t); // Squared for sharper
	} else if (adjusted_lum < 0.85) {
		// Bright areas
		float t = (adjusted_lum - 0.7) / 0.15;
		chrome_color = mix(chrome_light, chrome_bright, t);
	} else {
		// Super bright specular
		float t = (adjusted_lum - 0.85) / 0.15;
		chrome_color = mix(chrome_bright, chrome_spec, t);
	}
	
	// Add environment map simulation using normal
	vec2 env_uv = normal.xy * 0.5 + 0.5;
	float env_pattern = sin(env_uv.x * 20.0) * sin(env_uv.y * 20.0);
	vec3 reflection = mix(chrome_mid, chrome_bright, env_pattern * 0.5 + 0.5);
	
	// Mix in reflection based on surface angle
	float fresnel = 1.0 - abs(normal.z);
	fresnel = pow(fresnel, 2.0);
	chrome_color = mix(chrome_color, reflection, fresnel * 0.5);
	
	// Add anisotropic streaks for brushed metal effect
	float streak = sin(normalized_uv.y * 100.0 + normal.x * 10.0) * 0.5 + 0.5;
	streak *= pow(luminance, 2.0); // Only on bright areas
	chrome_color = mix(chrome_color, chrome_spec, streak * 0.3);
	
	// Sharp specular highlights based on edges
	float edge_strength = length(vec2(dx.r + dx.g + dx.b, dy.r + dy.g + dy.b));
	vec3 edge_highlight = chrome_spec * smoothstep(0.1, 0.3, edge_strength);
	chrome_color += edge_highlight * 0.5;
	
	// Add rainbow iridescence for oil-slick effect
	float iridescence_factor = sin(luminance * 15.0 + normalized_uv.x * 5.0) * 0.5 + 0.5;
	vec3 iridescence = vec3(
		sin(iridescence_factor * 6.28 + 0.0) * 0.5 + 0.5,
		sin(iridescence_factor * 6.28 + 2.094) * 0.5 + 0.5,
		sin(iridescence_factor * 6.28 + 4.189) * 0.5 + 0.5
	);
	chrome_color = mix(chrome_color, chrome_color * iridescence, 0.2);
	
	// High contrast adjustment for chrome look
	chrome_color = pow(chrome_color, vec3(0.7));
	
	// Add subtle dithering to reduce banding
	float dither = fract(sin(dot(normalized_uv * 1000.0, vec2(12.9898, 78.233))) * 43758.5453) * 0.01;
	chrome_color += vec3(dither);
	
	// Final color
	color.rgb = clamp(chrome_color, 0.0, 1.5); // Allow slight over-bright
	color.a = original.a;
	"""
