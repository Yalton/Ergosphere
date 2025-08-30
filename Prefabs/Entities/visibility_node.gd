extends Node3D

## Visual indicator that shows through walls. Attach as child of AvatarIconoclast.
@export var indicator_color: Color = Color(1.0, 0.0, 1.0, 0.8)
## Size of the indicator sphere
@export var indicator_size: float = 0.5
## Height offset from avatar position
@export var height_offset: float = 2.0
## Enable pulsing animation
@export var enable_pulse: bool = true
## Pulse speed
@export var pulse_speed: float = 2.0

var mesh_instance: MeshInstance3D
var material: ShaderMaterial

func _ready():
	DebugLogger.register_module("AvatarIndicator")
	_create_indicator()

func _create_indicator():
	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Create sphere mesh
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = indicator_size
	sphere_mesh.height = indicator_size * 2.0
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	mesh_instance.mesh = sphere_mesh
	
	# Position it above the avatar
	mesh_instance.position.y = height_offset
	
	# Create shader material that renders through everything
	material = ShaderMaterial.new()
	material.shader = _create_xray_shader()
	material.set_shader_parameter("indicator_color", indicator_color)
	mesh_instance.material_override = material
	
	# Disable shadows
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	DebugLogger.log_message("AvatarIndicator", "Indicator created")

func _create_xray_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;

uniform vec4 indicator_color : source_color = vec4(1.0, 0.0, 1.0, 0.8);
uniform float pulse_amplitude = 0.2;
uniform float pulse_speed = 2.0;

void vertex() {
	// Apply pulsing scale
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amplitude;
	VERTEX *= pulse;
}

void fragment() {
	ALBEDO = indicator_color.rgb;
	ALPHA = indicator_color.a;
}
"""
	return shader

func _process(delta):
	if enable_pulse and material:
		var pulse = 0.2 * sin(Time.get_ticks_msec() / 1000.0 * pulse_speed)
		material.set_shader_parameter("pulse_amplitude", pulse)

func set_indicator_color(color: Color):
	indicator_color = color
	if material:
		material.set_shader_parameter("indicator_color", color)

func set_indicator_visible(visible: bool):
	if mesh_instance:
		mesh_instance.visible = visible
