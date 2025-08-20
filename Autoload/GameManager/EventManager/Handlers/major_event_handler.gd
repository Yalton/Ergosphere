extends EventHandler
class_name MajorEventHandler

## Handles all major station events: hawking radiation, power outages, oxygen failures, and heatsink failures

# ============== POWER OUTAGE SETTINGS ==============
@export_group("Power Outage Settings")
## Sound to play when power fails
@export var power_failure_sound: AudioStream
## Sound to play when power is restored  
@export var power_restore_sound: AudioStream

# ============== OXYGEN FAILURE SETTINGS ==============
@export_group("Oxygen Failure Settings")
## Sound to play when oxygen system fails
@export var oxygen_failure_sound: AudioStream
## Sound to play when oxygen is restored
@export var oxygen_restore_sound: AudioStream

# ============== HEATSINK FAILURE SETTINGS ==============
@export_group("Heatsink Failure Settings")
## Sound to play when heatsink fails
@export var heatsink_failure_sound: AudioStream

# State tracking for heatsink failure
var failed_heatsink: StationEngine = null

func _ready() -> void:
	# All events this consolidated handler processes
	handled_event_ids = [
		"hawking_radiation", "shutter_warning",
		"power_outage",
		"oxygen_failure",
		"heatsink_failure"
	]
	
	DebugLogger.register_module("MajorEventHandler")
	
	# Initialize default states if they don't exist
	_initialize_states()

func _initialize_states() -> void:
	var state_manager = get_state_manager()
	if not state_manager:
		return
	
	# Initialize states with defaults if they don't exist
	if state_manager.get_state("power") == null:
		state_manager.set_state("power", "on")
	
	if state_manager.get_state("oxygen_system") == null:
		state_manager.set_state("oxygen_system", "operational")
	
	if state_manager.get_state("engine_heatsink_operational") == null:
		state_manager.set_state("engine_heatsink_operational", true)

func _can_execute_internal() -> Dictionary:
	DebugLogger.log_message("MajorEventHandler", "Checking if can execute: " + event_data.id)
	
	match event_data.id:
		"hawking_radiation", "shutter_warning":
			return _can_execute_hawking()
		"power_outage":
			return _can_execute_power_outage()
		"oxygen_failure":
			return _can_execute_oxygen_failure()
		"heatsink_failure":
			return _can_execute_heatsink_failure()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func _execute_internal() -> Dictionary:
	DebugLogger.log_message("MajorEventHandler", "Executing event: " + event_data.id)
	
	match event_data.id:
		"hawking_radiation", "shutter_warning":
			return _execute_hawking()
		"power_outage":
			return _execute_power_outage()
		"oxygen_failure":
			return _execute_oxygen_failure()
		"heatsink_failure":
			return _execute_heatsink_failure()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func end() -> void:
	DebugLogger.log_message("MajorEventHandler", "Ending event: " + event_data.id)
	
	# Clean up based on event type
	match event_data.id:
		"hawking_radiation", "shutter_warning":
			# Hawking cleanup is now minimal - consequences are handled by HawkingConsequence
			pass
		"power_outage":
			_end_power_outage()
		"oxygen_failure":
			_end_oxygen_failure()
		"heatsink_failure":
			_end_heatsink_failure()
		_:
			pass
	
	# Call base implementation
	super.end()

# ============== HAWKING RADIATION FUNCTIONS ==============
func _can_execute_hawking() -> Dictionary:
	var window_lever = get_tree().get_first_node_in_group("window_lever")
	if not window_lever:
		return {"success": false, "message": "No window lever found in scene"}
	
	# Check if shutters are open
	if not window_lever.shutters_open:
		return {"success": false, "message": "Shutters are closed - event won't proc"}
	
	return {"success": true, "message": "OK"}

func _execute_hawking() -> Dictionary:
	# Simply trigger the emergency task and send warning
	# All consequence handling is done by HawkingConsequence when task fails
	trigger_emergency_task("hawking_radiation")
	
	CommonUtils.send_player_hint("", "WARNING: Hawking radiation detected! Close the shutters immediately!")
	
	DebugLogger.log_message("MajorEventHandler", "Hawking radiation task triggered - consequences handled by HawkingConsequence")
	
	return {"success": true, "message": "OK"}

