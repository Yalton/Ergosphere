extends CompositorEffect
class_name ShapeDilationEffect


## Scale of the dilation effect - larger values create bigger distortion areas
@export var scale: float = 1.0

## Strength of the distortion - how much pixels are pulled
@export var distortion_strength: float = 0.1

## Size of the black hole center
@export var black_hole_size: float = 0.1

## Edge detection threshold
@export var edge_threshold: float = 0.01

var rd: RenderingDevice
var shader: RID
var pipeline: RID

func _init():
	RenderingServer.call_on_render_thread(_initialize_compute)
	
func _initialize_compute():
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		return
		
	var shader_code = """
#version 460

// Workgroup size
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// Bindings
layout(set = 0, binding = 0, rgba16f) restrict readonly uniform image2D color_image;
layout(set = 0, binding = 1, rgba16f) restrict writeonly uniform image2D target_image;
layout(set = 0, binding = 2, r32f) restrict readonly uniform image2D depth_image;
layout(set = 0, binding = 3, r32f) restrict readonly uniform image2D object_mask;

// Push constants
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
	float scale;
	float distortion_strength;
	float black_hole_size;
	float edge_threshold;
} params;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}
	
	// Read object mask
	float mask_value = imageLoad(object_mask, uv).r;
	
	// Inside object - make it black
	if (mask_value > 0.5) {
		imageStore(target_image, uv, vec4(0.0, 0.0, 0.0, 1.0));
		return;
	}
	
	// Find nearest edge point
	vec2 nearest_edge = vec2(0.0);
	float min_distance = 10000.0;
	bool found_edge = false;
	
	// Search for edges
	int search_radius = int(params.scale * 50.0);
	for (int r = 1; r < search_radius && !found_edge; r += 2) {
		int samples = r * 8;
		for (int i = 0; i < samples; i++) {
			float angle = float(i) * 6.28318 / float(samples);
			ivec2 offset = ivec2(cos(angle) * float(r), sin(angle) * float(r));
			ivec2 sample_pos = uv + offset;
			
			if (sample_pos.x < 0 || sample_pos.x >= size.x || 
				sample_pos.y < 0 || sample_pos.y >= size.y) continue;
			
			float sample_mask = imageLoad(object_mask, sample_pos).r;
			
			// Check if we found an edge
			if (sample_mask > 0.5) {
				float dist = length(vec2(offset));
				if (dist < min_distance) {
					min_distance = dist;
					nearest_edge = normalize(vec2(sample_pos - uv));
					found_edge = true;
				}
			}
		}
	}
	
	// Apply distortion based on distance to edge
	vec2 distorted_uv = vec2(uv);
	if (found_edge) {
		float normalized_dist = min_distance / (params.scale * 50.0);
		float distortion_amount = exp(-normalized_dist * normalized_dist * 4.0);
		distorted_uv += nearest_edge * distortion_amount * params.distortion_strength * size.x * 0.1;
	}
	
	// Clamp and sample
	ivec2 final_uv = ivec2(clamp(distorted_uv, vec2(0.0), vec2(size) - vec2(1.0)));
	vec4 color = imageLoad(color_image, final_uv);
	
	imageStore(target_image, uv, color);
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
		
	# Get color buffer
	var color_image: RID = render_scene_buffers.get_color_layer(0)
	
	# Get depth buffer
	var depth_image: RID = render_scene_buffers.get_depth_layer(0)
	
	# Create object mask buffer (this would be filled by your object shader)
	var mask_format := RDTextureFormat.new()
	mask_format.width = render_size.x
	mask_format.height = render_size.y
	mask_format.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
	mask_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	
	var mask_image := rd.texture_create(mask_format, RDTextureView.new())
	
	# Create output buffer
	var output_format := RDTextureFormat.new()
	output_format.width = render_size.x
	output_format.height = render_size.y
	output_format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	output_format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT
	
	var output_image := rd.texture_create(output_format, RDTextureView.new())
	
	# Create uniform set
	var uniform_set := rd.uniform_set_create([
		_get_image_uniform(color_image, 0),
		_get_image_uniform(output_image, 1),
		_get_image_uniform(depth_image, 2),
		_get_image_uniform(mask_image, 3)
	], shader, 0)
	
	# Push constants
	var push_constant := PackedFloat32Array()
	push_constant.append(render_size.x)
	push_constant.append(render_size.y)
	push_constant.append(0.0) # reserved
	push_constant.append(0.0) # reserved
	push_constant.append(scale)
	push_constant.append(distortion_strength)
	push_constant.append(black_hole_size)
	push_constant.append(edge_threshold)
	
	# Dispatch compute shader
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, (render_size.x - 1) / 8 + 1, (render_size.y - 1) / 8 + 1, 1)
	rd.compute_list_end()
	
	rd.submit()
	rd.sync()
	
	# Copy result back to color buffer
	render_scene_buffers.set_color_layer(0, output_image)

func _get_image_uniform(image: RID, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(image)
	return uniform
