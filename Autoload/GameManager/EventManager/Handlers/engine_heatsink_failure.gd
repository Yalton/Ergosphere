# heatsink_failure.gd
extends EventHandler
class_name HeatsinkFailureEvent

@export_group("Heatsink Failure Settings")
## Sound to play when heatsink fails
@export var failure_sound: AudioStream

var failed_heatsink: StationEngine = null

func _ready() -> void:
	super._ready()
	module_name = "HeatsinkFailureEvent"
	
	# This handler handles the heatsink_failure event
	handled_event_ids = ["heatsink_failure"]

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Check if heatsink is operational
	if not check_state("engine_heatsink_operational", true):
		DebugLogger.debug(module_name, "Engine heatsink already failed")
		return false
	
	# Find operational engine heatsinks
	var engines = get_tree().get_nodes_in_group("station_engine")
	for engine in engines:
		if engine is StationEngine and engine.can_fail():
			return true
	
	DebugLogger.debug(module_name, "No operational engines available to fail")
	return false

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	# Update state
	set_state("engine_heatsink_operational", false)
	
	# Find all operational engines
	var engines = get_tree().get_nodes_in_group("station_engine")
	var operational_engines: Array[StationEngine] = []
	
	for engine in engines:
		if engine is StationEngine and engine.can_fail():
			operational_engines.append(engine)
	
	if operational_engines.is_empty():
		DebugLogger.error(module_name, "No operational engines found during execution")
		# Revert state since we couldn't actually fail anything
		set_state("engine_heatsink_operational", true)
		return false
	
	# Pick one at random to fail
	failed_heatsink = operational_engines[randi() % operational_engines.size()]
	
	# Connect to its repair signal
	if not failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.connect(_on_heatsink_fixed)
	
	# Trigger the failure
	failed_heatsink.trigger_failure()
	
	# Play failure sound
	if failure_sound:
		play_audio(failure_sound)
	
	# Create emergency task
	trigger_emergency_task("replace_heatsink")
	
	# Send player notification
	CommonUtils.send_player_hint("", "WARNING: Engine Heatsink Failure")
	
	DebugLogger.info(module_name, "Heatsink failure triggered on engine: " + failed_heatsink.name)
	
	return true

func end() -> void:
	# Clean up connections
	if failed_heatsink and failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.disconnect(_on_heatsink_fixed)
	
	failed_heatsink = null
	
	# Restore state
	set_state("engine_heatsink_operational", true)
	
	DebugLogger.info(module_name, "Heatsink failure event ended")
	
	# Call base implementation
	super.end()

func _on_heatsink_fixed() -> void:
	DebugLogger.info(module_name, "Heatsink has been fixed, ending event")
	
	# Tell EventManager to end this event
	if GameManager and GameManager.event_manager:
		GameManager.event_manager.end_event("heatsink_failure")
