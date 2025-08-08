# GeometricFractalHandler.gd
extends BaseVisualEffect
class_name GeometricFractalHandler

## Geometric/Fractal visual effect handler
## Transforms the screen into geometric patterns

@export_group("Geometric Settings")
## Audio to play when effect starts
@export var geometric_sound: AudioStream
## Whether to gradually increase fractal depth during effect
@export var animate_depth: bool = true
## Target fractal depth
@export var target_depth: int = 3
## Target number of segments to morph to
@export var target_segments: int = 8
## Whether to rotate the pattern
@export var enable_rotation: bool = true
## Rotation speed during duration
@export var rotation_speed: float = 1.0

var compositor_effect: CompositorEffect
var original_segments: int = 4
var original_depth: int = 1
var original_scale: float = 1.0
var morph_tween: Tween
var rotation_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "geometric_fractal"
	effect_name = "Geometric Fractal"
	compositor_index = 4  # Assuming this is index 5
	module_name = "VFX_GeometricFractal"
	
	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "Geometric fractal handler ready")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Geometric fractal startup phase (%.1fs)" % time)
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found at index %d" % compositor_index)
		return
	
	# Store original values if available
	if compositor_effect.has_method("get"):
		if compositor_effect.get("segments") != null:
			original_segments = compositor_effect.get("segments")
		if compositor_effect.get("fractal_depth") != null:
			original_depth = compositor_effect.get("fractal_depth")
		if compositor_effect.get("pattern_scale") != null:
			original_scale = compositor_effect.get("pattern_scale")
	
	# Play sound
	if geometric_sound:
		play_effect_audio(geometric_sound)
	
	# Enable effect
	compositor_effect.enabled = true
	
	# Start morphing animation
	if animate_depth and time > 0 and compositor_effect.has_method("set"):
		morph_tween = create_tween()
		morph_tween.set_parallel(true)
		
		# Animate fractal depth from current to target
		if compositor_effect.get("fractal_depth") != null:
			morph_tween.tween_property(compositor_effect, "fractal_depth", target_depth, time)
		
		# Animate segments
		if compositor_effect.get("segments") != null:
			morph_tween.tween_property(compositor_effect, "segments", target_segments, time)
		
		# Animate pattern scale
		if compositor_effect.get("pattern_scale") != null:
			morph_tween.tween_property(compositor_effect, "pattern_scale", 2.0, time)
		
		await morph_tween.finished
	elif time > 0:
		# If can't animate, just set values instantly
		if compositor_effect.has_method("set"):
			compositor_effect.set("fractal_depth", target_depth)
			compositor_effect.set("segments", target_segments)
			compositor_effect.set("pattern_scale", 2.0)
		await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Geometric fractal duration phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Continuous rotation during duration
	if enable_rotation and time > 0 and compositor_effect.has_method("set"):
		rotation_tween = create_tween()
		rotation_tween.set_loops()
		
		# Rotate pattern by animating rotation or animation speed
		if compositor_effect.get("rotation") != null:
			# Direct rotation animation
			rotation_tween.tween_property(compositor_effect, "rotation", TAU, 2.0 / rotation_speed)
			rotation_tween.tween_callback(func(): 
				if compositor_effect:
					compositor_effect.set("rotation", 0.0)
			)
		elif compositor_effect.get("animation_speed") != null:
			# Animate via animation speed parameter
			rotation_tween.tween_property(compositor_effect, "animation_speed", 2.0 * rotation_speed, 1.0)
			rotation_tween.tween_property(compositor_effect, "animation_speed", 0.5 * rotation_speed, 1.0)
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop rotation
	if rotation_tween and rotation_tween.is_valid():
		rotation_tween.kill()
		rotation_tween = null

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Geometric fractal wind down phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Stop any active tweens
	if morph_tween and morph_tween.is_valid():
		morph_tween.kill()
	if rotation_tween and rotation_tween.is_valid():
		rotation_tween.kill()
	
	# Morph back to original values
	if time > 0 and compositor_effect.has_method("set"):
		var restore_tween = create_tween()
		restore_tween.set_parallel(true)
		
		if compositor_effect.get("fractal_depth") != null:
			restore_tween.tween_property(compositor_effect, "fractal_depth", original_depth, time)
		if compositor_effect.get("segments") != null:
			restore_tween.tween_property(compositor_effect, "segments", original_segments, time)
		if compositor_effect.get("pattern_scale") != null:
			restore_tween.tween_property(compositor_effect, "pattern_scale", original_scale, time)
		
		await restore_tween.finished
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up geometric fractal effect")
	
	if compositor_effect:
		compositor_effect.enabled = false
		# Restore original values
		if compositor_effect.has_method("set"):
			compositor_effect.set("fractal_depth", original_depth)
			compositor_effect.set("segments", original_segments)
			compositor_effect.set("pattern_scale", original_scale)
		compositor_effect = null
	
	if morph_tween and morph_tween.is_valid():
		morph_tween.kill()
		morph_tween = null
	
	if rotation_tween and rotation_tween.is_valid():
		rotation_tween.kill()
		rotation_tween = null

func stop_immediately() -> void:
	if morph_tween and morph_tween.is_valid():
		morph_tween.kill()
	if rotation_tween and rotation_tween.is_valid():
		rotation_tween.kill()
	
	if compositor_effect:
		compositor_effect.enabled = false
		if compositor_effect.has_method("set"):
			compositor_effect.set("fractal_depth", original_depth)
			compositor_effect.set("segments", original_segments)
			compositor_effect.set("pattern_scale", original_scale)
	
	super.stop_immediately()
