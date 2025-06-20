extends BaseVisualEffect
class_name HallucinationTextHandler

## Hallucination text visual effect handler
## Displays warped text/numbers overlaying the screen

@export_group("Hallucination Settings")
## Audio to play when effect starts (whispers, static, etc)
@export var hallucination_sound: AudioStream
## Whether text should gradually appear
@export var fade_in_text: bool = true
## Text messages to cycle through (if empty, uses procedural text)
@export var text_messages: Array[String] = ["YOU ARE BEING WATCHED", "THEY KNOW", "WAKE UP", "IT'S NOT REAL", "ERROR ERROR ERROR"]
## Whether to cycle through messages
@export var cycle_messages: bool = true
## Message cycle duration
@export var message_duration: float = 2.0

var audio_player: AudioStreamPlayer
var compositor_effect: CompositorEffect
var text_tween: Tween
var message_timer: Timer
var current_message_index: int = 0

func _ready() -> void:
	super._ready()
	effect_id = "hallucination_text"
	effect_name = "Hallucination Text"
	compositor_index = 7  # Assuming this is index 7
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	# Create message timer
	message_timer = Timer.new()
	message_timer.one_shot = false
	message_timer.timeout.connect(_on_message_timeout)
	add_child(message_timer)
	
	module_name = "HallucinationTextHandler"
	DebugLogger.register_module(module_name, true)

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Hallucination text startup phase")
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found for hallucination text")
		return
	
	# Play sound
	if hallucination_sound:
		audio_player.stream = hallucination_sound
		audio_player.play()
	
	# Enable effect
	compositor_effect.enabled = true
	
	# Fade in text
	if fade_in_text and time > 0:
		text_tween = create_tween()
		compositor_effect.set("text_opacity", 0.0)
		text_tween.tween_property(compositor_effect, "text_opacity", 0.7, time)
		
		# Also fade in distortion
		compositor_effect.set("distortion_amount", 0.0)
		text_tween.parallel().tween_property(compositor_effect, "distortion_amount", 0.3, time)
		
		await text_tween.finished
	else:
		compositor_effect.set("text_opacity", 0.7)
		compositor_effect.set("distortion_amount", 0.3)

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Hallucination text duration phase for %f seconds" % time)
	
	if not compositor_effect:
		return
	
	# Start message cycling if enabled
	if cycle_messages and text_messages.size() > 0:
		message_timer.wait_time = message_duration
		message_timer.start()
		_update_message()
	
	# Create subtle animation variations
	if time > 0:
		_animate_text_properties()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop message cycling
	message_timer.stop()

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Hallucination text wind down phase")
	
	if not compositor_effect:
		return
	
	# Stop any active tweens
	if text_tween and text_tween.is_valid():
		text_tween.kill()
	
	# Fade out text and increase distortion
	if time > 0:
		var fade_tween = create_tween()
		fade_tween.set_parallel(true)
		
		fade_tween.tween_property(compositor_effect, "text_opacity", 0.0, time)
		fade_tween.tween_property(compositor_effect, "distortion_amount", 1.0, time * 0.5)
		fade_tween.tween_property(compositor_effect, "flicker_intensity", 1.0, time * 0.5)
		
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
	if text_tween and text_tween.is_valid():
		text_tween.kill()
		text_tween = null
	message_timer.stop()

func _animate_text_properties() -> void:
	if not compositor_effect:
		return
	
	var anim_tween = create_tween()
	anim_tween.set_loops()
	
	# Subtle wave amplitude changes
	anim_tween.tween_property(compositor_effect, "wave_amplitude", 0.15, 2.0)
	anim_tween.tween_property(compositor_effect, "wave_amplitude", 0.05, 2.0)
	
	# Flicker intensity variation
	anim_tween.parallel().tween_property(compositor_effect, "flicker_intensity", 0.5, 1.5)
	anim_tween.tween_property(compositor_effect, "flicker_intensity", 0.1, 1.5)

func _update_message() -> void:
	if text_messages.size() == 0:
		return
	
	# You would need to implement a way to pass the current message to the shader
	# This could be done through a uniform or by modifying the shader to read from a texture
	current_message_index = (current_message_index + 1) % text_messages.size()
	
	DebugLogger.debug(module_name, "Switching to message: %s" % text_messages[current_message_index])

func _on_message_timeout() -> void:
	_update_message()
