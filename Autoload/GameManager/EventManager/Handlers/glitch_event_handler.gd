extends EventHandler
class_name DiageticUIGlitchEvent

## Duration range for the glitch effect in seconds
@export var min_glitch_duration: float = 2.0
@export var max_glitch_duration: float = 8.0

## Group name for diegetic UI elements that can be glitched
@export var diegetic_ui_group: String = "diegetic_ui"

func _ready() -> void:
	super._ready()
	DebugLogger.register_module("DiageticUIGlitchEvent")

func execute(params: Dictionary = {}) -> void:
	var ui_elements = get_tree().get_nodes_in_group(diegetic_ui_group)
	
	if ui_elements.is_empty():
		DebugLogger.log_warning("DiageticUIGlitchEvent", "No diegetic UI elements found in group: " + diegetic_ui_group)
		return
	
	# Pick random UI element
	var target_ui = ui_elements.pick_random() as DiegeticUIBase
	if target_ui == null:
		DebugLogger.log_error("DiageticUIGlitchEvent", "Selected element is not a DiegeticUIBase node")
		return
	
	# Get random duration
	var duration = randf_range(min_glitch_duration, max_glitch_duration)
	
	DebugLogger.log_debug("DiageticUIGlitchEvent", "Corrupting UI: " + target_ui.name + " for " + str(duration) + " seconds")
	
	# Corrupt the terminal
	target_ui.corrupt_terminal(duration)
