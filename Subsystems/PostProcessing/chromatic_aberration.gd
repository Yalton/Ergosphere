@tool
extends PostProcessShader
class_name ChromaticAberrationShader

## Chromatic aberration shader that splits RGB channels
## Creates a disorienting lens distortion effect

func _init():
	super._init()
	
	shader_code = """
	// Calculate distance from center for radial effect
	vec2 center = vec2(size) * 0.5;
	vec2 current_pos = vec2(uv);
	float dist_from_center = length(current_pos - center) / length(center);
	
	// Base aberration strength - increases toward edges
	float aberration_strength = 4.0 * dist_from_center * dist_from_center;
	
	// Calculate offset directions
	vec2 direction = normalize(current_pos - center);
	ivec2 red_offset = ivec2(direction * aberration_strength);
	ivec2 blue_offset = ivec2(-direction * aberration_strength);
	
	// Clamp coordinates to prevent out-of-bounds access
	ivec2 red_coord = clamp(uv + red_offset, ivec2(0), size - ivec2(1));
	ivec2 blue_coord = clamp(uv + blue_offset, ivec2(0), size - ivec2(1));
	
	// Sample colors at offset positions
	vec4 red_sample = imageLoad(color_image, red_coord);
	vec4 blue_sample = imageLoad(color_image, blue_coord);
	
	// Keep green channel from original position, offset red and blue
	color.r = red_sample.r;
	color.b = blue_sample.b;
	
	// Add subtle vignette effect to enhance the distortion
	float vignette = 1.0 - dist_from_center * 0.5;
	color.rgb *= vignette;
	
	// Slight desaturation for horror atmosphere
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(vec3(gray), color.rgb, 0.85);
	"""
