# GlitchEffectHandler.gd
extends BaseVisualEffect
class_name GlitchEffectHandler

## Glitch visual effect handler
## Uses compositor index 1 for the glitch post-process effect

@export_group("Glitch Settings")
## Audio to play during glitch
@export var glitch_sound: AudioStream
## Intensity multiplier for the effect
@export var intensity: float = 1.0
## Whether to flicker during duration
@export var enable_flicker: bool = true
## Flicker frequency (times per second)
@export var flicker_rate: float = 4.0

var compositor_effect: CompositorEffect
var flicker_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "glitch"
	effect_name = "Glitch"
	compositor_index = 1  # Set your compositor index here
	module_name = "VFX_Glitch"
	
	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "Glitch effect handler ready")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Glitch startup phase (%.1fs)" % time)
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for glitch at index %d" % compositor_index)
		return
	
	# Play sound
	if glitch_sound:
		play_effect_audio(glitch_sound)
	
	# Enable effect
	compositor_effect.enabled = true
	
	# Wait for startup time
	if time > 0:
		await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Glitch duration phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Start flicker if enabled
	if enable_flicker and time > 0:
		start_flicker()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop flicker
	if flicker_tween:
		flicker_tween.kill()
		flicker_tween = null

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Glitch wind down phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Could do a fade out here if your compositor supports it
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up glitch effect")
	
	if compositor_effect:
		compositor_effect.enabled = false
		compositor_effect = null
	
	if flicker_tween:
		flicker_tween.kill()
		flicker_tween = null

func start_flicker() -> void:
	if not compositor_effect:
		return
	
	var flicker_interval = 1.0 / flicker_rate
	
	DebugLogger.debug(module_name, "Starting flicker at %f Hz" % flicker_rate)
	
	# Create looping tween for flicker
	flicker_tween = create_tween()
	flicker_tween.set_loops()
	
	# Flicker by toggling enabled state
	flicker_tween.tween_callback(func(): 
		if compositor_effect:
			compositor_effect.enabled = false
	)
	flicker_tween.tween_interval(flicker_interval * 0.3)
	flicker_tween.tween_callback(func(): 
		if compositor_effect:
			compositor_effect.enabled = true
	)
	flicker_tween.tween_interval(flicker_interval * 0.7)
