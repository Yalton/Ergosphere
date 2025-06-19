extends BaseVisualEffect
class_name WarpEffectHandler

## Warp visual effect handler
## Uses a ColorRect with warp shader instead of compositor

@export_group("Warp Settings")
## Reference to the warp ColorRect
@export var warp_rect: ColorRect
## Sound to play when warp starts
@export var warp_start_sound: AudioStream
## Sound to play when warp ends
@export var warp_end_sound: AudioStream

var audio_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	effect_id = "warp"
	effect_name = "Warp"
	compositor_index = -1  # No compositor effect, uses ColorRect
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	# Ensure warp rect is hidden
	if warp_rect:
		warp_rect.visible = false
		warp_rect.modulate.a = 0.0

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Warp startup phase")
	
	if not warp_rect:
		DebugLogger.error(module_name, "No warp rect assigned")
		return
	
	# Play start sound
	if warp_start_sound:
		audio_player.stream = warp_start_sound
		audio_player.play()
	
	# Show and fade in
	warp_rect.visible = true
	
	if time > 0:
		var tween = create_tween()
		tween.tween_property(warp_rect, "modulate:a", 1.0, time)
		
		# Animate shader parameters if available
		var material = warp_rect.material as ShaderMaterial
		if material and material.get_shader_parameter("warp_strength") != null:
			tween.parallel().tween_method(
				func(value): material.set_shader_parameter("warp_strength", value),
				0.0, 0.7, time
			)
		
		await tween.finished
	else:
		warp_rect.modulate.a = 1.0

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Warp duration phase for %f seconds" % time)
	
	# Maintain the warp effect
	if time > 0:
		await get_tree().create_timer(time).timeout

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Warp wind down phase")
	
	if not warp_rect:
		return
	
	# Play end sound
	if warp_end_sound:
		audio_player.stream = warp_end_sound
		audio_player.play()
	
	# Fade out
	if time > 0:
		var tween = create_tween()
		tween.tween_property(warp_rect, "modulate:a", 0.0, time)
		
		# Animate shader parameters if available
		var material = warp_rect.material as ShaderMaterial
		if material and material.get_shader_parameter("warp_strength") != null:
			var current_strength = material.get_shader_parameter("warp_strength")
			tween.parallel().tween_method(
				func(value): material.set_shader_parameter("warp_strength", value),
				current_strength, 0.0, time
			)
		
		await tween.finished
	else:
		warp_rect.modulate.a = 0.0
	
	# Hide
	warp_rect.visible = false

func _cleanup() -> void:
	if warp_rect:
		warp_rect.visible = false
		warp_rect.modulate.a = 0.0
	if audio_player.playing:
		audio_player.stop()
