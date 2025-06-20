extends BaseVisualEffect
class_name GeometricFractalHandler

## Geometric/Fractal visual effect handler
## Transforms the screen into geometric patterns

@export_group("Geometric Settings")
## Audio to play when effect starts
@export var geometric_sound: AudioStream
## Whether to gradually increase fractal depth during effect
@export var animate_depth: bool = true
## Target number of segments to morph to
@export var target_segments: int = 8
## Whether to rotate the pattern
@export var enable_rotation: bool = true

var audio_player: AudioStreamPlayer
var compositor_effect: CompositorEffect
var original_segments: int
var original_depth: int
var morph_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "geometric_fractal"
	effect_name = "Geometric Fractal"
	compositor_index = 5  # Assuming this is index 5
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	module_name = "GeometricFractalHandler"
	DebugLogger.register_module(module_name, true)

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Geometric fractal startup phase")
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for geometric fractal")
		return
	
	# Store original values
	if compositor_effect.has_method("get"):
		original_segments = compositor_effect.get("segments")
		original_depth = compositor_effect.get("fractal_depth")
	
	# Play sound
	if geometric_sound:
		audio_player.stream = geometric_sound
		audio_player.play()
	
	# Enable effect
	compositor_effect.enabled = true
	
	# Start morphing
	if animate_depth and time > 0:
		morph_tween = create_tween()
		morph_tween.set_parallel(true)
		
		# Animate fractal depth from 1 to target
		morph_tween.tween_property(compositor_effect, "fractal_depth", 3, time)
		
		# Animate segments
		morph_tween.tween_property(compositor_effect, "segments", target_segments, time)
		
		# Animate pattern scale
		morph_tween.tween_property(compositor_effect, "pattern_scale", 2.0, time)
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Geometric fractal duration phase for %f seconds" % time)
	
	if not compositor_effect:
		return
	
	# Continuous rotation during duration
	if enable_rotation and time > 0:
		var rotation_tween = create_tween()
		rotation_tween.set_loops()
		
		# Rotate pattern by animating the animation speed
		rotation_tween.tween_property(compositor_effect, "animation_speed", 2.0, 1.0)
		rotation_tween.tween_property(compositor_effect, "animation_speed", 0.5, 1.0)
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Geometric fractal wind down phase")
	
	if not compositor_effect:
		return
	
	# Stop any active tweens
	if morph_tween and morph_tween.is_valid():
		morph_tween.kill()
	
	# Morph back to original
	if time > 0:
		var restore_tween = create_tween()
		restore_tween.set_parallel(true)
		
		restore_tween.tween_property(compositor_effect, "fractal_depth", original_depth, time)
		restore_tween.tween_property(compositor_effect, "segments", original_segments, time)
		restore_tween.tween_property(compositor_effect, "pattern_scale", 1.0, time)
		
		await restore_tween.finished
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
	if morph_tween and morph_tween.is_valid():
		morph_tween.kill()
		morph_tween = null
