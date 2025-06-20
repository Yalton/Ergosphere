extends CompositorEffect
class_name PurpleLightEffect

## Purple light post-processing effect that makes everything look lit by purple light
## Primary purple color
@export var purple_color: Color = Color(0.7, 0.2, 1.0, 1.0)
## Secondary purple color for variation
@export var secondary_color: Color = Color(0.9, 0.3, 0.8, 1.0)
## Light intensity
@export_range(0.0, 2.0) var intensity: float = 1.0
## Shadow darkness - how much to darken non-lit areas
@export_range(0.0, 1.0) var shadow_darkness: float = 0.5
## Light falloff - how light fades with distance
@export_range(0.1, 5.0) var light_falloff: float = 2.0
## Pulsing effect
@export var enable_pulse: bool = true
## Pulse speed
@export var pulse_speed: float = 2.0
## Pulse intensity variation
@export_range(0.0, 1.0) var pulse_amount: float = 0.3

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
layout(set = 0, binding = 2, r32f) restrict readonly uniform image2D depth_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
	vec4 purple_color;
	vec4 secondary_color;
	float intensity;
	float shadow_darkness;
	float light_falloff;
	float time;
	float pulse_speed;
	float pulse_amount;
	float enable_pulse;
} params;

// Simple pseudo-random function
float random(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Calculate luminance
float getLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

// Simulate purple light with depth-based falloff
vec3 applyPurpleLight(vec3 original_color, float depth, vec2 uv) {
	// Calculate base lighting
	float luminance = getLuminance(original_color);
	
	// Create multiple purple light sources
	vec2 light_pos1 = vec2(0.3, 0.2) + vec2(sin(params.time * 0.7), cos(params.time * 0.5)) * 0.1;
	vec2 light_pos2 = vec2(0.7, 0.8) + vec2(cos(params.time * 0.9), sin(params.time * 0.6)) * 0.15;
	
	float dist1 = distance(uv, light_pos1);
	float dist2 = distance(uv, light_pos2);
	
	// Calculate light influence based on distance
	float light_influence1 = pow(max(0.0, 1.0 - dist1), params.light_falloff);
	float light_influence2 = pow(max(0.0, 1.0 - dist2), params.light_falloff);
	
	// Mix the two purple colors based on position
	vec3 purple_mix = mix(params.purple_color.rgb, params.secondary_color.rgb, 
						  sin(uv.x * 3.14159 + params.time) * 0.5 + 0.5);
	
	// Apply pulsing if enabled
	float pulse_factor = 1.0;
	if (params.enable_pulse > 0.5) {
		pulse_factor = 1.0 + sin(params.time * params.pulse_speed) * params.pulse_amount;
	}
	
	// Calculate final light contribution
	float total_light = (light_influence1 + light_influence2) * params.intensity * pulse_factor;
	
	// Apply purple lighting
	vec3 lit_color = original_color * purple_mix;
	
	// Add rim lighting effect based on depth
	float depth_edge = fwidth(depth) * 100.0;
	float rim_light = smoothstep(0.0, 1.0, depth_edge) * luminance;
	lit_color += purple_mix * rim_light * 0.5;
	
	// Mix based on light influence and add shadows
	vec3 shadow_color = original_color * params.shadow_darkness;
	vec3 final_color = mix(shadow_color, lit_color, clamp(total_light, 0.0, 1.0));
	
	// Add subtle noise for atmosphere
	float noise = random(uv + vec2(params.time * 0.1)) * 0.05;
	final_color += purple_mix * noise * params.intensity;
	
	return final_color;
}

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}
	
	vec2 normalized_uv = vec2(uv) / vec2(size);
	
	// Sample original color and depth
	vec4 original_color = imageLoad(color_image, uv);
	float depth = imageLoad(depth_image, uv).r;
	
	// Apply purple light effect
	vec3 final_color = applyPurpleLight(original_color.rgb, depth, normalized_uv);
	
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
		
	# Get buffers
	var color_image: RID = render_scene_buffers.get_color_layer(0)
	var depth_image: RID = render_scene_buffers.get_depth_layer(0)
	
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
			rd.uniform_image_create(1, output_image),
			rd.uniform_sampler_with_texture_create(2, rd.sampler_create(RDSamplerState.new()), depth_image)
		],
		shader,
		0
	)
	
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	# Push constants
	var push_constant := PackedFloat32Array([
		render_size.x, render_size.y, 0.0, 0.0,
		purple_color.r, purple_color.g, purple_color.b, purple_color.a,
		secondary_color.r, secondary_color.g, secondary_color.b, secondary_color.a,
		intensity, shadow_darkness, light_falloff, time_passed,
		pulse_speed, pulse_amount, 1.0 if enable_pulse else 0.0, 0.0
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
