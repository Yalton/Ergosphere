# EventManager.gd
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
var available_event_ids: Array[String] = []

# Cached event nodes for performance
var event_nodes: Dictionary = {}  # event_id -> BaseEvent

# References
var state_manager: StateManager
var task_manager: TaskManager

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Cache all event nodes
	_cache_event_nodes()
	
	# Connect to GameManager's day_reset signal
	if GameManager:
		CommonUtils.connect_signal_safe(GameManager, "day_reset", self, "_on_day_reset")
		DebugLogger.debug(module_name, "Connected to day_reset signal")

func _cache_event_nodes() -> void:
	event_nodes.clear()
	for child in get_children():
		if child is BaseEvent:
			event_nodes[child.name] = child
			DebugLogger.debug(module_name, "Cached event: " + child.name)

func initialize(_state_manager: StateManager) -> void:
	state_manager = _state_manager
	
	_reset_event_system()
	
	if GameManager:
		task_manager = GameManager.task_manager
		if task_manager:
			CommonUtils.connect_signal_safe(task_manager, "task_completed", self, "_on_task_completed")
	
	DebugLogger.info(module_name, "EventManager initialized with " + str(event_nodes.size()) + " events")

func _reset_event_system() -> void:
	# End all active events properly
	for event_id in active_events.keys():
		var event = active_events[event_id]
		if event and is_instance_valid(event):
			event.is_active = false
			if event.has_method("_on_end"):
				event._on_end(state_manager)
	
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
		available_event_ids = event_nodes.keys()
		return
	
	# Set up available events from config
	available_event_ids = day_config.available_event_ids.duplicate()
	
	# Remove excluded events
	for excluded_id in day_config.excluded_events:
		available_event_ids.erase(excluded_id)
	
	# Trigger guaranteed events after a frame
	for event_id in day_config.guaranteed_events:
		if event_id in available_event_ids or day_config.guaranteed_events.has(event_id):
			call_deferred("trigger_event", event_id)
	
	DebugLogger.info(module_name, "Set up " + str(available_event_ids.size()) + " events for the day")

func _on_task_completed(task_id: String) -> void:
	# Check cached events for task triggers
	for event_id in event_nodes:
		var event = event_nodes[event_id]
		if event.has_method("check_task_trigger"):
			event.check_task_trigger(task_id)

func trigger_event(event_id: String) -> void:
	# Check availability
	if current_day_config and available_event_ids.size() > 0 and not event_id in available_event_ids:
		DebugLogger.warning(module_name, "Event not available today: " + event_id)
		return
	
	# Use cached event
	var event = event_nodes.get(event_id)
	
	if not event:
		DebugLogger.error(module_name, "Event not found: " + event_id)
		return
	
	if active_events.has(event_id):
		DebugLogger.warning(module_name, "Event already active: " + event_id)
		return
	
	DebugLogger.debug(module_name, "Triggering event: " + event_id)
	
	active_events[event_id] = event
	event.start_event(state_manager)
	event_triggered.emit(event_id)

func reverse_event(event_id: String) -> void:
	if not active_events.has(event_id):
		DebugLogger.warning(module_name, "Cannot reverse inactive event: " + event_id)
		return
	
	var event = active_events[event_id]
	
	DebugLogger.debug(module_name, "Reversing event: " + event_id)
	
	event.reverse_event(state_manager)
	active_events.erase(event_id)

func end_event(event_id: String) -> void:
	if not active_events.has(event_id):
		DebugLogger.warning(module_name, "Cannot end inactive event: " + event_id)
		return
		
	var event = active_events[event_id]
	
	DebugLogger.debug(module_name, "Ending event: " + event_id)
	
	event.end_event(state_manager)
	active_events.erase(event_id)
	event_ended.emit(event_id)

func is_event_active(event_id: String) -> bool:
	return active_events.has(event_id)

func get_active_events() -> Array[BaseEvent]:
	return active_events.values()

func _on_day_reset() -> void:
	DebugLogger.info(module_name, "Day reset signal received - cancelling all active events")
	
	# End all active events
	var events_to_end = active_events.keys().duplicate()
	for event_id in events_to_end:
		DebugLogger.debug(module_name, "Ending event due to day reset: " + event_id)
		end_event(event_id)
	
	available_event_ids.clear()
	
	DebugLogger.info(module_name, "All events cancelled for day reset")
