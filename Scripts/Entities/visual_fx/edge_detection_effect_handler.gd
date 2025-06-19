extends BaseVisualEffect
class_name EdgeDetectionHandler

## Edge detection visual effect handler
## Uses compositor index 1 for the edge detection post-process effect

@export_group("Edge Detection Settings")
## Audio to play during effect
@export var edge_sound: AudioStream
## Whether to fade in/out smoothly
@export var smooth_transitions: bool = true

var audio_player: AudioStreamPlayer
var compositor_effect: CompositorEffect

func _ready() -> void:
	super._ready()
	effect_id = "edge_detection"
	effect_name = "Edge Detection"
	compositor_index = 1  # Edge detection is index 1
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Edge detection startup phase")
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for edge detection")
		return
	
	# Play sound
	if edge_sound:
		audio_player.stream = edge_sound
		audio_player.play()
	
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
	
	# Stop audio
	if audio_player.playing:
		audio_player.stop()

func _cleanup() -> void:
	if compositor_effect:
		compositor_effect.enabled = false
	if audio_player.playing:
		audio_player.stop()
