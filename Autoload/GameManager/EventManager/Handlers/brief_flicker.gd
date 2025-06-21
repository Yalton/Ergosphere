# LightEffectsEventHandler.gd
extends EventHandler
class_name LightEffectsEventHandler

## Single handler for all light/emissive effects

var effects_manager: Node

func _ready() -> void:
	module_name = "LightEffectsEvent"
	super._ready()
	
	handled_event_ids = ["brief_flicker", "purple_shift", "brightness_boost"]
	
	DebugLogger.register_module(module_name, true)
	DebugLogger.debug(module_name, "LightEffectsEventHandler ready")

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if not effects_manager:
		DebugLogger.error(module_name, "Could not find effects manager")
		return
	
	match event_data.event_id:
		"brief_flicker":
			DebugLogger.info(module_name, "Executing brief flicker")
			if effects_manager.has_method("trigger_brief_flicker"):
				effects_manager.trigger_brief_flicker()
		
		"purple_shift":
			DebugLogger.info(module_name, "Executing purple shift")
			if effects_manager.has_method("trigger_purple_shift"):
				effects_manager.trigger_purple_shift()
		
		"brightness_boost":
			DebugLogger.info(module_name, "Executing brightness boost")
			if effects_manager.has_method("trigger_brightness_boost"):
				effects_manager.trigger_brightness_boost()
		
		_:
			DebugLogger.warning(module_name, "Unknown event ID: " + event_data.event_id)
