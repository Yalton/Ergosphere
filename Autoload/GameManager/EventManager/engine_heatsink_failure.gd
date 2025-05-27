extends BaseEvent
class_name HeatsinkFailureEvent

@export_group("Heatsink Failure Settings")
@export var failure_sound: AudioStream

var failed_heatsink: StationEngine = null
var audio_player: AudioStreamPlayer

func _ready() -> void:
	super._ready()
	event_name = "heatsink_failure"
	event_description = "Engine heatsink requires replacement"
	
	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "SFX"
	add_child(audio_player)

func _on_start(state_manager: StateManager) -> void:
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
	
	DebugLogger.info(module_name, "Heatsink failure event started - heatsink: " + failed_heatsink.name)

func _on_reverse(state_manager: StateManager) -> void:
	# This event can't be directly reversed - it requires player action
	DebugLogger.warning(module_name, "Heatsink failure cannot be reversed - requires heatsink replacement")

func _on_end(state_manager: StateManager) -> void:
	# Clean up connections
	if failed_heatsink and failed_heatsink.is_connected("heatsink_fixed", _on_heatsink_fixed):
		failed_heatsink.heatsink_fixed.disconnect(_on_heatsink_fixed)
	
	failed_heatsink = null
	
	# Update state
	state_manager.set_state("engine_heatsink_operational", true)
	
	DebugLogger.info(module_name, "Heatsink failure event ended")

func _on_heatsink_fixed() -> void:
	DebugLogger.info(module_name, "Heatsink has been fixed, ending event")
	
	# Tell GameManager the event is resolved
	if GameManager and GameManager.event_manager:
		GameManager.event_manager.end_event("heatsink_failure")
	else:
		# Fallback - end ourselves
		end_event(GameManager.state_manager if GameManager else null)
