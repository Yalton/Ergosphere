extends BaseVisualEffect
class_name GlitchEffectHandler

## Glitch visual effect handler
## Uses compositor index 0 for the glitch post-process effect

@export_group("Glitch Settings")
## Audio to play during glitch
@export var glitch_sound: AudioStream
## Intensity multiplier for the effect
@export var intensity: float = 1.0
## Whether to flicker during duration
@export var enable_flicker: bool = true
## Flicker frequency (times per second)
@export var flicker_rate: float = 4.0

var audio_player: AudioStreamPlayer
var compositor_effect: CompositorEffect
var flicker_tween: Tween

func _ready() -> void:
	super._ready()
	effect_id = "glitch"
	effect_name = "Glitch"
	compositor_index = 1  # Glitch is index 0
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Glitch startup phase")
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for glitch")
		return
	
	# Play sound
	if glitch_sound:
		audio_player.stream = glitch_sound
		audio_player.play()
	
	# Enable effect
	compositor_effect.enabled = true
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Glitch duration phase for %f seconds" % time)
	
	if not compositor_effect:
		return
	
	# Start flicker if enabled
	if enable_flicker and time > 0:
		_start_flicker()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop flicker
	if flicker_tween:
		flicker_tween.kill()
		flicker_tween = null

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Glitch wind down phase")
	
	if not compositor_effect:
		return
	
	if time > 0:
		await get_tree().create_timer(time).timeout
	
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
	if flicker_tween:
		flicker_tween.kill()
		flicker_tween = null

func _start_flicker() -> void:
	if not compositor_effect:
		return
	
	var flicker_interval = 1.0 / flicker_rate
	
	flicker_tween = create_tween()
	flicker_tween.set_loops()
	
	# Flicker by toggling enabled state
	flicker_tween.tween_callback(func(): compositor_effect.enabled = false)
	flicker_tween.tween_interval(flicker_interval * 0.3)
	flicker_tween.tween_callback(func(): compositor_effect.enabled = true)
	flicker_tween.tween_interval(flicker_interval * 0.7)
