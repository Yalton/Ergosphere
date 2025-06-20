extends BaseVisualEffect
class_name PurpleLightHandler

## Purple light visual effect handler
## Makes everything look lit by purple light

@export_group("Purple Light Settings")
## Audio to play when effect starts
@export var purple_sound: AudioStream
## Whether to use dynamic light movement
@export var dynamic_lights: bool = true
## Number of purple light sources
@export var light_count: int = 2
## Whether to apply audio reactive pulsing
@export var audio_reactive: bool = false

var audio_player: AudioStreamPlayer
var compositor_effect: CompositorEffect
var light_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "purple_light"
	effect_name = "Purple Light"
	compositor_index = 6  # Assuming this is index 6
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	module_name = "PurpleLightHandler"
	DebugLogger.register_module(module_name, true)

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Purple light startup phase")
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for purple light")
		return
	
	# Play sound
	if purple_sound:
		audio_player.stream = purple_sound
		audio_player.play()
	
	# Enable effect
	compositor_effect.enabled = true
	
	# Fade in intensity
	if time > 0:
		var fade_tween = create_tween()
		compositor_effect.set("intensity", 0.0)
		fade_tween.tween_property(compositor_effect, "intensity", 1.0, time)
		await fade_tween.finished

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Purple light duration phase for %f seconds" % time)
	
	if not compositor_effect:
		return
	
	# Start dynamic light animation
	if dynamic_lights and time > 0:
		_animate_lights()
	
	# Audio reactive pulsing
	if audio_reactive and audio_player.playing:
		_start_audio_reactive_pulse()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop animations
	if light_tween and light_tween.is_valid():
		light_tween.kill()
		light_tween = null

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Purple light wind down phase")
	
	if not compositor_effect:
		return
	
	# Fade out intensity
	if time > 0:
		var fade_tween = create_tween()
		fade_tween.tween_property(compositor_effect, "intensity", 0.0, time)
		await fade_tween.finished
	
	# Disable effect
	compositor_effect.enabled = false
	
	# Stop audio if still playing
	if audio_player.playing:
		audio_player.stop()

func _cleanup() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
	if audio_player.playing:
		audio_player.stop()
	if light_tween and light_tween.is_valid():
		light_tween.kill()
		light_tween = null

func _animate_lights() -> void:
	if not compositor_effect:
		return
	
	light_tween = create_tween()
	light_tween.set_loops()
	light_tween.set_parallel(true)
	
	# Animate light falloff for breathing effect
	light_tween.tween_property(compositor_effect, "light_falloff", 3.0, 2.0)
	light_tween.tween_property(compositor_effect, "light_falloff", 1.5, 2.0).set_delay(2.0)
	
	# Animate shadow darkness
	light_tween.tween_property(compositor_effect, "shadow_darkness", 0.7, 1.5)
	light_tween.tween_property(compositor_effect, "shadow_darkness", 0.3, 1.5).set_delay(1.5)

func _start_audio_reactive_pulse() -> void:
	if not compositor_effect:
		return
	
	# Enable pulsing in the effect
	compositor_effect.set("enable_pulse", true)
	compositor_effect.set("pulse_speed", 4.0)  # Faster pulse for audio reactivity
	compositor_effect.set("pulse_amount", 0.5)
