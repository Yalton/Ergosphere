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

var compositor_effect: CompositorEffect
var pulse_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "chromatic_aberration"
	effect_name = "Chromatic Aberration"
	compositor_index = 2  # Chromatic is index 2
	


func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration startup phase")
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for chromatic aberration")
		return
	
	# Play sound using base class wrapper
	if aberration_sound:
		play_effect_audio(aberration_sound)

	# Enable effect
	compositor_effect.enabled = true
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration duration phase for %f seconds" % time)
	
	if not compositor_effect:
		return
	
	# Start pulse if enabled
	if enable_pulse and time > 0:
		_start_pulse()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop pulse
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Chromatic aberration wind down phase")
	
	if not compositor_effect:
		return
	
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func _start_pulse() -> void:
	if not compositor_effect:
		return
	
	var beat_duration = 60.0 / pulse_bpm
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Pulse by toggling visibility to simulate heartbeat
	pulse_tween.tween_callback(func(): compositor_effect.enabled = true)
	pulse_tween.tween_interval(beat_duration * 0.4)
	pulse_tween.tween_callback(func(): compositor_effect.enabled = false)
	pulse_tween.tween_interval(beat_duration * 0.6)