# ============== POWER OUTAGE FUNCTIONS ==============
func _can_execute_power_outage() -> Dictionary:
	# Initialize state if needed
	var state_manager = get_state_manager()
	if state_manager and state_manager.get_state("power") == null:
		state_manager.set_state("power", "on")
	
	if not check_state("power", "on"):
		return {"success": false, "message": "Power is already off"}
	
	return {"success": true, "message": "OK"}

func _execute_power_outage() -> Dictionary:
	set_state("power", "off")
	
	notify_group("powered_objects", "on_power_lost")
	
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager:
		effects_manager.kill_power()
		effects_manager.update_power_lever(false)
	else:
		return {"success": false, "message": "Could not find effects manager for power control"}
		
	trigger_emergency_task("restore_power")
	
	CommonUtils.send_player_hint("", "WARNING: Station Power Failure")
	
	return {"success": true, "message": "OK"}

func _end_power_outage() -> void:
	set_state("power", "on")
	
	notify_group("powered_objects", "on_power_restored")
	
	if power_restore_sound:
		play_audio(power_restore_sound)
		var effects_manager = get_tree().get_first_node_in_group("effects_manager")
		if effects_manager:
			effects_manager.update_power_lever(true)

# ============== OXYGEN FAILURE FUNCTIONS ==============
func _can_execute_oxygen_failure() -> Dictionary:
	# Initialize state if needed
	var state_manager = get_state_manager()
	if state_manager and state_manager.get_state("oxygen_system") == null:
		state_manager.set_state("oxygen_system", "operational")
	
	if not check_state("oxygen_system", "operational"):
		return {"success": false, "message": "Oxygen system already failed"}
	
	return {"success": true, "message": "OK"}

func _execute_oxygen_failure() -> Dictionary:
	set_state("oxygen_system", "failed")
	
	notify_group("oxygen_dependent", "on_oxygen_lost")
	
	if oxygen_failure_sound:
		play_audio(oxygen_failure_sound)
	
	trigger_emergency_task("oxygen_filter_failure")
	
	CommonUtils.send_player_hint("", "WARNING: Oxygen System Failure")
	
	return {"success": true, "message": "OK"}

func _end_oxygen_failure() -> void:
	set_state("oxygen_system", "operational")
	
	notify_group("oxygen_dependent", "on_oxygen_restored")
	
	if oxygen_restore_sound:
		play_audio(oxygen_restore_sound)

# ============== HEATSINK FAILURE FUNCTIONS ==============
func _can_execute_heatsink_failure() -> Dictionary:
	# Initialize state if needed
	var state_manager = get_state_manager()
	if state_manager and state_manager.get_state("engine_heatsink_operational") == null:
		state_manager.set_state("engine_heatsink_operational", true)
	
	if not check_state("engine_heatsink_operational", true):
		return {"success": false, "message": "Engine heatsink already failed"}
	
	var engines = get_tree().get_nodes_in_group("station_engine")
	var operational_count = 0
	
	for engine in engines:
		if engine is StationEngine and engine.can_fail():
			operational_count += 1
	
	if operational_count == 0:
		return {"success": false, "message": "No operational engines available to fail"}
	
	return {"success": true, "message": "OK"}

func _execute_heatsink_failure() -> Dictionary:
	set_state("engine_heatsink_operational", false)
	
	var engines = get_tree().get_nodes_in_group("station_engine")
	var operational_engines: Array[StationEngine] = []
	
	for engine in engines:
		if engine is StationEngine and engine.can_fail():
			operational_engines.append(engine)
	
	if operational_engines.is_empty():
		set_state("engine_heatsink_operational", true)
		return {"success": false, "message": "No operational engines found during execution"}
	
	failed_heatsink = operational_engines[randi() % operational_engines.size()]
	
	if not failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.connect(_on_heatsink_fixed)
	
	failed_heatsink.trigger_failure()
	
	if heatsink_failure_sound:
		play_audio(heatsink_failure_sound)
	
	trigger_emergency_task("replace_heatsink")
	
	CommonUtils.send_player_hint("", "WARNING: Engine Heatsink Failure")
	
	return {"success": true, "message": "OK"}

func _end_heatsink_failure() -> void:
	if failed_heatsink and failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.disconnect(_on_heatsink_fixed)
	
	failed_heatsink = null
	
	set_state("engine_heatsink_operational", true)

func _on_heatsink_fixed() -> void:
	if GameManager and GameManager.event_manager:
		GameManager.event_manager.end_event("heatsink_failure")
