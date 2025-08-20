# MindBreakHandler.gd
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
## List of effects to activate (customize in inspector)
@export var effects_to_activate: Array[String] = ["glitch", "edge_detection", "chromatic_aberration", "warp"]

var active_sub_effects: Array[String] = []
var vfx_manager: Node = null

func _ready() -> void:
	super._ready()
	effect_id = "mind_break"
	effect_name = "Mind Break"
	compositor_index = -1  # This manages multiple effects
	module_name = "VFX_MindBreak"

	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "Mind break handler ready")

func startup_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Mind break startup phase (%.1fs)" % time)
	
	# Play sound
	if mind_break_sound:
		play_effect_audio(mind_break_sound)
	
	# Get VFX manager reference
	vfx_manager = get_parent()
	if not vfx_manager:
		DebugLogger.error(module_name, "No VFX manager parent")
		return
	
	if not vfx_manager.has_method("invoke_effect"):
		DebugLogger.error(module_name, "Parent is not a VFX manager")
		return
	
	# Clear any previous effects
	active_sub_effects.clear()
	
	# Activate each effect with staggering
	for id in effects_to_activate:
		# Skip if it's mind_break itself or blink
		if id == "mind_break" or id == "blink":
			continue
			
		# Check if the effect exists
		if not vfx_manager.effect_handlers.has(id):
			DebugLogger.warning(module_name, "Effect not found: %s" % id)
			continue
		
		# Each sub-effect gets its own timing
		var sub_startup = 0.2  # Quick startup for each
		var sub_duration = 0  # Will be handled by our duration phase
		var sub_winddown = 0  # Will be handled by our wind down phase
		
		DebugLogger.debug(module_name, "Activating sub-effect: %s" % id)
		vfx_manager.invoke_effect(id, sub_startup, sub_duration, sub_winddown)
		active_sub_effects.append(id)
		
		if stagger_effects and stagger_delay > 0:
			await get_tree().create_timer(stagger_delay).timeout
	
	# Wait for remaining startup time
	var total_stagger_time = stagger_delay * (active_sub_effects.size() - 1) if stagger_effects else 0
	var remaining_time = max(0, time - total_stagger_time)
	if remaining_time > 0:
		await get_tree().create_timer(remaining_time).timeout
	
	DebugLogger.debug(module_name, "Activated %d sub-effects" % active_sub_effects.size())

func duration_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Mind break duration phase (%.1fs)" % time)
	
	# All effects run simultaneously during this phase
	if time > 0:
		await get_tree().create_timer(time).timeout

func wind_down_phase(time: float) -> void:
	DebugLogger.debug(module_name, "Mind break wind down phase (%.1fs)" % time)
	
	if not vfx_manager:
		return
	
	if not vfx_manager.has_method("stop_effect"):
		DebugLogger.error(module_name, "VFX manager has no stop_effect method")
		return
	
	# Stop all sub-effects with staggering (in reverse order for cool effect)
	var effects_to_stop = active_sub_effects.duplicate()
	effects_to_stop.reverse()
	
	for sub_effect_id in effects_to_stop:
		DebugLogger.debug(module_name, "Stopping sub-effect: %s" % sub_effect_id)
		vfx_manager.stop_effect(sub_effect_id)
		
		if stagger_effects and stagger_delay > 0:
			await get_tree().create_timer(stagger_delay).timeout
	
	# Wait for any remaining wind down time
	var total_stagger_time = stagger_delay * effects_to_stop.size() if stagger_effects else 0
	var remaining_time = max(0, time - total_stagger_time)
	if remaining_time > 0:
		await get_tree().create_timer(remaining_time).timeout
	
	# Clear the list
	active_sub_effects.clear()

func _cleanup() -> void:
	DebugLogger.debug(module_name, "Cleaning up mind break effect")
	
	# Stop all active sub-effects immediately
	if vfx_manager and vfx_manager.has_method("stop_effect"):
		for sub_effect_id in active_sub_effects:
			vfx_manager.stop_effect(sub_effect_id)
	
	active_sub_effects.clear()
	vfx_manager = null

func stop_immediately() -> void:
	# Stop all sub-effects immediately
	if vfx_manager and vfx_manager.has_method("stop_effect"):
		for sub_effect_id in active_sub_effects:
			vfx_manager.stop_effect(sub_effect_id)
	
	active_sub_effects.clear()
	
	super.stop_immediately()
