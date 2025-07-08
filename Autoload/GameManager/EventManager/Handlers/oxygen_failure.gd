# oxygen_failure.gd
extends EventHandler
class_name OxygenFailureEvent

@export_group("Oxygen Failure Settings")
## Sound to play when oxygen filter fails
@export var failure_sound: AudioStream

var failed_filter: OxygenFilter = null

func _ready() -> void:
	super._ready()
	module_name = "OxygenFailureEvent"
	
	# This handler handles the oxygen_failure event
	handled_event_ids = ["oxygen_failure"]

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Find operational oxygen filters
	var oxygen_filters = get_tree().get_nodes_in_group("oxygen_filters")
	for filter in oxygen_filters:
		if filter is OxygenFilter and filter.can_fail():
			return true
	
	DebugLogger.debug(module_name, "No operational oxygen filters available to fail")
	return false

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	# Find all operational oxygen filters
	var oxygen_filters = get_tree().get_nodes_in_group("oxygen_filters")
	var operational_filters: Array[OxygenFilter] = []
	
	for filter in oxygen_filters:
		if filter is OxygenFilter and filter.can_fail():
			operational_filters.append(filter)
	
	if operational_filters.is_empty():
		DebugLogger.error(module_name, "No operational filters found during execution")
		return false
	
	# Pick one at random to fail
	failed_filter = operational_filters[randi() % operational_filters.size()]
	
	# Connect to its repair signal
	if not failed_filter.is_connected("filter_fixed", _on_filter_fixed):
		failed_filter.filter_fixed.connect(_on_filter_fixed)
	
	# Trigger the failure
	failed_filter.trigger_failure()
	
	# Play failure sound
	if failure_sound:
		play_audio(failure_sound)
	
	# Create emergency task
	trigger_emergency_task("oxygen_filter_failure")
	
	# Send player notification
	CommonUtils.send_player_hint("", "WARNING: Oxygen System Failure")
	
	DebugLogger.info(module_name, "Oxygen failure triggered on filter: " + failed_filter.name)
	
	return true

func end() -> void:
	# Clean up connections
	if failed_filter and failed_filter.is_connected("filter_fixed", _on_filter_fixed):
		failed_filter.filter_fixed.disconnect(_on_filter_fixed)
	
	failed_filter = null
	
	DebugLogger.info(module_name, "Oxygen failure event ended")
	
	# Call base implementation
	super.end()

func _on_filter_fixed() -> void:
	DebugLogger.info(module_name, "Filter has been fixed, ending event")
	
	# Tell EventManager to end this event
	if GameManager and GameManager.event_manager:
		GameManager.event_manager.end_event("oxygen_failure")
