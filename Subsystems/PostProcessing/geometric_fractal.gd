@tool
extends PostProcessShader
class_name GeometricFractalShader

## Geometric/Fractal post-processing effect that transforms the screen into kaleidoscopic patterns
## Creates a dramatic fractal/kaleidoscope effect with the image

func _init():
	super._init()
	
	shader_code = """
	// Constants
	const float PI = 3.14159265359;
	const float TAU = 6.28318530718;
	
	// Get normalized UV (0-1 range)
	vec2 normalized_uv = vec2(uv) / vec2(size);
	vec2 centered_uv = normalized_uv - 0.5;
	
	// Convert to polar coordinates
	float radius = length(centered_uv);
	float angle = atan(centered_uv.y, centered_uv.x);
	
	// Parameters (you can expose these later)
	float segments = 6.0; // Number of kaleidoscope segments
	float pattern_scale = 2.0; // Scale of the pattern
	int fractal_depth = 2; // Fractal iterations
	float time = 0.0; // Add time parameter if you want animation
	
	// Kaleidoscope effect
	float segment_angle = TAU / segments;
	float segment_index = floor(angle / segment_angle);
	float local_angle = mod(angle, segment_angle);
	
	// Mirror every other segment
	if (mod(segment_index, 2.0) == 1.0) {
		local_angle = segment_angle - local_angle;
	}
	
	// Reconstruct position with mirrored angle
	float final_angle = local_angle + segment_index * segment_angle;
	vec2 kaleidoscope_pos = vec2(
		radius * cos(final_angle),
		radius * sin(final_angle)
	);
	
	// Apply fractal transformation
	vec2 fractal_uv = kaleidoscope_pos;
	for (int i = 0; i < fractal_depth; i++) {
		// Scale and rotate for each iteration
		fractal_uv *= pattern_scale;
		
		// Fold space (creates fractal patterns)
		fractal_uv = abs(fractal_uv);
		if (fractal_uv.x > fractal_uv.y) {
			fractal_uv = fractal_uv.yx;
		}
		
		// Mirror folding
		if (fractal_uv.x > 0.5) {
			fractal_uv.x = 1.0 - fractal_uv.x;
		}
		if (fractal_uv.y > 0.5) {
			fractal_uv.y = 1.0 - fractal_uv.y;
		}
		
		// Scale down for next iteration
		fractal_uv *= 0.7;
	}
	
	// Convert back to screen coordinates
	vec2 sample_uv = (fractal_uv + 0.5);
	
	// Wrap coordinates
	sample_uv = fract(sample_uv);
	
	// Convert to pixel coordinates
	ivec2 sample_coord = ivec2(sample_uv * vec2(size));
	sample_coord = clamp(sample_coord, ivec2(0), size - ivec2(1));
	
	// Sample the transformed position
	vec4 fractal_color = imageLoad(color_image, sample_coord);
	
	// Add color shifting based on segment
	vec3 color_shift = vec3(
		sin(segment_index * 0.7) * 0.5 + 0.5,
		sin(segment_index * 1.3 + 2.0) * 0.5 + 0.5,
		sin(segment_index * 2.1 + 4.0) * 0.5 + 0.5
	);
	
	// Mix in color shift
	fractal_color.rgb = mix(fractal_color.rgb, fractal_color.rgb * color_shift, 0.4);
	
	// Add concentric rings overlay
	float ring_pattern = sin(radius * 20.0) * 0.5 + 0.5;
	fractal_color.rgb = mix(fractal_color.rgb, fractal_color.rgb * 1.5, ring_pattern * 0.3);
	
	// Edge darkening for vignette effect
	float edge_fade = 1.0 - smoothstep(0.2, 0.5, radius);
	fractal_color.rgb *= edge_fade;
	
	// Enhance contrast
	fractal_color.rgb = pow(fractal_color.rgb, vec3(0.9));
	
	// Set final color
	color = fractal_color;
	"""
