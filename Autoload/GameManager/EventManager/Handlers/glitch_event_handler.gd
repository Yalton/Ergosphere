# glitch_event.gd
extends EventHandler
class_name GlitchEvent

## Glitches random diegetic UI elements for a duration

@export_group("Glitch Settings")
## Duration range for the glitch effect in seconds
@export var min_glitch_duration: float = 2.0
@export var max_glitch_duration: float = 8.0
## Group name for diegetic UI elements that can be glitched
@export var diegetic_ui_group: String = "diegetic_ui"

var glitched_ui: Node = null
var glitch_duration: float = 0.0

func _ready() -> void:
	super._ready()
	module_name = "GlitchEvent"
	
	# Define which events this handler processes
	handled_event_ids = ["terminal_glitch"]
	
	DebugLogger.debug(module_name, "GlitchEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Check if there are any diegetic UI elements
	var ui_elements = get_tree().get_nodes_in_group(diegetic_ui_group)
	if ui_elements.is_empty():
		DebugLogger.warning(module_name, "No diegetic UI elements found in group: " + diegetic_ui_group)
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	var ui_elements = get_tree().get_nodes_in_group(diegetic_ui_group)
	
	if ui_elements.is_empty():
		DebugLogger.error(module_name, "No diegetic UI elements found during execution")
		return false
	
	# Pick random UI element
	glitched_ui = ui_elements.pick_random()
	
	# Check if it has the corrupt_terminal method
	if not glitched_ui.has_method("corrupt_terminal"):
		DebugLogger.error(module_name, "Selected UI element doesn't have corrupt_terminal method: " + glitched_ui.name)
		return false
	
	# Get random duration
	glitch_duration = randf_range(min_glitch_duration, max_glitch_duration)
	
	DebugLogger.info(module_name, "Corrupting UI: " + glitched_ui.name + " for " + str(glitch_duration) + " seconds")
	
	# Corrupt the terminal
	glitched_ui.corrupt_terminal(glitch_duration)
	
	# End after duration
	get_tree().create_timer(glitch_duration).timeout.connect(func():
		if is_active:
			end()
	)
	
	return true

func end() -> void:
	DebugLogger.info(module_name, "Glitch event completed on: " + (glitched_ui.name if glitched_ui else "unknown"))
	
	glitched_ui = null
	
	# Call base implementation
	super.end()
