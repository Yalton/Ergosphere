extends CompositorEffect
class_name GeometricFractalEffect

## Geometric/Fractal post-processing effect that transforms the screen into geometric patterns
## Number of geometric segments (3 = triangles, 6 = hexagons, etc)
@export_range(3, 12) var segments: int = 6
## Scale of the geometric pattern
@export_range(0.1, 5.0) var pattern_scale: float = 1.0
## Fractal recursion depth
@export_range(1, 4) var fractal_depth: int = 2
## Edge softness
@export_range(0.0, 1.0) var edge_softness: float = 0.1
## Animation speed
@export var animation_speed: float = 0.5

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
	float segments;
	float pattern_scale;
	float fractal_depth;
	float edge_softness;
	float time;
	float animation_speed;
} params;

// Convert to polar coordinates
vec2 toPolar(vec2 cartesian) {
	float r = length(cartesian);
	float theta = atan(cartesian.y, cartesian.x);
	return vec2(r, theta);
}

// Convert from polar to cartesian
vec2 toCartesian(vec2 polar) {
	return vec2(polar.x * cos(polar.y), polar.x * sin(polar.y));
}

// Create geometric pattern
float geometricPattern(vec2 uv, float segments, float scale) {
	vec2 centered = (uv - 0.5) * scale;
	vec2 polar = toPolar(centered);
	
	// Quantize angle to create segments
	float angleStep = 6.28318 / segments;
	float quantizedAngle = floor(polar.y / angleStep) * angleStep + angleStep * 0.5;
	
	// Create hexagonal/polygonal cells
	vec2 quantizedPos = toCartesian(vec2(polar.x, quantizedAngle));
	float dist = length(centered - quantizedPos);
	
	return 1.0 - smoothstep(0.0, params.edge_softness * scale, dist);
}

// Fractal recursion
vec3 fractalGeometry(vec2 uv, int depth) {
	vec3 result = vec3(0.0);
	float scale = params.pattern_scale;
	float amplitude = 1.0;
	
	for (int i = 0; i < depth; i++) {
		float pattern = geometricPattern(uv + vec2(sin(params.time * params.animation_speed * (i + 1)), 
													cos(params.time * params.animation_speed * (i + 1))) * 0.1, 
										params.segments, scale);
		result += vec3(pattern) * amplitude;
		
		scale *= 2.0;
		amplitude *= 0.5;
	}
	
	return result / float(depth);
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
	
	// Apply fractal geometric transformation
	vec3 pattern = fractalGeometry(normalized_uv, int(params.fractal_depth));
	
	// Mix with original based on pattern intensity
	vec3 final_color = mix(original_color.rgb * 0.3, original_color.rgb, pattern);
	
	// Add subtle color shifting based on segment
	vec2 centered = (normalized_uv - 0.5) * params.pattern_scale;
	vec2 polar = toPolar(centered);
	float segment = floor(polar.y / (6.28318 / params.segments));
	vec3 segment_tint = vec3(
		sin(segment * 0.7) * 0.5 + 0.5,
		sin(segment * 1.3 + 2.0) * 0.5 + 0.5,
		sin(segment * 2.1 + 4.0) * 0.5 + 0.5
	);
	
	final_color = mix(final_color, final_color * segment_tint, 0.2);
	
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
		float(segments), pattern_scale, float(fractal_depth), edge_softness,
		time_passed, animation_speed, 0.0, 0.0
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
