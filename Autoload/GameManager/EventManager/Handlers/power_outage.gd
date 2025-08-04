extends EventHandler
class_name PowerOutageEvent

@export_group("Power Outage Settings")
## Sound to play when power fails
@export var power_failure_sound: AudioStream

## Sound to play when power is restored  
@export var power_restore_sound: AudioStream

func _ready() -> void:
	# This handler handles the power_outage event
	handled_event_ids = ["power_outage"]

func _can_execute_internal() -> Dictionary:
	# Check if power is currently on
	if not check_state("power", "on"):
		return {"success": false, "message": "Power is already off"}
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	# Set power state to off
	set_state("power", "off")
	
	# Notify all powered objects
	notify_group("powered_objects", "on_power_lost")
	
	# Play failure sound
	#if power_failure_sound:
		#play_audio(power_failure_sound)
	
	# Use effects manager for all power-related effects
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		effects_manager.kill_power()
		effects_manager.update_power_lever(false)
	else:
		return {"success": false, "message": "Could not find effects manager for power control"}
		
	# Create emergency task
	trigger_emergency_task("restore_power")
	
	# Send player notification
	CommonUtils.send_player_hint("", "WARNING: Station Power Failure")
	
	return {"success": true, "message": "OK"}

func end() -> void:
	# Restore power
	set_state("power", "on")
	
	# Notify all powered objects
	notify_group("powered_objects", "on_power_restored")
	
	# Play restore sound
	if power_restore_sound:
		play_audio(power_restore_sound)
		var effects_manager = get_tree().get_first_node_in_group("effects_manager")
		if effects_manager:
			effects_manager.update_power_lever(true)
	
	# Call base implementation
	super.end()
