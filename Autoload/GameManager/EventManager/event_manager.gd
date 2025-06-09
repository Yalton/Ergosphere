# EventManager.gd - Debug Fix for Array Type Error
extends Node
class_name EventManager

signal event_triggered(event_id: String)
signal event_ended(event_id: String)

@export var enable_debug: bool = true
var module_name: String = "EventManager"

# Current day configuration
var current_day_config: DayConfigResource = null

# Active events tracking
var active_events: Dictionary = {}  # event_id -> BaseEvent node
var available_event_ids: Array[String] = []  # Event IDs available today

# References
var state_manager: StateManager
var task_manager: TaskManager

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect to GameManager's day_reset signal
	if GameManager:
		GameManager.day_reset.connect(_on_day_reset)
		DebugLogger.debug(module_name, "Connected to day_reset signal")

func initialize(_state_manager: StateManager) -> void:
	state_manager = _state_manager
	
	# Reset everything first
	_reset_event_system()
	
	# Find task manager
	if GameManager:
		task_manager = GameManager.task_manager
		if task_manager and not task_manager.task_completed.is_connected(_on_task_completed):
			task_manager.task_completed.connect(_on_task_completed)
	
	# Find all event nodes
	for child in get_children():
		if child is BaseEvent:
			DebugLogger.debug(module_name, "Found event: " + child.name)
	
	DebugLogger.info(module_name, "EventManager initialized and reset with " + str(get_child_count()) + " events")

func _reset_event_system() -> void:
	# End all active events properly
	for event_id in active_events.keys():
		var event = active_events[event_id]
		if event and is_instance_valid(event):
			event.is_active = false
			# Reset any event-specific state
			if event.has_method("_on_end"):
				event._on_end(state_manager)
	
	# Clear all tracking
	active_events.clear()
	available_event_ids.clear()
	current_day_config = null
	
	DebugLogger.debug(module_name, "Event system reset")

func set_day_events(day_config: DayConfigResource) -> void:
	current_day_config = day_config
	available_event_ids.clear()
	
	# Clear any active events from previous day
	for event_id in active_events.keys():
		end_event(event_id)
	
	if not day_config:
		DebugLogger.debug(module_name, "No day config, all events available")
		# Make all events available
		for child in get_children():
			if child is BaseEvent:
				available_event_ids.append(child.name)
		return
	
	# Debug: Check the type of available_event_ids from config
	DebugLogger.debug(module_name, "Day config available_event_ids type: " + str(typeof(day_config.available_event_ids)))
	DebugLogger.debug(module_name, "Day config available_event_ids content: " + str(day_config.available_event_ids))
	
	# Validate and copy available events from config
	if day_config.available_event_ids is Array:
		for item in day_config.available_event_ids:
			if item is String:
				available_event_ids.append(item)
			else:
				DebugLogger.error(module_name, "Non-string item found in available_event_ids: " + str(item) + " (type: " + str(typeof(item)) + ")")
				# If it's an array, try to extract strings from it
	else:
		DebugLogger.error(module_name, "available_event_ids is not an array! Type: " + str(typeof(day_config.available_event_ids)))
	
	# Remove excluded events
	for excluded_id in day_config.excluded_events:
		available_event_ids.erase(excluded_id)
	
	# Trigger guaranteed events
	for event_id in day_config.guaranteed_events:
		if event_id in available_event_ids or day_config.guaranteed_events.has(event_id):
			# Wait a frame to ensure everything is set up
			await get_tree().process_frame
			trigger_event(event_id)
	
	DebugLogger.info(module_name, "Set up " + str(available_event_ids.size()) + " events for the day")

func _on_task_completed(task_id: String) -> void:
	# Check if any events should trigger based on task completion
	# This would be configured in the event nodes themselves
	for child in get_children():
		if child is BaseEvent and child.has_method("check_task_trigger"):
			child.check_task_trigger(task_id)

func trigger_event(event_id: String) -> void:
	# Check if event is available today
	if current_day_config and available_event_ids.size() > 0 and not event_id in available_event_ids:
		DebugLogger.warning(module_name, "Event not available today: " + event_id)
		return
	
	var event = get_node_or_null(event_id)
	
	if not event:
		DebugLogger.error(module_name, "Event not found: " + event_id)
		return
		
	if not event is BaseEvent:
		DebugLogger.error(module_name, "Node is not a BaseEvent: " + event_id)
		return
	
	if active_events.has(event_id):
		DebugLogger.warning(module_name, "Event already active: " + event_id)
		return
	
	DebugLogger.debug(module_name, "Triggering event: " + event_id)
	
	# Track the event
	active_events[event_id] = event
	
	# Start the event
	event.start_event(state_manager)
	
	event_triggered.emit(event_id)

func reverse_event(event_id: String) -> void:
	if not active_events.has(event_id):
		DebugLogger.warning(module_name, "Cannot reverse inactive event: " + event_id)
		return
	
	var event = active_events[event_id]
	
	DebugLogger.debug(module_name, "Reversing event: " + event_id)
	
	# Reverse the event
	event.reverse_event(state_manager)
	
	# Remove from active events
	active_events.erase(event_id)

func end_event(event_id: String) -> void:
	if not active_events.has(event_id):
		DebugLogger.warning(module_name, "Cannot end inactive event: " + event_id)
		return
		
	var event = active_events[event_id]
	
	DebugLogger.debug(module_name, "Ending event: " + event_id)
	
	# End the event
	event.end_event(state_manager)
	
	# Remove from active events
	active_events.erase(event_id)
	
	event_ended.emit(event_id)

# Check if an event is currently active
func is_event_active(event_id: String) -> bool:
	return active_events.has(event_id)

# Get all active event nodes
func get_active_events() -> Array[BaseEvent]:
	var events: Array[BaseEvent] = []
	for event in active_events.values():
		events.append(event)
	return events

func _on_day_reset() -> void:
	DebugLogger.info(module_name, "Day reset signal received - cancelling all active events")
	
	# End all active events
	var events_to_end = active_events.keys().duplicate()
	for event_id in events_to_end:
		DebugLogger.debug(module_name, "Ending event due to day reset: " + event_id)
		end_event(event_id)
	
	# Clear available event IDs
	available_event_ids.clear()
	
	DebugLogger.info(module_name, "All events cancelled for day reset")
