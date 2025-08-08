# HallucinationTextHandler.gd
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
## Maximum text opacity
@export var max_text_opacity: float = 0.7
## Base distortion amount
@export var base_distortion: float = 0.3
## Wave amplitude for text warping
@export var wave_amplitude: float = 0.1
## Flicker intensity
@export var flicker_intensity: float = 0.2

var compositor_effect: CompositorEffect
var text_tween: Tween
var anim_tween: Tween
var message_timer: Timer
var current_message_index: int = 0

func _ready() -> void:
	super._ready()
	effect_id = "hallucination_text"
	effect_name = "Hallucination Text"
	compositor_index = 6  
	module_name = "VFX_HallucinationText"
	
	# Create message timer
	message_timer = Timer.new()
	message_timer.name = "MessageTimer"
	message_timer.one_shot = false
	message_timer.timeout.connect(_on_message_timeout)
	add_child(message_timer)
	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "Hallucination text handler ready")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Hallucination text startup phase (%.1fs)" % time)
	
	# Get compositor effect
	compositor_effect = get_compositor_effect()
	if not compositor_effect:
		DebugLogger.error(module_name, "No compositor effect found at index %d" % compositor_index)
		return
	
	# Play sound
	if hallucination_sound:
		play_effect_audio(hallucination_sound)
	
	# Set initial message if available
	if text_messages.size() > 0 and compositor_effect.has_method("set"):
		current_message_index = 0
		_update_message()
	
	# Enable effect
	compositor_effect.enabled = true
	
	# Configure initial parameters
	if compositor_effect.has_method("set"):
		compositor_effect.set("wave_amplitude", wave_amplitude)
		compositor_effect.set("flicker_intensity", flicker_intensity)
	
	# Fade in text
	if fade_in_text and time > 0 and compositor_effect.has_method("set"):
		text_tween = create_tween()
		compositor_effect.set("text_opacity", 0.0)
		compositor_effect.set("distortion_amount", 0.0)
		
		text_tween.set_parallel(true)
		text_tween.tween_property(compositor_effect, "text_opacity", max_text_opacity, time)
		text_tween.tween_property(compositor_effect, "distortion_amount", base_distortion, time)
		
		await text_tween.finished
	else:
		if compositor_effect.has_method("set"):
			compositor_effect.set("text_opacity", max_text_opacity)
			compositor_effect.set("distortion_amount", base_distortion)
		if time > 0:
			await get_tree().create_timer(time).timeout

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Hallucination text duration phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Start message cycling if enabled
	if cycle_messages and text_messages.size() > 1:
		message_timer.wait_time = message_duration
		message_timer.start()
		DebugLogger.debug(module_name, "Started message cycling with %d messages" % text_messages.size())
	
	# Create subtle animation variations
	if time > 0:
		_animate_text_properties()
	
	# Wait for duration
	if time > 0:
		await get_tree().create_timer(time).timeout
	
	# Stop message cycling
	message_timer.stop()
	
	# Stop animation tween
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
		anim_tween = null

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Hallucination text wind down phase (%.1fs)" % time)
	
	if not compositor_effect:
		return
	
	# Stop any active tweens
	if text_tween and text_tween.is_valid():
		text_tween.kill()
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
	
	# Stop message timer
	message_timer.stop()
	
	# Fade out text and increase distortion for creepy effect
	if time > 0 and compositor_effect.has_method("set"):
		var fade_tween = create_tween()
		fade_tween.set_parallel(true)
		
		# Fade out opacity
		fade_tween.tween_property(compositor_effect, "text_opacity", 0.0, time)
		
		# Increase distortion for a warped fade out
		fade_tween.tween_property(compositor_effect, "distortion_amount", 1.0, time * 0.5)
		
		# Increase flicker for glitchy fade
		fade_tween.tween_property(compositor_effect, "flicker_intensity", 1.0, time * 0.5)
		
		await fade_tween.finished
	else:
		if time > 0:
			await get_tree().create_timer(time).timeout
	
	# Disable effect
	compositor_effect.enabled = false

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up hallucination text effect")
	
	if compositor_effect:
		compositor_effect.enabled = false
		# Reset parameters
		if compositor_effect.has_method("set"):
			compositor_effect.set("text_opacity", max_text_opacity)
			compositor_effect.set("distortion_amount", base_distortion)
			compositor_effect.set("flicker_intensity", flicker_intensity)
			compositor_effect.set("wave_amplitude", wave_amplitude)
		compositor_effect = null
	
	if text_tween and text_tween.is_valid():
		text_tween.kill()
		text_tween = null
	
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
		anim_tween = null
	
	message_timer.stop()
	current_message_index = 0

func _animate_text_properties() -> void:
	if not compositor_effect:
		return
	
	if not compositor_effect.has_method("set"):
		return
	
	DebugLogger.debug(module_name, "Starting text property animations")
	
	anim_tween = create_tween()
	anim_tween.set_loops()
	
	# Check what properties are available and animate them
	if compositor_effect.has_method("get"):
		# Subtle wave amplitude changes for warping effect
		if compositor_effect.get("wave_amplitude") != null:
			anim_tween.tween_property(compositor_effect, "wave_amplitude", wave_amplitude * 1.5, 2.0)
			anim_tween.tween_property(compositor_effect, "wave_amplitude", wave_amplitude * 0.5, 2.0)
		
		# Flicker intensity variation for unstable appearance
		if compositor_effect.get("flicker_intensity") != null:
			anim_tween.set_parallel(true)
			anim_tween.tween_property(compositor_effect, "flicker_intensity", flicker_intensity * 2.5, 1.5)
			anim_tween.tween_property(compositor_effect, "flicker_intensity", flicker_intensity * 0.5, 1.5)
		
		# Could also animate text scale or rotation if supported
		if compositor_effect.get("text_scale") != null:
			anim_tween.tween_property(compositor_effect, "text_scale", 1.1, 3.0)
			anim_tween.tween_property(compositor_effect, "text_scale", 0.9, 3.0)

func _update_message() -> void:
	if text_messages.size() == 0 or not compositor_effect:
		return
	
	var message = text_messages[current_message_index]
	
	# Update the message in the compositor effect
	# The exact implementation depends on how your shader accepts text
	if compositor_effect.has_method("set"):
		# If the compositor has a text parameter
		if compositor_effect.has_method("get") and compositor_effect.get("display_text") != null:
			compositor_effect.set("display_text", message)
		
		# Alternative: might use a text_index parameter
		elif compositor_effect.has_method("get") and compositor_effect.get("text_index") != null:
			compositor_effect.set("text_index", current_message_index)
	
	DebugLogger.debug(module_name, "Displaying message [%d]: %s" % [current_message_index, message])
	
	# Advance to next message for next cycle
	current_message_index = (current_message_index + 1) % text_messages.size()

func _on_message_timeout() -> void:
	_update_message()
	
	# Optional: Add a brief flicker when changing messages
	if compositor_effect and compositor_effect.has_method("set"):
		var original_opacity = max_text_opacity
		compositor_effect.set("text_opacity", 0.0)
		await get_tree().create_timer(0.1).timeout
		compositor_effect.set("text_opacity", original_opacity)

func stop_immediately() -> void:
	message_timer.stop()
	
	if text_tween and text_tween.is_valid():
		text_tween.kill()
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()
	
	if compositor_effect:
		compositor_effect.enabled = false
	
	super.stop_immediately()
