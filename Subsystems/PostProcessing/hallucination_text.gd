@tool
extends PostProcessShader
class_name HallucinationTextShader

## Hallucination text effect - displays creepy scrolling text overlay
## Creates the effect of seeing disturbing messages everywhere

func _init():
	super._init()
	
	shader_code = """
	// Get normalized UV
	vec2 normalized_uv = vec2(uv) / vec2(size);
	
	// Sample original color
	vec4 original = imageLoad(color_image, uv);
	
	// Time parameter for animation (you'd need to pass this somehow)
	// For now using UV position to create variation
	float time = normalized_uv.x * 10.0 + normalized_uv.y * 5.0;
	
	// Create multiple text layers at different scales
	float text_pattern = 0.0;
	
	// Layer 1: Large creepy messages
	vec2 text_uv1 = normalized_uv * vec2(8.0, 4.0);
	text_uv1.y += time * 0.1; // Slow scroll
	vec2 cell1 = floor(text_uv1);
	vec2 cell_uv1 = fract(text_uv1);
	
	// Create fake text pattern using lines and dots
	float char1 = 0.0;
	// Horizontal lines (like text)
	char1 += step(0.3, cell_uv1.y) * step(cell_uv1.y, 0.4);
	char1 += step(0.5, cell_uv1.y) * step(cell_uv1.y, 0.6);
	char1 += step(0.7, cell_uv1.y) * step(cell_uv1.y, 0.8);
	// Vertical strokes
	char1 *= step(0.1, cell_uv1.x) * step(cell_uv1.x, 0.9);
	// Random gaps between characters
	float rand1 = fract(sin(dot(cell1, vec2(12.9898, 78.233))) * 43758.5453);
	char1 *= step(0.3, rand1);
	
	text_pattern += char1 * 0.8;
	
	// Layer 2: Medium scrambled text
	vec2 text_uv2 = normalized_uv * vec2(15.0, 10.0);
	text_uv2.x += sin(normalized_uv.y * 20.0 + time) * 0.1; // Wavy distortion
	text_uv2.y -= time * 0.2; // Faster scroll
	vec2 cell2 = floor(text_uv2);
	vec2 cell_uv2 = fract(text_uv2);
	
	// Different character pattern
	float char2 = 0.0;
	// Create cross pattern (like corrupted text)
	char2 += step(0.4, cell_uv2.x) * step(cell_uv2.x, 0.6);
	char2 += step(0.4, cell_uv2.y) * step(cell_uv2.y, 0.6);
	// Add dots
	float dot_dist = length(cell_uv2 - vec2(0.5));
	char2 += 1.0 - smoothstep(0.1, 0.2, dot_dist);
	// Random appearance
	float rand2 = fract(sin(dot(cell2 + vec2(time * 0.1), vec2(45.23, 89.45))) * 23758.5453);
	char2 *= step(0.4, rand2) * step(rand2, 0.8);
	
	text_pattern += char2 * 0.5;
	
	// Layer 3: Small flickering symbols
	vec2 text_uv3 = normalized_uv * vec2(30.0, 20.0);
	text_uv3 = fract(text_uv3 + vec2(time * 0.05, -time * 0.3));
	vec2 cell3 = floor(text_uv3 * 10.0);
	vec2 cell_uv3 = fract(text_uv3);
	
	// Simple pixel pattern
	float char3 = step(0.4, cell_uv3.x) * step(0.4, cell_uv3.y);
	float rand3 = fract(sin(dot(cell3, vec2(127.1, 311.7))) * 43758.5453);
	char3 *= step(0.7, rand3);
	// Flicker
	char3 *= 0.5 + 0.5 * sin(time * 20.0 + rand3 * 100.0);
	
	text_pattern += char3 * 0.3;
	
	// Create distortion based on text
	vec2 distort_uv = normalized_uv;
	distort_uv.x += sin(normalized_uv.y * 30.0 + time * 2.0) * text_pattern * 0.02;
	distort_uv.y += cos(normalized_uv.x * 25.0 + time * 1.5) * text_pattern * 0.02;
	
	// Sample distorted position for warping effect
	ivec2 distort_coord = ivec2(distort_uv * vec2(size));
	distort_coord = clamp(distort_coord, ivec2(0), size - ivec2(1));
	vec4 distorted = imageLoad(color_image, distort_coord);
	
	// Text colors - blood red with variations
	vec3 text_color = vec3(0.8, 0.1, 0.1);
	// Add color variation based on position
	text_color.r += sin(normalized_uv.x * 10.0) * 0.2;
	text_color.g += sin(normalized_uv.y * 15.0) * 0.05;
	
	// Create glow effect around text
	float glow = text_pattern * 0.5;
	// Expand glow
	vec2 glow_uv = normalized_uv + vec2(0.002, 0.002);
	float glow_pattern = 0.0;
	// Sample nearby for glow (simplified)
	glow_pattern += step(0.5, sin(glow_uv.x * 50.0) * sin(glow_uv.y * 30.0));
	
	// Mix everything together
	vec3 final_color = distorted.rgb;
	
	// Add red glow
	vec3 glow_color = vec3(1.0, 0.2, 0.2);
	final_color = mix(final_color, final_color + glow_color * 0.3, glow * 0.5);
	
	// Add text overlay
	final_color = mix(final_color, text_color, text_pattern * 0.7);
	
	// Add static noise for horror effect
	float noise = fract(sin(dot(normalized_uv * 1000.0 + vec2(time), vec2(12.9898, 78.233))) * 43758.5453);
	final_color = mix(final_color, vec3(noise), text_pattern * 0.1);
	
	// Darken edges for vignette
	float vignette = 1.0 - length(normalized_uv - 0.5) * 0.7;
	final_color *= vignette;
	
	// Output
	color.rgb = final_color;
	color.a = original.a;
	"""
