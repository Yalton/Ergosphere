extends BaseEvent
class_name OxygenFailureEvent

@export_group("Oxygen Failure Settings")
@export var failure_sound: AudioStream

var failed_filter: OxygenFilter = null
var audio_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	event_name = "oxygen_failure"
	event_description = "Oxygen filter requires replacement"
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

func _on_start(state_manager: StateManager) -> void:
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
	
	DebugLogger.info(module_name, "Oxygen failure event started - filter: " + failed_filter.name)

func _on_reverse(_state_manager: StateManager) -> void:
	# This event can't be directly reversed - it requires player action
	DebugLogger.warning(module_name, "Oxygen failure cannot be reversed - requires filter replacement")

func _on_end(state_manager: StateManager) -> void:
	# Clean up connections
	if failed_filter and failed_filter.is_connected("filter_fixed", _on_filter_fixed):
		failed_filter.filter_fixed.disconnect(_on_filter_fixed)
	
	failed_filter = null
	
	# Update state
	state_manager.set_state("oxygen_system_operational", true)
	
	DebugLogger.info(module_name, "Oxygen failure event ended")

func _on_filter_fixed() -> void:
	DebugLogger.info(module_name, "Filter has been fixed, ending event")
	
	# Tell GameManager the event is resolved
	if GameManager and GameManager.event_manager:
		GameManager.event_manager.end_event("oxygen_failure")
	else:
		# Fallback - end ourselves
		end_event(GameManager.state_manager if GameManager else null)
