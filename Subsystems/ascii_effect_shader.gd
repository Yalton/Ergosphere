@tool
extends CompositorEffect
class_name ASCIIEffect

@export_range(1.0, 50.0) var pixel_size: float = 8.0
@export_range(1.0, 32.0) var color_depth: float = 4.0
@export var use_ascii: bool = true
@export var green_monitor: bool = false
@export var dithering: bool = true
@export_range(0.0, 1.0) var brightness_boost: float = 0.1

const shader_code_template = """#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float pixel_size;
	float color_depth;
	bool use_ascii;
	bool green_monitor;
	bool dithering;
	float brightness_boost;
} params;

// Function to get ASCII character value based on brightness
float get_ascii_char_value(int index) {
	if (index == 0) return 0.0;        // Darkest (space)
	else if (index == 1) return 0.3;   // .
	else if (index == 2) return 0.5;   // ,
	else if (index == 3) return 0.6;   // -
	else if (index == 4) return 0.7;   // +
	else if (index == 5) return 0.75;  // o
	else if (index == 6) return 0.8;   // a
	else if (index == 7) return 0.85;  // #
	else if (index == 8) return 0.9;   // @
	else if (index == 9) return 1.0;   // $ (brightest)
	return 0.0;
}

// Function to get dither pattern value
float get_dither_value(int x_mod, int y_mod) {
	int index = y_mod * 4 + x_mod;
	
	if (index == 0) return 0.0/16.0;
	else if (index == 1) return 8.0/16.0;
	else if (index == 2) return 2.0/16.0;
	else if (index == 3) return 10.0/16.0;
	else if (index == 4) return 12.0/16.0;
	else if (index == 5) return 4.0/16.0;
	else if (index == 6) return 14.0/16.0;
	else if (index == 7) return 6.0/16.0;
	else if (index == 8) return 3.0/16.0;
	else if (index == 9) return 11.0/16.0;
	else if (index == 10) return 1.0/16.0;
	else if (index == 11) return 9.0/16.0;
	else if (index == 12) return 15.0/16.0;
	else if (index == 13) return 7.0/16.0;
	else if (index == 14) return 13.0/16.0;
	else if (index == 15) return 5.0/16.0;
	
	return 0.0;
}

// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}
	
	// Pixelate by rounding down to the nearest pixel_size
	ivec2 pixelated_coord = ivec2(floor(vec2(uv) / params.pixel_size) * params.pixel_size);
	pixelated_coord = clamp(pixelated_coord, ivec2(0), size - ivec2(1));
	
	// Get pixelated color
	vec4 color = imageLoad(color_image, pixelated_coord);
	
	// Calculate brightness for each pixelated area
	float brightness = dot(color.rgb, vec3(0.299, 0.587, 0.114)) + params.brightness_boost;
	brightness = clamp(brightness, 0.0, 1.0);
	
	// Apply dithering if enabled
	if (params.dithering) {
		int x_mod = int(uv.x) % 4;
		int y_mod = int(uv.y) % 4;
		float dither_value = get_dither_value(x_mod, y_mod);
		brightness += (dither_value - 0.5) / params.color_depth;
		brightness = clamp(brightness, 0.0, 1.0);
	}
	
	// Reduce color depth
	float quantized_brightness = floor(brightness * params.color_depth) / params.color_depth;
	
	// Final color calculation
	if (params.use_ascii) {
		// Get ASCII character based on brightness
		int char_index = int(floor(quantized_brightness * 9.0));
		char_index = clamp(char_index, 0, 9);
		
		// Set color to ASCII character intensity
		float char_value = get_ascii_char_value(char_index);
		color.rgb = vec3(char_value);
	} else {
		// Regular pixelated look with reduced colors
		color.rgb = vec3(quantized_brightness);
	}
	
	// Apply green monitor effect if enabled
	if (params.green_monitor) {
		color.rgb = color.r * vec3(0.0, 1.0, 0.2);
	}
	
	// CRT scanline effect for additional retro feel
	float scanline = sin(float(uv.y) * 0.5) * 0.05;
	color.rgb -= scanline;
	
	// Output the processed color
	imageStore(color_image, uv, color);
}
"""

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var mutex: Mutex = Mutex.new()
var shader_is_dirty: bool = true

# Called when this resource is constructed.
func _init():
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()

# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			# Freeing our shader will also free any dependents such as the pipeline!
			rd.free_rid(shader)

# Check if our shader has changed and needs to be recompiled.
func _check_shader() -> bool:
	if not rd:
		return false
	
	mutex.lock()
	var need_recompile = shader_is_dirty
	shader_is_dirty = false
	mutex.unlock()
	
	# If we don't need to recompile, return if we have a valid pipeline
	if not need_recompile:
		return pipeline.is_valid()
	
	# Out with the old.
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
		pipeline = RID()
	
	# In with the new.
	var shader_source = RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	shader_source.source_compute = shader_code_template
	var shader_spirv = rd.shader_compile_spirv_from_source(shader_source)
	
	if shader_spirv.compile_error_compute != "":
		push_error(shader_spirv.compile_error_compute)
		push_error("In: " + shader_code_template)
		return false
	
	shader = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		return false
	
	pipeline = rd.compute_pipeline_create(shader)
	return pipeline.is_valid()

# Called by the rendering thread every frame.
func _render_callback(p_effect_callback_type, p_render_data):
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and _check_shader():
		# Get our render scene buffers object, this gives us access to our render buffers.
		var render_scene_buffers = p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			# Get our render size, this is the 3D render resolution!
			var size = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return
			
			# We can use a compute shader here
			var x_groups = (size.x - 1) / 8 + 1
			var y_groups = (size.y - 1) / 8 + 1
			var z_groups = 1
			
			# Push constant
			var push_constant = PackedFloat32Array()
			push_constant.push_back(size.x)
			push_constant.push_back(size.y)
			push_constant.push_back(pixel_size)
			push_constant.push_back(color_depth)
			push_constant.push_back(1.0 if use_ascii else 0.0)
			push_constant.push_back(1.0 if green_monitor else 0.0)
			push_constant.push_back(1.0 if dithering else 0.0)
			push_constant.push_back(brightness_boost)
			
			# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
			var view_count = render_scene_buffers.get_view_count()
			for view in range(view_count):
				# Get the RID for our color image, we will be reading from and writing to it.
				var input_image = render_scene_buffers.get_color_layer(view)
				
				# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
				var uniform = RDUniform.new()
				uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.binding = 0
				uniform.add_id(input_image)
				var uniform_set = UniformSetCacheRD.get_cache(shader, 0, [uniform])
				
				# Run our compute shader.
				var compute_list = rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()

# When any of our parameters change, mark the shader dirty to propagate changes
func _set(property, _value):
	if property in ["pixel_size", "color_depth", "use_ascii", "green_monitor", "dithering", "brightness_boost"]:
		mutex.lock()
		shader_is_dirty = true
		mutex.unlock()
	return false
