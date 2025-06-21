# EventHandler.gd
extends Node
class_name EventHandler

## Interface for handling specific event types
## Extend this class to create handlers for different events (power outage, oxygen failure, etc.)

@export var enable_debug: bool = true
var module_name: String = "EventHandler"

## Event IDs this handler can process
@export var handled_event_ids: Array[String] = []

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)

func can_handle_event(event_id: String) -> bool:
	## Check if this handler can process the given event
	return event_id in handled_event_ids

func execute_event(event_data: EventData, state_manager: StateManager) -> void:
	## Execute the event - override in subclasses
	DebugLogger.warning(module_name, "Base execute_event called for: %s" % event_data.event_id)
	_on_execute(event_data, state_manager)

func complete_event(event_data: EventData, state_manager: StateManager) -> void:
	## Called when event is completed/resolved - override in subclasses
	DebugLogger.debug(module_name, "Event completed: %s" % event_data.event_id)
	_on_complete(event_data, state_manager)

# Virtual methods for subclasses to override
func _on_execute(_event_data: EventData, _state_manager: StateManager) -> void:
	## Override this to implement event execution logic
	pass

func _on_complete(_event_data: EventData, _state_manager: StateManager) -> void:
	## Override this to implement event completion logic
	pass
