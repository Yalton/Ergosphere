# power_outage.gd
extends EventHandler
class_name PowerOutageEvent

@export_group("Power Outage Settings")
## Sound to play when power fails
@export var power_failure_sound: AudioStream

## Sound to play when power is restored  
@export var power_restore_sound: AudioStream

func _ready() -> void:
	super._ready()
	module_name = "PowerOutageEvent"
	
	# This handler handles the power_outage event
	handled_event_ids = ["power_outage"]

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Check if power is currently on
	if not check_state("power", "on"):
		DebugLogger.debug(module_name, "Power is already off")
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
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
		DebugLogger.error(module_name, "Could not find effects manager")
		
	# Create emergency task
	trigger_emergency_task("restore_power")
	
	# Send player notification
	CommonUtils.send_player_hint("", "WARNING: Station Power Failure")
	
	DebugLogger.info(module_name, "Power outage executed successfully")
	
	return true

func end() -> void:
	# Restore power
	set_state("power", "on")
	
	# Notify all powered objects
	notify_group("powered_objects", "on_power_restored")
	
	# Play restore sound
	if power_restore_sound:
		play_audio(power_restore_sound)
		var effects_manager = get_tree().get_first_node_in_group("effects_manager")
		effects_manager.update_power_lever(true)
	
	DebugLogger.info(module_name, "Power has been restored")
	
	# Call base implementation
	super.end()
