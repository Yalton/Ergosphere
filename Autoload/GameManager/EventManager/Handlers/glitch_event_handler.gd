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
	# Define which events this handler processes
	handled_event_ids = ["terminal_glitch"]

func _can_execute_internal() -> Dictionary:
	# Check if there are any diegetic UI elements
	var ui_elements = get_tree().get_nodes_in_group(diegetic_ui_group)
	if ui_elements.is_empty():
		return {"success": false, "message": "No diegetic UI elements found in group: " + diegetic_ui_group}
	
	# Check if any have the corrupt_terminal method
	var valid_elements = false
	for element in ui_elements:
		if element.has_method("corrupt_terminal"):
			valid_elements = true
			break
	
	if not valid_elements:
		return {"success": false, "message": "No UI elements with corrupt_terminal method found"}
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	var ui_elements = get_tree().get_nodes_in_group(diegetic_ui_group)
	
	if ui_elements.is_empty():
		return {"success": false, "message": "No diegetic UI elements found during execution"}
	
	# Filter to only elements with corrupt_terminal method
	var valid_elements = []
	for element in ui_elements:
		if element.has_method("corrupt_terminal"):
			valid_elements.append(element)
	
	if valid_elements.is_empty():
		return {"success": false, "message": "No UI elements with corrupt_terminal method available"}
	
	# Pick random UI element
	glitched_ui = valid_elements.pick_random()
	
	# Get random duration
	glitch_duration = randf_range(min_glitch_duration, max_glitch_duration)
	
	# Corrupt the terminal
	glitched_ui.corrupt_terminal(glitch_duration)
	
	# End after duration
	get_tree().create_timer(glitch_duration).timeout.connect(func():
		if is_active:
			end()
	)
	
	return {"success": true, "message": "OK"}

func end() -> void:
	glitched_ui = null
	
	# Call base implementation
	super.end()
