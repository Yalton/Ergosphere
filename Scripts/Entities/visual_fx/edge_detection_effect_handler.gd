extends BaseVisualEffect
class_name EdgeDetectionHandler

## Edge detection visual effect handler
## Uses compositor index 1 for the edge detection post-process effect

@export_group("Edge Detection Settings")
## Audio to play during effect
@export var edge_sound: AudioStream
## Whether to fade in/out smoothly
@export var smooth_transitions: bool = true

var compositor_effect: CompositorEffect

func _ready() -> void:
	super._ready()
	effect_id = "edge_detection"
	effect_name = "Edge Detection"
	compositor_index = 3  # Edge detection is index 1
	


func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Edge detection startup phase")
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for edge detection")
		return
	

	

	# Play sound using base class wrapper
	if edge_sound:
		play_effect_audio(edge_sound)

	# Enable effect
	compositor_effect.enabled = true
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Edge detection duration phase for %f seconds" % time)
	
	if not compositor_effect:
		return
	
	# Just maintain the effect
	if time > 0:
		await get_tree().create_timer(time).timeout

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Edge detection wind down phase")
	
	if not compositor_effect:
		return
	
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Disable effect
	compositor_effect.enabled = false
	

func _cleanup() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
