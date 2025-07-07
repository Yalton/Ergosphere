# brief_flicker.gd
extends EventHandler
class_name BriefFlickerEvent

## Handles brief light flickering effects

func _ready() -> void:
	super._ready()
	module_name = "BriefFlickerEvent"
	
	# Define which events this handler processes
	handled_event_ids = ["brief_flicker", "purple_shift", "brightness_boost"]
	
	DebugLogger.debug(module_name, "BriefFlickerEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Find effects manager
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		DebugLogger.warning(module_name, "No effects manager found")
		return false
	
	# Check if the required method exists
	match event_data.id:
		"brief_flicker":
			if not effects_manager.has_method("trigger_brief_flicker"):
				DebugLogger.warning(module_name, "Effects manager missing trigger_brief_flicker method")
				return false
		"purple_shift":
			if not effects_manager.has_method("trigger_purple_shift"):
				DebugLogger.warning(module_name, "Effects manager missing trigger_purple_shift method")
				return false
		"brightness_boost":
			if not effects_manager.has_method("trigger_brightness_boost"):
				DebugLogger.warning(module_name, "Effects manager missing trigger_brightness_boost method")
				return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		DebugLogger.error(module_name, "Could not find effects manager during execution")
		return false
	
	match event_data.id:
		"brief_flicker":
			DebugLogger.info(module_name, "Executing brief flicker")
			effects_manager.trigger_brief_flicker()
		
		"purple_shift":
			DebugLogger.info(module_name, "Executing purple shift")
			effects_manager.trigger_purple_shift()
		
		"brightness_boost":
			DebugLogger.info(module_name, "Executing brightness boost")
			effects_manager.trigger_brightness_boost()
		
		_:
			DebugLogger.warning(module_name, "Unknown event ID: " + event_data.id)
			return false
	
	# These are instant effects, end immediately
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_active:
			end()
	)
	
	return true

func end() -> void:
	DebugLogger.info(module_name, "Light effect event completed: " + event_data.id)
	
	# Call base implementation
	super.end()
