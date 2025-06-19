@tool
extends PostProcessShader
class_name OutlineDetectionShader

## Edge detection shader that creates unsettling outlines
## Perfect for entity appearances or reality distortion effects

func _init():
	super._init()
	
	# Sobel edge detection with adjustable threshold
	shader_code = """
	// Sample neighboring pixels for edge detection
	vec4 top = imageLoad(color_image, uv + ivec2(0, -1));
	vec4 bottom = imageLoad(color_image, uv + ivec2(0, 1));
	vec4 left = imageLoad(color_image, uv + ivec2(-1, 0));
	vec4 right = imageLoad(color_image, uv + ivec2(1, 0));
	
	// Calculate luminance for each sample
	float lum_center = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	float lum_top = dot(top.rgb, vec3(0.299, 0.587, 0.114));
	float lum_bottom = dot(bottom.rgb, vec3(0.299, 0.587, 0.114));
	float lum_left = dot(left.rgb, vec3(0.299, 0.587, 0.114));
	float lum_right = dot(right.rgb, vec3(0.299, 0.587, 0.114));
	
	// Sobel operators
	float sobel_x = abs(lum_right - lum_left);
	float sobel_y = abs(lum_bottom - lum_top);
	float edge = sqrt(sobel_x * sobel_x + sobel_y * sobel_y);
	
	// Edge threshold - adjust for sensitivity
	float threshold = 0.15;
	float edge_strength = smoothstep(threshold, threshold + 0.05, edge);
	
	// Create creepy outline effect
	vec3 outline_color = vec3(0.0, 0.0, 0.0); // Black outlines
	vec3 background_color = color.rgb * 0.8; // Darken the background
	
	// Mix based on edge detection
	color.rgb = mix(background_color, outline_color, edge_strength);
	
	// Add subtle red tint to edges for horror effect
	if (edge_strength > 0.5) {
		color.r += edge_strength * 0.2;
	}
	"""
