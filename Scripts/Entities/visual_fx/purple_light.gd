# PurpleLightHandler.gd
extends BaseVisualEffect
class_name PurpleLightHandler

## Purple light visual effect handler
## Makes everything look lit by purple light

@export_group("Purple Light Settings")
## Audio to play when effect starts
@export var purple_sound: AudioStream
## Whether to use dynamic light movement
@export var dynamic_lights: bool = true
## Number of purple light sources (for visual reference)
@export var light_count: int = 2
## Whether to apply audio reactive pulsing
@export var audio_reactive: bool = false
## Purple color tint
@export var purple_tint: Color = Color(0.7, 0.2, 1.0, 1.0)
## Light intensity
@export var light_intensity: float = 1.0

var compositor_effect: CompositorEffect
var light_tween: Tween
var pulse_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "purple_light"
	effect_name = "Purple Light"
	compositor_index = 5  # Assuming this is index 6
	module_name = "VFX_PurpleLight"

	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "Purple light handler ready")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Purple light startup phase (%.1fs)" % time)
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found at index %d" % compositor_index)
		return
	
	# Play sound
	if purple_sound:
		play_effect_audio(purple_sound)
	
	# Configure effect colors and settings
	if compositor_effect.has_method("set"):
		compositor_effect.set("light_color", purple_tint)
		compositor_effect.set("light_count", light_count)
	
	# Enable effect
	compositor_effect.enabled = true
	
	# Fade in intensity
	if time > 0 and compositor_effect.has_method("set"):
		compositor_effect.set("intensity", 0.0)
		var fade_tween = create_tween()
		fade_tween.tween_property(compositor_effect, "intensity", light_intensity, time)
		await fade_tween.finished
	else:
		if compositor_effect.has_method("set"):
			compositor_effect.set("intensity", light_intensity)
		if time > 0:
			await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Purple light duration phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Start dynamic light animation
	if dynamic_lights and time > 0:
		animate_lights()
	
	# Start audio reactive pulse if enabled
	if audio_reactive and time > 0:
		start_audio_reactive_pulse()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop animations
	if light_tween and light_tween.is_valid():
		light_tween.kill()
		light_tween = null
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		pulse_tween = null

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Purple light wind down phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Stop any active animations
	if light_tween and light_tween.is_valid():
		light_tween.kill()
		light_tween = null
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		pulse_tween = null
	
	# Fade out intensity
	if time > 0 and compositor_effect.has_method("set"):
		var fade_tween = create_tween()
		fade_tween.tween_property(compositor_effect, "intensity", 0.0, time)
		await fade_tween.finished
	else:
		if time > 0:
			await get_tree().create_timer(time).timeout
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up purple light effect")
	
	if compositor_effect:
		compositor_effect.enabled = false
		if compositor_effect.has_method("set"):
			compositor_effect.set("intensity", light_intensity)
		compositor_effect = null
	
	if light_tween and light_tween.is_valid():
		light_tween.kill()
		light_tween = null
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		pulse_tween = null

func animate_lights() -> void:
	if not compositor_effect:
		return
	
	DebugLogger.debug(module_name, "Starting dynamic light animation")
	
	light_tween = create_tween()
	light_tween.set_loops()
	
	# Check what parameters the compositor effect supports
	if compositor_effect.has_method("get"):
		# Animate light falloff for breathing effect
		if compositor_effect.get("light_falloff") != null:
			light_tween.tween_property(compositor_effect, "light_falloff", 3.0, 2.0)
			light_tween.tween_property(compositor_effect, "light_falloff", 1.5, 2.0)
		
		# Animate shadow darkness
		if compositor_effect.get("shadow_darkness") != null:
			light_tween.set_parallel(true)
			light_tween.tween_property(compositor_effect, "shadow_darkness", 0.7, 1.5)
			light_tween.tween_property(compositor_effect, "shadow_darkness", 0.3, 1.5).set_delay(1.5)
		
		# Could also animate light positions if supported
		if compositor_effect.get("light_position") != null:
			# Example: move lights in a circle
			pass

func start_audio_reactive_pulse() -> void:
	if not compositor_effect:
		return
	
	DebugLogger.debug(module_name, "Starting audio reactive pulse")
	
	# Check if the compositor supports these parameters
	if compositor_effect.has_method("set"):
		# Try to enable built-in pulsing if available
		if compositor_effect.has_method("get") and compositor_effect.get("enable_pulse") != null:
			compositor_effect.set("enable_pulse", true)
			compositor_effect.set("pulse_speed", 4.0)
			compositor_effect.set("pulse_amount", 0.5)
		else:
			# Manual pulse animation
			pulse_tween = create_tween()
			pulse_tween.set_loops()
			
			# Pulse the intensity
			var base_intensity = light_intensity
			var pulse_intensity = light_intensity * 1.5
			
			pulse_tween.tween_property(compositor_effect, "intensity", pulse_intensity, 0.15)
			pulse_tween.tween_property(compositor_effect, "intensity", base_intensity, 0.35)
			pulse_tween.tween_interval(0.1)  # Brief pause between pulses

func stop_immediately() -> void:
	if light_tween and light_tween.is_valid():
		light_tween.kill()
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
	
	if compositor_effect:
		compositor_effect.enabled = false
		if compositor_effect.has_method("set"):
			compositor_effect.set("intensity", light_intensity)
	
	super.stop_immediately()
