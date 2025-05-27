# EventManager.gd
extends Node
class_name EventManager

@export var enable_debug: bool = true
var module_name: String = "EventManager"

# Dictionary to track active events
var active_events: Dictionary = {}
var state_manager: StateManager

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)

func initialize(_state_manager: StateManager) -> void:
	state_manager = _state_manager
	
	# Find all event nodes
	for child in get_children():
		if child is BaseEvent:
			DebugLogger.debug(module_name, "Found event: " + child.name)
	
	DebugLogger.info(module_name, "EventManager initialized with " + str(get_child_count()) + " events")

func trigger_event(event_id: String) -> void:
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

# Check if an event is currently active
func is_event_active(event_id: String) -> bool:
	return active_events.has(event_id)
