extends EventHandler
class_name OxygenFailureEvent

@export_group("Oxygen Failure Settings")
## Sound to play when oxygen system fails
@export var failure_sound: AudioStream

## Sound to play when oxygen is restored
@export var restore_sound: AudioStream

func _ready() -> void:
	# This handler handles the oxygen_failure event
	handled_event_ids = ["oxygen_failure"]

func _can_execute_internal() -> Dictionary:
	# Check if oxygen system is currently operational
	if not check_state("oxygen_system", "operational"):
		return {"success": false, "message": "Oxygen system already failed"}
	
	# Could add additional checks here for oxygen tanks, etc.
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	# Set oxygen system state to failed
	set_state("oxygen_system", "failed")
	
	# Notify all oxygen-dependent systems
	notify_group("oxygen_dependent", "on_oxygen_lost")
	
	# Play failure sound
	if failure_sound:
		play_audio(failure_sound)
	
	# Create emergency task
	trigger_emergency_task("restore_oxygen")
	
	# Send player notification
	CommonUtils.send_player_hint("", "WARNING: Oxygen System Failure")
	
	# Could add additional effects here like:
	# - Start a timer for player suffocation
	# - Reduce visibility (fog effect)
	# - Play breathing difficulty sounds
	
	return {"success": true, "message": "OK"}

func end() -> void:
	# Restore oxygen system
	set_state("oxygen_system", "operational")
	
	# Notify all oxygen-dependent systems
	notify_group("oxygen_dependent", "on_oxygen_restored")
	
	# Play restore sound
	if restore_sound:
		play_audio(restore_sound)
	
	# Call base implementation
	super.end()
