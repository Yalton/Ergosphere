# ShapeDilationHandler.gd
extends BaseVisualEffect
class_name ShapeDilationHandler

## Shape dilation/black hole distortion effect handler
## Controls the compositor effect at index 7

@export_group("Shape Dilation Settings")
## Audio to play when effect starts (reality tearing sound)
@export var dilation_sound: AudioStream
## Audio for continuous warping (optional ambient sound)
@export var ambient_warp_sound: AudioStream
## Volume for ambient sound
@export var ambient_volume: float = 0.0

var compositor_effect: CompositorEffect
var ambient_audio_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	effect_id = "shape_dilation"
	effect_name = "Shape Dilation"
	compositor_index = 7  # Shape dilation is at index 7
	module_name = "VFX_ShapeDilation"
	
	# Create ambient audio player
	ambient_audio_player = AudioStreamPlayer.new()
	ambient_audio_player.name = "AmbientWarpAudio"
	ambient_audio_player.bus = "SFX"
	add_child(ambient_audio_player)
	
	DebugLogger.debug(module_name, "Shape dilation handler ready")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Shape dilation startup phase (%.1fs)" % time)
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found at index %d" % compositor_index)
		return
	
	# Play startup sound (reality tearing)
	if dilation_sound:
		play_effect_audio(dilation_sound)
	
	# Start ambient warp sound if provided
	if ambient_warp_sound and ambient_audio_player:
		ambient_audio_player.stream = ambient_warp_sound
		ambient_audio_player.volume_db = -80.0
		ambient_audio_player.play()
		
		# Fade in ambient sound
		var tween = create_tween()
		tween.tween_property(ambient_audio_player, "volume_db", ambient_volume, time if time > 0 else 0.5)
	
	# Enable the compositor effect
	compositor_effect.enabled = true
	
	if time > 0:
		await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Shape dilation duration phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# The effect continues running
	# Could play periodic warp sounds for atmosphere
	if time > 2.0 and dilation_sound:
		var warp_interval = 2.0
		var warps_to_play = int(time / warp_interval)
		
		for i in warps_to_play:
			await get_tree().create_timer(warp_interval).timeout
			# Play a subtle warp sound at random pitch
			play_effect_audio(dilation_sound, randf_range(0.8, 1.2), randf_range(-10, -5))
	else:
		if time > 0:
			await get_tree().create_timer(time).timeout

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Shape dilation wind down phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Fade out ambient sound
	if ambient_audio_player.playing:
		var tween = create_tween()
		tween.tween_property(ambient_audio_player, "volume_db", -80.0, time if time > 0 else 0.5)
		tween.tween_callback(ambient_audio_player.stop)
	
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Disable the compositor effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up shape dilation effect")
	
	if compositor_effect:
		compositor_effect.enabled = false
		compositor_effect = null
	
	if ambient_audio_player.playing:
		ambient_audio_player.stop()

func stop_immediately() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
	
	if ambient_audio_player.playing:
		ambient_audio_player.stop()
	
	super.stop_immediately()
