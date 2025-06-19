extends BaseVisualEffect
class_name MindBreakHandler

## Mind break combo effect - activates all effects except blink
## This is a special effect that manages multiple sub-effects

@export_group("Mind Break Settings")
## Sound to play during mind break
@export var mind_break_sound: AudioStream
## Whether to stagger effect activation
@export var stagger_effects: bool = true
## Delay between each effect activation
@export var stagger_delay: float = 0.2

var audio_player: AudioStreamPlayer
var active_sub_effects: Array[String] = []

func _ready() -> void:
	super._ready()
	effect_id = "mind_break"
	effect_name = "Mind Break"
	compositor_index = -1  # This manages multiple effects
	use_blink_transition = false  # We handle our own transitions
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

func _startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Mind break startup phase")
	
	# Play sound
	if mind_break_sound:
		audio_player.stream = mind_break_sound
		audio_player.play()
	
	var vfx_manager = get_parent()
	if not vfx_manager:
		DebugLogger.error(module_name, "No VFX manager parent")
		return
	
	# List of effects to activate (all except blink and mind_break itself)
	var effects_to_activate = ["glitch", "edge_detection", "chromatic_aberration", "warp"]
	
	# Activate each effect with staggering
	for effect_id in effects_to_activate:
		if vfx_manager.has_method("invoke_effect"):
			# Each sub-effect gets a portion of the total time
			var sub_startup = time / effects_to_activate.size()
			vfx_manager.invoke_effect(effect_id, sub_startup, 0, 0)  # We'll handle duration and wind down
			active_sub_effects.append(effect_id)
			
			if stagger_effects and stagger_delay > 0:
				await get_tree().create_timer(stagger_delay).timeout
	
	# Wait for remaining startup time
	var total_stagger_time = stagger_delay * (effects_to_activate.size() - 1)
	var remaining_time = max(0, time - total_stagger_time)
	if remaining_time > 0:
		await get_tree().create_timer(remaining_time).timeout

func _duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Mind break duration phase for %f seconds" % time)
	
	# All effects run simultaneously during this phase
	if time > 0:
		await get_tree().create_timer(time).timeout

func _wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Mind break wind down phase")
	
	var vfx_manager = get_parent()
	if not vfx_manager:
		return
	
	# Stop all sub-effects with staggering
	for effect_id in active_sub_effects:
		if vfx_manager.has_method("stop_effect"):
			vfx_manager.stop_effect(effect_id)
			
			if stagger_effects and stagger_delay > 0:
				await get_tree().create_timer(stagger_delay).timeout
	
	# Clear the list
	active_sub_effects.clear()
	
	# Stop audio
	if audio_player.playing:
		audio_player.stop()
	
	# Wait for any remaining wind down time
	var total_stagger_time = stagger_delay * active_sub_effects.size()
	var remaining_time = max(0, time - total_stagger_time)
	if remaining_time > 0:
		await get_tree().create_timer(remaining_time).timeout

func _cleanup() -> void:
	# Stop all active sub-effects immediately
	var vfx_manager = get_parent()
	if vfx_manager:
		for effect_id in active_sub_effects:
			if vfx_manager.has_method("stop_effect"):
				vfx_manager.stop_effect(effect_id)
	
	active_sub_effects.clear()
	
	if audio_player.playing:
		audio_player.stop()
