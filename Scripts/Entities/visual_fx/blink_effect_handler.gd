extends BaseVisualEffect
class_name BlinkEffectHandler

## Blink effect handler - fades to black and back
## Uses a ColorRect overlay instead of compositor

@export_group("Blink Settings")
## Reference to the blink ColorRect
@export var blink_rect: ColorRect
## Sound to play during blink
@export var blink_sound: AudioStream
## Color to blink to
@export var blink_color: Color = Color.BLACK

func _ready() -> void:
	super._ready()
	effect_id = "blink"
	effect_name = "Blink"
	compositor_index = -1  # No compositor effect
	
	
	# Ensure blink rect is hidden
	if blink_rect:
		blink_rect.visible = false
		blink_rect.color = blink_color
		blink_rect.modulate.a = 0.0

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Blink startup phase")
	
	if not blink_rect:
		DebugLogger.error(module_name, "No blink rect assigned")
		return

	
		# Play sound using base class wrapper
	if blink_sound:
		play_effect_audio(blink_sound)

	# Show and fade in
	blink_rect.visible = true
	
	if time > 0:
		var tween = create_tween()
		tween.tween_property(blink_rect, "modulate:a", 1.0, time)
		await tween.finished
	else:
		blink_rect.modulate.a = 1.0

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Blink duration phase for %f seconds" % time)
	
	# Just hold the blink
	if time > 0:
		await get_tree().create_timer(time).timeout

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Blink wind down phase")
	
	if not blink_rect:
		return
	
	# Fade out
	if time > 0:
		var tween = create_tween()
		tween.tween_property(blink_rect, "modulate:a", 0.0, time)
		await tween.finished
	else:
		blink_rect.modulate.a = 0.0
	
	# Hide
	blink_rect.visible = false

func _cleanup() -> void:
	if blink_rect:
		blink_rect.visible = false
		blink_rect.modulate.a = 0.0
