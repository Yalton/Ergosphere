@tool
extends PostProcessShader
class_name GlitchShader

## Digital glitch shader for entity manifestations and reality breaks
## Creates horizontal displacement, color channel splitting, and noise

func _init():
	super._init()
	
	shader_code = """
	// Create pseudo-random value based on position
	float rand = fract(sin(dot(vec2(uv.y, uv.x * 0.01), vec2(12.9898, 78.233))) * 43758.5453);
	
	// Horizontal glitch lines - random chance per row
	bool should_glitch = rand < 0.05; // 5% of rows glitch
	
	if (should_glitch) {
		// Calculate glitch offset
		float glitch_strength = 20.0;
		int offset = int((rand - 0.5) * glitch_strength);
		
		// RGB channel splitting for glitched rows
		if (rand < 0.02) { // 2% chance for severe glitch
			// Severe glitch - separate RGB channels
			ivec2 r_coord = clamp(ivec2(uv.x + offset + 5, uv.y), ivec2(0), size - ivec2(1));
			ivec2 g_coord = clamp(ivec2(uv.x + offset, uv.y), ivec2(0), size - ivec2(1));
			ivec2 b_coord = clamp(ivec2(uv.x + offset - 5, uv.y), ivec2(0), size - ivec2(1));
			
			vec4 r_sample = imageLoad(color_image, r_coord);
			vec4 g_sample = imageLoad(color_image, g_coord);
			vec4 b_sample = imageLoad(color_image, b_coord);
			
			color.r = r_sample.r;
			color.g = g_sample.g;
			color.b = b_sample.b;
			
			// Add noise to glitched areas
			float noise = fract(sin(float(uv.x + uv.y) * 78.233) * 43758.5453);
			color.rgb = mix(color.rgb, vec3(noise), 0.3);
		} else {
			// Mild glitch - just displacement
			ivec2 glitch_coord = clamp(ivec2(uv.x + offset, uv.y), ivec2(0), size - ivec2(1));
			color = imageLoad(color_image, glitch_coord);
		}
	}
	
	// Occasional static blocks
	float block_size = 32.0;
	vec2 block_pos = floor(vec2(uv) / block_size);
	float block_rand = fract(sin(dot(block_pos, vec2(12.9898, 78.233))) * 43758.5453);
	
	if (block_rand < 0.01) { // 1% chance per block
		float static_noise = fract(sin(float(uv.x * uv.y) * 43758.5453));
		color.rgb = vec3(static_noise);
	}
	
	// Subtle scan lines for CRT feel
	float scanline = sin(float(uv.y) * 800.0) * 0.02;
	color.rgb -= scanline;
	
	// Color quantization for digital artifact feel
	float levels = 32.0;
	color.rgb = floor(color.rgb * levels) / levels;
	"""
