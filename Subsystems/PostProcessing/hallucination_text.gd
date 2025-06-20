extends CompositorEffect
class_name HallucinationTextEffect

## Hallucination text overlay effect - displays warped text/numbers over the screen
## Text color
@export var text_color: Color = Color(0.8, 0.1, 0.1, 0.7)
## Glow color
@export var glow_color: Color = Color(1.0, 0.2, 0.2, 0.5)
## Text size scale
@export_range(0.5, 3.0) var text_scale: float = 1.0
## Distortion amount
@export_range(0.0, 1.0) var distortion_amount: float = 0.3
## Text opacity
@export_range(0.0, 1.0) var text_opacity: float = 0.7
## Flicker intensity
@export_range(0.0, 1.0) var flicker_intensity: float = 0.3
## Scroll speed
@export var scroll_speed: float = 0.5
## Wave frequency
@export var wave_frequency: float = 3.0
## Wave amplitude
@export var wave_amplitude: float = 0.1

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var time_passed: float = 0.0

func _init():
	RenderingServer.call_on_render_thread(_initialize_compute)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			RenderingServer.call_on_render_thread(_cleanup)

func _cleanup():
	if rd and shader.is_valid():
		rd.free_rid(shader)
	shader = RID()
	pipeline = RID()

func _initialize_compute():
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		push_error("Failed to create RenderingDevice")
		return
		
	var shader_code = """
#version 460

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba16f) restrict readonly uniform image2D color_image;
layout(set = 0, binding = 1, rgba16f) restrict writeonly uniform image2D target_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
	vec4 text_color;
	vec4 glow_color;
	float text_scale;
	float distortion_amount;
	float text_opacity;
	float flicker_intensity;
	float scroll_speed;
	float wave_frequency;
	float wave_amplitude;
	float time;
} params;

// Simple pseudo-random function
float random(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Generate procedural character-like patterns
float generateCharacter(vec2 uv, int seed) {
	// Create a 5x7 grid for character
	vec2 grid = fract(uv * vec2(5.0, 7.0));
	
	// Use seed to generate different patterns
	float pattern = 0.0;
	for (int i = 0; i < 7; i++) {
		for (int j = 0; j < 5; j++) {
			vec2 cell = vec2(float(j) / 5.0, float(i) / 7.0);
			float dist = distance(grid, cell + vec2(0.1, 0.07));
			float r = random(vec2(float(seed * 35 + i * 5 + j), float(seed)));
			if (r > 0.5) {
				pattern += 1.0 - smoothstep(0.0, 0.15, dist);
			}
		}
	}
	
	return clamp(pattern, 0.0, 1.0);
}

// Create hallucination text overlay
float createHallucinationText(vec2 uv) {
	// Apply wave distortion
	float wave = sin(uv.y * params.wave_frequency + params.time * 2.0) * params.wave_amplitude;
	uv.x += wave * params.distortion_amount;
	
	// Scroll effect
	uv.y -= params.time * params.scroll_speed;
	
	// Scale for text size
	uv *= params.text_scale * 20.0;
	
	// Character grid position
	vec2 char_pos = floor(uv);
	vec2 char_uv = fract(uv);
	
	// Generate character based on position
	int seed = int(char_pos.x * 137.0 + char_pos.y * 233.0 + params.time * 10.0);
	float character = generateCharacter(char_uv, seed);
	
	// Random character appearance/disappearance
	float appear = random(char_pos + vec2(params.time * 0.1));
	character *= smoothstep(0.3, 0.7, appear);
	
	// Add distortion to individual characters
	float char_distort = random(char_pos + vec2(params.time * 0.5)) * params.distortion_amount;
	character *= 1.0 + sin(params.time * 10.0 + char_pos.x * 5.0) * char_distort;
	
	return character;
}

// Create glow effect
vec3 applyGlow(float text_mask, vec2 uv) {
	vec3 glow = vec3(0.0);
	float glow_radius = 3.0;
	float samples = 0.0;
	
	// Simple box blur for glow
	for (float x = -glow_radius; x <= glow_radius; x++) {
		for (float y = -glow_radius; y <= glow_radius; y++) {
			vec2 offset = vec2(x, y) / params.raster_size;
			float sample_text = createHallucinationText(uv + offset);
			float weight = 1.0 - length(vec2(x, y)) / glow_radius;
			glow += params.glow_color.rgb * sample_text * weight;
			samples += weight;
		}
	}
	
	return glow / max(samples, 1.0);
}

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}
	
	vec2 normalized_uv = vec2(uv) / vec2(size);
	
	// Sample original color
	vec4 original_color = imageLoad(color_image, uv);
	
	// Generate hallucination text
	float text_mask = createHallucinationText(normalized_uv);
	
	// Apply flicker
	float flicker = 1.0 - params.flicker_intensity * random(vec2(floor(params.time * 10.0)));
	text_mask *= flicker;
	
	// Apply glow
	vec3 glow = applyGlow(text_mask, normalized_uv);
	
	// Combine text and glow
	vec3 text_contribution = params.text_color.rgb * text_mask * params.text_opacity;
	vec3 final_color = original_color.rgb;
	
	// Add glow first (behind text)
	final_color = mix(final_color, final_color + glow, 0.8);
	
	// Then add text on top
	final_color = mix(final_color, text_contribution, text_mask * params.text_opacity);
	
	imageStore(target_image, uv, vec4(final_color, original_color.a));
}
"""
	
	var shader_source := RDShaderSource.new()
	shader_source.source_compute = shader_code
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	
	var shader_spirv := rd.shader_compile_spirv_from_source(shader_source)
	if shader_spirv.compile_error_compute != "":
		push_error("Compute shader compilation error: " + shader_spirv.compile_error_compute)
		return
		
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)

func _render_callback(effect_callback_type: int, render_data: RenderData):
	if not enabled or rd == null:
		return
		
	if effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return
		
	var render_scene_buffers := render_data.get_render_scene_buffers()
	var render_size: Vector2i = render_scene_buffers.get_internal_size()
	
	if render_size.x == 0 or render_size.y == 0:
		return
		
	# Update time
	time_passed += render_data.get_delta_time()
		
	# Get color buffer
	var color_image: RID = render_scene_buffers.get_color_layer(0)
	
	# Create output buffer
	var output_format := RDTextureFormat.new()
	output_format.width = render_size.x
	output_format.height = render_size.y
	output_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	output_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	
	var output_image := rd.texture_create(output_format, RDTextureView.new())
	
	# Set up compute shader
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	
	var uniform_set := rd.uniform_set_create(
		[
			rd.uniform_sampler_with_texture_create(0, rd.sampler_create(RDSamplerState.new()), color_image),
			rd.uniform_image_create(1, output_image)
		],
		shader,
		0
	)
	
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	# Push constants
	var push_constant := PackedFloat32Array([
		render_size.x, render_size.y, 0.0, 0.0,
		text_color.r, text_color.g, text_color.b, text_color.a,
		glow_color.r, glow_color.g, glow_color.b, glow_color.a,
		text_scale, distortion_amount, text_opacity, flicker_intensity,
		scroll_speed, wave_frequency, wave_amplitude, time_passed
	])
	
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	
	# Dispatch
	var work_groups_x: int = (render_size.x + 7) / 8
	var work_groups_y: int = (render_size.y + 7) / 8
	rd.compute_list_dispatch(compute_list, work_groups_x, work_groups_y, 1)
	
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	
	# Copy result back
	render_scene_buffers.set_color_layer(0, output_image)
	
	# Clean up
	rd.free_rid(output_image)
	rd.free_rid(uniform_set)
