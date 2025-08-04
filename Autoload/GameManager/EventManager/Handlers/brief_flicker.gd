extends EventHandler
class_name BriefFlickerEvent

## Handles brief light flickering effects

func _ready() -> void:
	# Define which events this handler processes
	handled_event_ids = ["brief_flicker", "purple_shift", "brightness_boost"]

func _can_execute_internal() -> Dictionary:
	# Find effects manager
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		return {"success": false, "message": "No effects manager found in scene"}
	
	# Check if the required method exists
	match event_data.id:
		"brief_flicker":
			if not effects_manager.has_method("trigger_brief_flicker"):
				return {"success": false, "message": "Effects manager missing trigger_brief_flicker method"}
		"purple_shift":
			if not effects_manager.has_method("trigger_purple_shift"):
				return {"success": false, "message": "Effects manager missing trigger_purple_shift method"}
		"brightness_boost":
			if not effects_manager.has_method("trigger_brightness_boost"):
				return {"success": false, "message": "Effects manager missing trigger_brightness_boost method"}
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		return {"success": false, "message": "Could not find effects manager during execution"}
	
	match event_data.id:
		"brief_flicker":
			effects_manager.trigger_brief_flicker()
		
		"purple_shift":
			effects_manager.trigger_purple_shift()
		
		"brightness_boost":
			effects_manager.trigger_brightness_boost()
		
		_:
			return {"success": false, "message": "Unknown event ID during execution: " + event_data.id}
	
	# These are instant effects, end immediately
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_active:
			end()
	)
	
	return {"success": true, "message": "OK"}

func end() -> void:
	# Call base implementation
	super.end()
