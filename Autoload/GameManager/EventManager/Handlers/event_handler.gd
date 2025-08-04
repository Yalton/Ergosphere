extends Node
class_name EventHandler

## Array of event IDs this handler can process
@export var handled_event_ids: Array[String] = []

## The event data this handler is currently executing
var event_data: EventData

## Time when this event started (for duration tracking)
var start_time: float = 0.0

## Is this event currently active
var is_active: bool = false

signal event_completed()
signal event_failed(reason: String)

## Check if this handler handles a specific event ID
func handles_event(event_id: String) -> bool:
	return event_id in handled_event_ids

## Check if this event can execute right now with status return
func can_execute_with_status() -> Dictionary:
	# Base implementation - check basic requirements
	if not GameManager or not GameManager.state_manager:
		return {"success": false, "message": "No GameManager or StateManager available"}
	
	# Check day requirement
	if event_data and GameManager.get_current_day() < event_data.min_day:
		return {"success": false, "message": "Day requirement not met. Current: " + str(GameManager.get_current_day()) + ", Required: " + str(event_data.min_day)}
	
	# Call the override method for specific checks
	return _can_execute_internal()

## Override this in subclasses for custom checks
func _can_execute_internal() -> Dictionary:
	return {"success": true, "message": "OK"}

## Check if this event can execute right now. Legacy support
func can_execute() -> bool:
	return can_execute_with_status().success

## Execute the event with status return
func execute_with_status() -> Dictionary:
	if is_active:
		return {"success": false, "message": "Event already active"}
	
	is_active = true
	start_time = Time.get_ticks_msec() / 1000.0
	
	# Call the override method for actual execution
	return _execute_internal()

## Override this in subclasses for custom execution
func _execute_internal() -> Dictionary:
	return {"success": true, "message": "OK"}

## Execute the event. Legacy support
func execute() -> bool:
	return execute_with_status().success

## Called when the event naturally ends. Override this!
func end() -> void:
	if not is_active:
		return
	
	is_active = false
	event_completed.emit()

## Get how long this event has been running
func get_duration() -> float:
	if not is_active:
		return 0.0
	return (Time.get_ticks_msec() / 1000.0) - start_time

## Helper to get state manager
func get_state_manager() -> StateManager:
	if GameManager and GameManager.state_manager:
		return GameManager.state_manager
	return null

## Helper to check a state value
func check_state(state_key: String, expected_value = null) -> bool:
	var state_manager = get_state_manager()
	if not state_manager:
		return false
	
	var current_value = state_manager.get_state(state_key)
	if expected_value == null:
		return current_value != null
	return current_value == expected_value

## Helper to set a state value
func set_state(state_key: String, value) -> void:
	var state_manager = get_state_manager()
	if state_manager:
		state_manager.set_state(state_key, value)

## Helper to trigger an emergency task
func trigger_emergency_task(task_id: String) -> void:
	if GameManager and GameManager.task_manager:
		GameManager.task_manager.trigger_emergency_task(task_id)

## Helper to play audio
func play_audio(audio_stream: AudioStream, bus: String = "SFX") -> void:
	if not audio_stream:
		return
	
	Audio.play_sound(audio_stream, true, 1.0, 0.0, bus)

## Helper to notify object groups
func notify_group(group_name: String, method_name: String, args: Array = []) -> void:
	var nodes = get_tree().get_nodes_in_group(group_name)
	
	for node in nodes:
		if node.has_method(method_name):
			node.callv(method_name, args)
