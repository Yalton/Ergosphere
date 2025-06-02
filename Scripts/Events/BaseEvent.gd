# BaseEvent.gd
extends Node
class_name BaseEvent

@export var enable_debug: bool = true
var module_name: String = "BaseEvent"

# Event properties
@export var event_name: String = "unnamed_event"
@export var event_description: String = ""

# State of the event
var is_active: bool = false
var event_started_at: float = 0.0

func _ready() -> void:
	module_name = event_name
	DebugLogger.register_module(module_name, enable_debug)

# Called when the event starts
func start_event(state_manager: StateManager) -> void:
	if is_active:
		DebugLogger.warning(module_name, "Event already active")
		return
		
	is_active = true
	event_started_at = Time.get_ticks_msec() / 1000.0
	
	DebugLogger.debug(module_name, "Starting event: " + event_name)
	
	_on_start(state_manager)

# Called when the event is reversed (used for reversible events like power)
func reverse_event(state_manager: StateManager) -> void:
	if not is_active:
		DebugLogger.warning(module_name, "Cannot reverse inactive event")
		return
		
	DebugLogger.debug(module_name, "Reversing event: " + event_name)
	
	_on_reverse(state_manager)
	
	is_active = false

# Called when the event ends normally
func end_event(state_manager: StateManager) -> void:
	if not is_active:
		DebugLogger.warning(module_name, "Event already inactive")
		return
		
	DebugLogger.debug(module_name, "Ending event: " + event_name)
	
	_on_end(state_manager)
	
	is_active = false

# Virtual methods to be overridden by specific events
func _on_start(_state_manager: StateManager) -> void:
	pass

func _on_reverse(state_manager: StateManager) -> void:
	# Default behavior is to call end
	_on_end(state_manager)

func _on_end(_state_manager: StateManager) -> void:
	pass

# Helper to get event duration
func get_duration() -> float:
	if not is_active:
		return 0.0
	return (Time.get_ticks_msec() / 1000.0) - event_started_at
