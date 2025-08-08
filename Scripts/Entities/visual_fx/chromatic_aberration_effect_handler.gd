# ChromaticAberrationHandler.gd
extends BaseVisualEffect
class_name ChromaticAberrationHandler

## Chromatic aberration visual effect handler
## Uses compositor index 2 for the chromatic aberration post-process effect

@export_group("Chromatic Settings")
## Audio to play when effect starts
@export var aberration_sound: AudioStream
## Whether to pulse during duration (like heartbeat)
@export var enable_pulse: bool = false
## Pulse rate in BPM
@export var pulse_bpm: float = 80.0
## Intensity of the aberration effect
@export var aberration_intensity: float = 1.0

var compositor_effect: CompositorEffect
var pulse_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "chromatic_aberration"
	effect_name = "Chromatic Aberration"
	compositor_index = 2  # Chromatic is index 2
	module_name = "VFX_ChromaticAberration"
	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "Chromatic aberration handler ready")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration startup phase (%.1fs)" % time)
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found at index %d" % compositor_index)
		return
	
	# Play sound using base class wrapper
	if aberration_sound:
		play_effect_audio(aberration_sound)
	
	# Enable effect
	compositor_effect.enabled = true
	
	# Optionally animate intensity during startup
	if time > 0:
		# If the compositor has an intensity parameter, animate it
		# This depends on your specific compositor implementation
		await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration duration phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Start pulse if enabled
	if enable_pulse and time > 0:
		start_pulse()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop pulse
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration wind down phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Stop any active pulse
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
	
	# Optionally fade out the effect
	if time > 0:
		# Could animate intensity down if your compositor supports it
		await get_tree().create_timer(time).timeout
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up chromatic aberration effect")
	
	if compositor_effect:
		compositor_effect.enabled = false
		compositor_effect = null
	
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func start_pulse() -> void:
	if not compositor_effect:
		return
	
	var beat_duration = 60.0 / pulse_bpm
	
	DebugLogger.debug(module_name, "Starting pulse at %f BPM" % pulse_bpm)
	
	# Create looping tween for pulse effect
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Pulse by modulating the effect intensity or visibility
	# This creates a heartbeat-like effect
	pulse_tween.tween_callback(func(): 
		if compositor_effect:
			compositor_effect.enabled = true
	)
	pulse_tween.tween_interval(beat_duration * 0.3)  # Effect on for 30% of beat
	pulse_tween.tween_callback(func(): 
		if compositor_effect:
			compositor_effect.enabled = false
	)
	pulse_tween.tween_interval(beat_duration * 0.1)  # Brief pause
	pulse_tween.tween_callback(func(): 
		if compositor_effect:
			compositor_effect.enabled = true
	)
	pulse_tween.tween_interval(beat_duration * 0.2)  # Second pulse
	pulse_tween.tween_callback(func(): 
		if compositor_effect:
			compositor_effect.enabled = false
	)
	pulse_tween.tween_interval(beat_duration * 0.4)  # Rest of beat

func stop_immediately() -> void:
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null
	
	if compositor_effect:
		compositor_effect.enabled = false
	
	super.stop_immediately()
