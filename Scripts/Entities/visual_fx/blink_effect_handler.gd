# BlinkEffectHandler.gd
extends BaseVisualEffect
class_name BlinkEffectHandler

## Blink effect handler - fades to black and back
## Uses a ColorRect with a shader overlay instead of compositor

@export_group("Blink Settings")
## Reference to the blink ColorRect with shader material
@export var blink_rect: ColorRect
## Sound to play during blink
@export var blink_sound: AudioStream
## Color to blink to (will be set in shader)
@export var blink_color: Color = Color.BLACK
## Whether to create a ColorRect if none is assigned
@export var auto_create_rect: bool = true

var shader_material: ShaderMaterial = null

func _ready() -> void:
	super._ready()
	effect_id = "blink"
	effect_name = "Blink"
	compositor_index = -1  # No compositor effect
	module_name = "VFX_Blink"
	
	# Try to find or create blink rect if not assigned
	if not blink_rect and auto_create_rect:
		_create_blink_rect()
	
	# Setup the shader material
	if blink_rect:
		_setup_shader_material()
	
	DebugLogger.debug(module_name, "Blink effect handler ready")

func _setup_shader_material() -> void:
	"""Setup the shader material and initial parameters"""
	if not blink_rect:
		return
	
	# Get the shader material
	if blink_rect.material and blink_rect.material is ShaderMaterial:
		shader_material = blink_rect.material as ShaderMaterial
		
		# Set initial shader parameters
		shader_material.set_shader_parameter("blink_progress", 0.0)
		shader_material.set_shader_parameter("blink_color", blink_color)
		
		# Ensure rect is setup properly
		blink_rect.visible = false
		blink_rect.z_index = 100
		blink_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		DebugLogger.debug(module_name, "Shader material configured")
	else:
		DebugLogger.error(module_name, "No shader material found on blink rect")

func _create_blink_rect() -> void:
	"""Create a fullscreen ColorRect for the blink effect"""
	DebugLogger.info(module_name, "Auto-creating blink ColorRect")
	
	var viewport = get_viewport()
	if not viewport:
		DebugLogger.error(module_name, "Could not get viewport for blink rect")
		return
	
	# Create a new ColorRect
	blink_rect = ColorRect.new()
	blink_rect.name = "BlinkEffectRect"
	blink_rect.visible = false
	blink_rect.z_index = 100
	blink_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it fullscreen
	blink_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blink_rect.size = viewport.get_visible_rect().size
	
	# Note: You'll need to assign the shader material manually or load it here
	DebugLogger.warning(module_name, "Blink rect created but needs shader material assigned")
	
	# Add to the scene
	var ui_root = get_tree().get_first_node_in_group("ui_layer")
	if ui_root:
		ui_root.add_child(blink_rect)
	else:
		get_tree().root.add_child(blink_rect)
		DebugLogger.warning(module_name, "Added blink rect to root - consider adding a UI layer")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Blink startup phase (%.1fs)" % time)
	
	if not blink_rect:
		DebugLogger.error(module_name, "No blink rect available")
		return
	
	if not shader_material:
		DebugLogger.error(module_name, "No shader material available")
		return
	
	# Play sound
	if blink_sound:
		play_effect_audio(blink_sound)
	
	# Update blink color in shader
	shader_material.set_shader_parameter("blink_color", blink_color)
	
	# Show rect and start with 0 progress
	blink_rect.visible = true
	shader_material.set_shader_parameter("blink_progress", 0.0)
	
	# Fade in by animating blink_progress
	if time > 0:
		var tween = create_tween()
		tween.tween_method(
			func(value): shader_material.set_shader_parameter("blink_progress", value),
			0.0, 
			1.0, 
			time
		)
		await tween.finished
	else:
		shader_material.set_shader_parameter("blink_progress", 1.0)

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Blink duration phase (%.1fs)" % time)
	
	if not blink_rect or not shader_material:
		return
	
	# Hold the blink at full opacity
	shader_material.set_shader_parameter("blink_progress", 1.0)
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Blink wind down phase (%.1fs)" % time)
	
	if not blink_rect or not shader_material:
		return
	
	# Fade out by animating blink_progress back to 0
	if time > 0:
		var tween = create_tween()
		tween.tween_method(
			func(value): shader_material.set_shader_parameter("blink_progress", value),
			1.0, 
			0.0, 
			time
		)
		await tween.finished
	else:
		shader_material.set_shader_parameter("blink_progress", 0.0)
	
	# Hide rect
	blink_rect.visible = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up blink effect")
	
	if blink_rect and shader_material:
		blink_rect.visible = false
		shader_material.set_shader_parameter("blink_progress", 0.0)

func stop_immediately() -> void:
	if blink_rect and shader_material:
		# Reset shader parameters
		shader_material.set_shader_parameter("blink_progress", 0.0)
		blink_rect.visible = false
	
	super.stop_immediately()

## Helper function to set a custom blink color at runtime
func set_blink_color(color: Color) -> void:
	blink_color = color
	if shader_material:
		shader_material.set_shader_parameter("blink_color", color)
