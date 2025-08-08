# WarpEffectHandler.gd
extends BaseVisualEffect
class_name WarpEffectHandler

## Warp visual effect handler
## Uses a ColorRect with warp shader instead of compositor

@export_group("Warp Settings")
## Reference to the warp ColorRect with shader
@export var warp_rect: ColorRect
## Sound to play when warp starts
@export var warp_start_sound: AudioStream
## Sound to play when warp ends
@export var warp_end_sound: AudioStream
## Whether to auto-create rect if not assigned
@export var auto_create_rect: bool = true
## Maximum warp strength
@export var max_warp_strength: float = 0.7

func _ready() -> void:
	super._ready()
	effect_id = "warp"
	effect_name = "Warp"
	compositor_index = -1  # No compositor effect, uses ColorRect
	module_name = "VFX_Warp"
	
	# Try to find or create warp rect if not assigned
	if not warp_rect and auto_create_rect:
		_create_warp_rect()
	
	# Ensure warp rect is hidden
	if warp_rect:
		warp_rect.visible = false
		warp_rect.modulate.a = 0.0
		warp_rect.z_index = 99  # Just below blink
	
	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "Warp effect handler ready")

func _create_warp_rect() -> void:
	"""Create a fullscreen ColorRect for the warp effect"""
	DebugLogger.info(module_name, "Auto-creating warp ColorRect")
	
	var viewport = get_viewport()
	if not viewport:
		DebugLogger.error(module_name, "Could not get viewport for warp rect")
		return
	
	# Create a new ColorRect
	warp_rect = ColorRect.new()
	warp_rect.name = "WarpEffectRect"
	warp_rect.modulate.a = 0.0
	warp_rect.visible = false
	warp_rect.z_index = 99
	warp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it fullscreen
	warp_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	warp_rect.size = viewport.get_visible_rect().size
	
	# Note: You'll need to assign a shader material with warp effect
	DebugLogger.warning(module_name, "Warp rect created but needs shader material assigned")
	
	# Add to scene
	var ui_root = get_tree().get_first_node_in_group("ui_layer")
	if ui_root:
		ui_root.add_child(warp_rect)
	else:
		get_tree().root.add_child(warp_rect)

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Warp startup phase (%.1fs)" % time)
	
	if not warp_rect:
		DebugLogger.error(module_name, "No warp rect assigned")
		return
	
	# Play start sound (fixed: was playing end sound)
	if warp_start_sound:
		play_effect_audio(warp_start_sound)
	
	# Show and fade in
	warp_rect.visible = true
	
	if time > 0:
		var tween = create_tween()
		tween.tween_property(warp_rect, "modulate:a", 1.0, time)
		
		# Animate shader parameters if available
		var material = warp_rect.material as ShaderMaterial
		if material and material.get_shader_parameter("warp_strength") != null:
			tween.parallel().tween_method(
				func(value): material.set_shader_parameter("warp_strength", value),
				0.0, max_warp_strength, time
			)
		else:
			DebugLogger.warning(module_name, "No warp_strength shader parameter found")
		
		await tween.finished
	else:
		warp_rect.modulate.a = 1.0
		var material = warp_rect.material as ShaderMaterial
		if material:
			material.set_shader_parameter("warp_strength", max_warp_strength)

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Warp duration phase (%.1fs)" % time)
	
	if not warp_rect:
		return
	
	# Optionally animate the warp during duration
	# You could add pulsing or other effects here
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Warp wind down phase (%.1fs)" % time)
	
	if not warp_rect:
		return
	
	# Play end sound
	if warp_end_sound:
		play_effect_audio(warp_end_sound)
	
	# Fade out
	if time > 0:
		var tween = create_tween()
		tween.tween_property(warp_rect, "modulate:a", 0.0, time)
		
		# Animate shader parameters if available
		var material = warp_rect.material as ShaderMaterial
		if material and material.get_shader_parameter("warp_strength") != null:
			var current_strength = material.get_shader_parameter("warp_strength")
			tween.parallel().tween_method(
				func(value): material.set_shader_parameter("warp_strength", value),
				current_strength, 0.0, time
			)
		
		await tween.finished
	else:
		warp_rect.modulate.a = 0.0
	
	# Hide
	warp_rect.visible = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up warp effect")
	
	if warp_rect:
		warp_rect.visible = false
		warp_rect.modulate.a = 0.0
		
		# Reset shader parameters
		var material = warp_rect.material as ShaderMaterial
		if material and material.get_shader_parameter("warp_strength") != null:
			material.set_shader_parameter("warp_strength", 0.0)

func stop_immediately() -> void:
	if warp_rect:
		warp_rect.modulate.a = 0.0
		warp_rect.visible = false
		
		var material = warp_rect.material as ShaderMaterial
		if material:
			material.set_shader_parameter("warp_strength", 0.0)
	
	super.stop_immediately()
