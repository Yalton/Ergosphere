# OxygenFailureHandler.gd
extends EventHandler
class_name OxygenFailureHandler

## Oxygen failure event handler for the new event system
## Handles oxygen filter failures and replacement

@export_group("Oxygen Failure Settings")
## Sound to play when oxygen system fails
@export var failure_sound: AudioStream

var failed_filter: OxygenFilter = null
var audio_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	module_name = "OxygenFailureHandler"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Define which events this handler processes
	handled_event_ids = ["oxygen_failure"]
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)
	
	DebugLogger.debug(module_name, "OxygenFailureHandler ready")

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	## Handle oxygen failure event execution
	DebugLogger.info(module_name, "Executing oxygen event: %s" % event_data.event_id)
	
	if event_data.event_id == "oxygen_filter_failure":
		_handle_oxygen_failure(event_data, state_manager)

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	## Handle oxygen failure event completion
	DebugLogger.info(module_name, "Completing oxygen event: %s" % event_data.event_id)
	
	if event_data.event_id == "oxygen_filter_failure":
		_complete_oxygen_failure(event_data, state_manager)

func _handle_oxygen_failure(event_data: EventData, state_manager: StateManager) -> void:
	## Handle oxygen system failure
	DebugLogger.debug(module_name, "Oxygen failure started")
	
	# Check if oxygen repair task is already active
	if GameManager and GameManager.task_manager:
		var existing_task = GameManager.task_manager.get_task("replace_oxygen_filter")
		if existing_task and not existing_task.is_completed:
			DebugLogger.info(module_name, "Oxygen repair task already active, skipping failure event")
			return
	
	# Update state
	state_manager.set_state("oxygen_system_operational", false)
	
	# Find all operational oxygen filters
	var oxygen_filters = get_tree().get_nodes_in_group("oxygen_filters")
	var operational_filters: Array[OxygenFilter] = []
	
	for filter in oxygen_filters:
		if filter is OxygenFilter and filter.can_fail():
			operational_filters.append(filter)
	
	if operational_filters.is_empty():
		DebugLogger.warning(module_name, "No operational oxygen filters found to fail")
		return
	
	# Pick one at random
	failed_filter = operational_filters[randi() % operational_filters.size()]
	
	# Connect to its repair signal
	if not failed_filter.is_connected("filter_fixed", _on_filter_fixed):
		failed_filter.filter_fixed.connect(_on_filter_fixed)
	
	# Trigger the failure
	failed_filter.trigger_failure()
	
	# Play failure sound
	if failure_sound and audio_player:
		audio_player.stream = failure_sound
		audio_player.play()
	
	# Show warning message
	if CommonUtils:
		CommonUtils.send_player_hint("", "WARNING: Oxygen System Failure")
	
	# Trigger emergency task if task system is available
	if GameManager and GameManager.task_manager:
		GameManager.task_manager.trigger_emergency_task("replace_oxygen_filter")
	
	DebugLogger.info(module_name, "Oxygen failure event started - filter: %s" % failed_filter.name)

func _complete_oxygen_failure(event_data: EventData, state_manager: StateManager) -> void:
	## Complete oxygen failure (filter replaced)
	DebugLogger.debug(module_name, "Oxygen failure completed - filter replaced")
	
	# Clean up connections
	if failed_filter and failed_filter.is_connected("filter_fixed", _on_filter_fixed):
		failed_filter.filter_fixed.disconnect(_on_filter_fixed)
	
	failed_filter = null
	
	# Update state
	state_manager.set_state("oxygen_system_operational", true)
	
	# Show restoration message
	if CommonUtils:
		CommonUtils.send_player_hint("", "Oxygen Systems Restored")
	
	DebugLogger.info(module_name, "Oxygen failure event ended")

func _on_filter_fixed() -> void:
	## Called when the failed filter is fixed by player
	DebugLogger.info(module_name, "Filter has been fixed, completing event")
	
	# Tell EventManager the event is resolved
	if GameManager and GameManager.event_manager:
		GameManager.event_manager.complete_event("oxygen_filter_failure")
