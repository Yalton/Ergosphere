# HeatsinkFailureHandler.gd
extends EventHandler
class_name HeatsinkFailureHandler

## Heatsink failure event handler for the new event system
## Handles engine heatsink failures and replacement

@export_group("Heatsink Failure Settings")
## Sound to play when heatsink system fails
@export var failure_sound: AudioStream

var failed_heatsink: StationEngine = null
var audio_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	module_name = "HeatsinkFailureHandler"
	
	# Define which events this handler processes
	handled_event_ids = ["heatsink_failure", "engine_overheat", "cooling_system_failure"]
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	DebugLogger.debug(module_name, "HeatsinkFailureHandler ready")

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	## Handle heatsink failure event execution
	DebugLogger.info(module_name, "Executing heatsink event: %s" % event_data.event_id)
	
	match event_data.event_id:
		"heatsink_failure":
			_handle_heatsink_failure(event_data, state_manager)
		"engine_overheat":
			_handle_engine_overheat(event_data, state_manager)
		"cooling_system_failure":
			_handle_cooling_system_failure(event_data, state_manager)

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	## Handle heatsink failure event completion
	DebugLogger.info(module_name, "Completing heatsink event: %s" % event_data.event_id)
	
	match event_data.event_id:
		"heatsink_failure":
			_complete_heatsink_failure(event_data, state_manager)
		"engine_overheat":
			_complete_engine_overheat(event_data, state_manager)
		"cooling_system_failure":
			_complete_cooling_system_failure(event_data, state_manager)

func _handle_heatsink_failure(event_data: EventData, state_manager: StateManager) -> void:
	## Handle heatsink system failure
	DebugLogger.debug(module_name, "Heatsink failure started")
	
	# Update state
	state_manager.set_state("engine_heatsink_operational", false)
	
	# Find all operational engine heatsinks
	var engine_heatsinks = get_tree().get_nodes_in_group("station_engine")
	var operational_heatsinks: Array[StationEngine] = []
	
	for heatsink in engine_heatsinks:
		if heatsink is StationEngine and heatsink.can_fail():
			operational_heatsinks.append(heatsink)
	
	if operational_heatsinks.is_empty():
		DebugLogger.warning(module_name, "No operational engine heatsinks found to fail")
		return
	
	# Pick one at random
	failed_heatsink = operational_heatsinks[randi() % operational_heatsinks.size()]
	
	# Connect to its repair signal
	if not failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.connect(_on_heatsink_fixed)
	
	# Trigger the failure
	failed_heatsink.trigger_failure()
	
	# Play failure sound
	if failure_sound and audio_player:
		audio_player.stream = failure_sound
		audio_player.play()
	
	# Show warning message
	if CommonUtils:
		CommonUtils.send_player_hint("", "WARNING: Engine Heatsink Failure")
	
	# Trigger emergency task if task system is available
	if GameManager and GameManager.task_manager:
		GameManager.task_manager.trigger_emergency_task("replace_heatsink")
	
	DebugLogger.info(module_name, "Heatsink failure event started - heatsink: %s" % failed_heatsink.name)

func _handle_engine_overheat(event_data: EventData, state_manager: StateManager) -> void:
	## Handle engine overheating
	DebugLogger.debug(module_name, "Engine overheat started")
	
	# Show warning
	if CommonUtils:
		CommonUtils.send_player_hint("", "WARNING: Engine Temperature Critical")

func _handle_cooling_system_failure(event_data: EventData, state_manager: StateManager) -> void:
	## Handle cooling system failure
	DebugLogger.debug(module_name, "Cooling system failure started")
	
	# Show warning
	if CommonUtils:
		CommonUtils.send_player_hint("", "WARNING: Cooling System Failure")

func _complete_heatsink_failure(event_data: EventData, state_manager: StateManager) -> void:
	## Complete heatsink failure (heatsink replaced)
	DebugLogger.debug(module_name, "Heatsink failure completed - heatsink replaced")
	
	# Clean up connections
	if failed_heatsink and failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.disconnect(_on_heatsink_fixed)
	
	failed_heatsink = null
	
	# Update state
	state_manager.set_state("engine_heatsink_operational", true)
	
	# Show restoration message
	if CommonUtils:
		CommonUtils.send_player_hint("", "Engine Heatsink Systems Restored")
	
	DebugLogger.info(module_name, "Heatsink failure event ended")

func _complete_engine_overheat(event_data: EventData, state_manager: StateManager) -> void:
	## Complete engine overheat
	DebugLogger.debug(module_name, "Engine overheat completed")
	
	if CommonUtils:
		CommonUtils.send_player_hint("", "Engine Temperature Normalized")

func _complete_cooling_system_failure(event_data: EventData, state_manager: StateManager) -> void:
	## Complete cooling system failure
	DebugLogger.debug(module_name, "Cooling system failure completed")
	
	if CommonUtils:
		CommonUtils.send_player_hint("", "Cooling Systems Restored")

func _on_heatsink_fixed() -> void:
	## Called when the failed heatsink is fixed by player
	DebugLogger.info(module_name, "Heatsink has been fixed, completing event")
	
	# Tell EventManager the event is resolved
	if GameManager and GameManager.event_manager:
		GameManager.event_manager.complete_event("heatsink_failure")
