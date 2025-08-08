# EdgeDetectionHandler.gd
extends BaseVisualEffect
class_name EdgeDetectionHandler

## Edge detection visual effect handler
## Uses compositor index 3 for the edge detection post-process effect

@export_group("Edge Detection Settings")
## Audio to play during effect
@export var edge_sound: AudioStream
## Whether to fade in/out smoothly
@export var smooth_transitions: bool = true
## Edge detection threshold
@export var edge_threshold: float = 0.5
## Edge color
@export var edge_color: Color = Color.WHITE

var compositor_effect: CompositorEffect

func _ready() -> void:
	super._ready()
	effect_id = "edge_detection"
	effect_name = "Edge Detection"
	compositor_index = 3  # Edge detection is index 3
	module_name = "VFX_EdgeDetection"
	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "Edge detection handler ready")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Edge detection startup phase (%.1fs)" % time)
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found at index %d" % compositor_index)
		return
	
	# Play sound using base class wrapper
	if edge_sound:
		play_effect_audio(edge_sound)
	
	# Configure effect parameters if available
	if compositor_effect.has_method("set"):
		compositor_effect.set("threshold", edge_threshold)
		compositor_effect.set("edge_color", edge_color)
	
	# Enable effect with smooth transition if requested
	if smooth_transitions and time > 0:
		# Start with low intensity
		compositor_effect.enabled = true
		if compositor_effect.has_method("set") and compositor_effect.has_method("get"):
			compositor_effect.set("intensity", 0.0)
			var tween = create_tween()
			tween.tween_property(compositor_effect, "intensity", 1.0, time)
			await tween.finished
	else:
		# Instant enable
		compositor_effect.enabled = true
		if time > 0:
			await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Edge detection duration phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Just maintain the effect
	# Could add pulsing or other effects here
	if time > 0:
		await get_tree().create_timer(time).timeout

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Edge detection wind down phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Smooth fade out if requested
	if smooth_transitions and time > 0:
		if compositor_effect.has_method("set") and compositor_effect.has_method("get"):
			var tween = create_tween()
			tween.tween_property(compositor_effect, "intensity", 0.0, time)
			await tween.finished
	else:
		if time > 0:
			await get_tree().create_timer(time).timeout
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up edge detection effect")
	
	if compositor_effect:
		compositor_effect.enabled = false
		# Reset intensity if it was modified
		if compositor_effect.has_method("set"):
			compositor_effect.set("intensity", 1.0)
		compositor_effect = null

func stop_immediately() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
		if compositor_effect.has_method("set"):
			compositor_effect.set("intensity", 1.0)
	
	super.stop_immediately()
