# EventManager.gd
extends Node
class_name EventManager

## Main event system - handles all event types with tension/disruption scoring and cooldown management
## Completely separate from the task system - handles planned, unplanned, and hybrid events

signal event_triggered(event_data: EventData)
signal event_completed(event_data: EventData)

@export var enable_debug: bool = true
var module_name: String = "EventManager"

## Time between evaluation cycles in seconds
@export var evaluation_interval: float = 2.0

## Cooldown randomization factor (plus/minus this percentage of base cooldown)
@export var cooldown_variation: float = 0.5

## Event configurations
@export var event_configurations: Array[EventData] = []

# Current state
var active_cooldowns: Dictionary = {} # severity_type -> remaining_time
var scheduled_events: Array[ScheduledEvent] = []
var available_events: Array[EventData] = []
var current_day: int = 1
var insanity_level: float = 0.0
var task_completion_boost: float = 1.0
var task_completion_timer: float = 0.0

# Event handlers
var event_handlers: Array[EventHandler] = []

# References
var state_manager: StateManager

# Evaluation timer
var evaluation_timer: Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create evaluation timer
	evaluation_timer = Timer.new()
	evaluation_timer.wait_time = evaluation_interval
	evaluation_timer.timeout.connect(_evaluate_events)
	evaluation_timer.autostart = true
	add_child(evaluation_timer)
	
	DebugLogger.info(module_name, "EventManager initialized")

func _process(delta: float) -> void:
	# Update cooldowns
	_update_cooldowns(delta)
	
	# Update task completion boost timer
	if task_completion_timer > 0.0:
		task_completion_timer -= delta
		if task_completion_timer <= 0.0:
			task_completion_boost = 1.0
			DebugLogger.debug(module_name, "Task completion boost expired")

func initialize(_state_manager: StateManager) -> void:
	## Initialize the event system
	state_manager = _state_manager
	
	# Use provided configurations or empty array
	available_events = event_configurations.duplicate()
	scheduled_events.clear()
	active_cooldowns.clear()
	
	# Connect signals
	event_triggered.connect(_on_event_triggered)
	event_completed.connect(_on_event_completed)
	
	# Find all event handlers
	_discover_event_handlers()
	
	# Schedule planned events
	for event in available_events:
		if event.category == EventData.EventCategory.PLANNED:
			_schedule_planned_event(event)
	
	# Connect to task completion if available
	if GameManager and GameManager.task_manager:
		if not GameManager.task_manager.task_completed.is_connected(_on_task_completed):
			GameManager.task_manager.task_completed.connect(_on_task_completed)
	
	DebugLogger.info(module_name, "Initialized with %d events, %d handlers, %d planned events scheduled" % [available_events.size(), event_handlers.size(), scheduled_events.size()])

func start_new_day(day_number: int) -> void:
	## Called when a new day starts - handles day transition
	DebugLogger.info(module_name, "Starting new day: %d" % day_number)
	
	# End all active events for day transition
	_end_all_active_events()
	
	# Update current day
	set_current_day(day_number)
	
	# Start grace period where no events can trigger
	_start_grace_period()
	
	DebugLogger.info(module_name, "Day %d started with 30s grace period" % day_number)

func _end_all_active_events() -> void:
	## End all currently active events for day transition
	if active_cooldowns.is_empty():
		return
	
	DebugLogger.info(module_name, "Ending all active events for day transition")
	
	# Clear all cooldowns (this effectively ends all active events)
	active_cooldowns.clear()
	
	# Emit completion signals for any events that were active
	# Note: In a more complex system, you might want to track which events were actually active
	# For now, we just clear the cooldowns which prevents new events from being blocked

func _start_grace_period() -> void:
	## Start 30-second grace period where no events can trigger
	evaluation_timer.stop()
	
	# Create grace period timer
	var grace_timer = Timer.new()
	grace_timer.wait_time = 30.0
	grace_timer.one_shot = true
	grace_timer.timeout.connect(_end_grace_period)
	add_child(grace_timer)
	grace_timer.start()
	
	DebugLogger.debug(module_name, "Grace period started - events disabled for 30s")

func _end_grace_period() -> void:
	## End grace period and resume normal event evaluation
	evaluation_timer.start()
	DebugLogger.debug(module_name, "Grace period ended - events enabled")

func set_current_day(day: int) -> void:
	current_day = day
	DebugLogger.debug(module_name, "Day set to: %d" % day)
	insanity_level = clamp(insanity_level, 0.0, 100.0)
	DebugLogger.debug(module_name, "Insanity level set to: %.1f" % insanity_level)

func force_trigger_event(event_id: String) -> void:
	## Force trigger an event bypassing all checks (for planned events and dev console)
	var event = _find_event_by_id(event_id)
	if not event:
		DebugLogger.error(module_name, "Cannot force trigger - event not found: %s" % event_id)
		return
	
	_trigger_event(event)
	DebugLogger.info(module_name, "Force triggered event: %s" % event_id)

func complete_event(event_id: String) -> void:
	## Mark an event as completed (called by external systems)
	var event_data = _find_event_by_id(event_id)
	if event_data:
		event_completed.emit(event_data)
		DebugLogger.debug(module_name, "Event marked as completed: %s" % event_id)
	else:
		DebugLogger.error(module_name, "Cannot complete unknown event: %s" % event_id)

func _evaluate_events() -> void:
	## Main evaluation loop - runs every few seconds to check if events should trigger
	if available_events.is_empty():
		return
	
	# Check scheduled events first
	_check_scheduled_events()
	
	# Evaluate unplanned and hybrid events
	for event in available_events:
		if event.category == EventData.EventCategory.PLANNED:
			continue
			
		if _can_event_trigger(event) and _should_event_trigger(event):
			_trigger_event(event)
			break # Only trigger one event per evaluation

func _check_scheduled_events() -> void:
	## Check if any scheduled planned events should trigger now
	var current_time = Time.get_unix_time_from_system()
	var events_to_remove: Array[ScheduledEvent] = []
	
	for scheduled in scheduled_events:
		if current_time >= scheduled.trigger_time:
			force_trigger_event(scheduled.event_id)
			events_to_remove.append(scheduled)
	
	# Remove triggered events
	for event in events_to_remove:
		scheduled_events.erase(event)

func _can_event_trigger(event: EventData) -> bool:
	## Check if event meets prerequisites and cooldown requirements
	
	# Check prerequisites
	if not _check_prerequisites(event):
		return false
	
	# Check cooldowns
	var cooldown_key = _get_cooldown_key(event.tension_score, event.disruption_score)
	if active_cooldowns.has(cooldown_key) and active_cooldowns[cooldown_key] > 0:
		return false
	
	return true

func _should_event_trigger(event: EventData) -> bool:
	## Calculate final chance and roll for trigger
	var base_chance = event.base_chance
	var final_chance = _calculate_modified_chance(base_chance)
	
	var roll = randf() * 100.0
	var triggered = roll <= final_chance
	
	DebugLogger.debug(module_name, "Event %s: base=%.1f%%, final=%.1f%%, roll=%.1f%%, trigger=%s" % [event.event_id, base_chance, final_chance, roll, str(triggered)])
	
	return triggered

func _calculate_modified_chance(base_chance: float) -> float:
	## Apply all modifiers to base chance
	var modified_chance = base_chance
	
	# Insanity modifier (increases chance)
	var insanity_modifier = 1.0 + (insanity_level / 100.0)
	modified_chance *= insanity_modifier
	
	# Task completion boost
	modified_chance *= task_completion_boost
	
	# Day progression modifier (10% increase per day after day 1)
	var day_modifier = 1.0 + ((current_day - 1) * 0.1)
	modified_chance *= day_modifier
	
	# Clamp to reasonable bounds
	modified_chance = clamp(modified_chance, 0.0, 95.0)
	
	return modified_chance

func _trigger_event(event: EventData) -> void:
	## Actually trigger the event and start cooldowns
	
	# Apply cooldowns
	_start_cooldowns(event)
	
	# Emit signal
	event_triggered.emit(event)
	
	DebugLogger.info(module_name, "Triggered event: %s (T:%d D:%d)" % [event.event_id, event.tension_score, event.disruption_score])

func _start_cooldowns(event: EventData) -> void:
	## Start cooldown timers based on event severity
	
	# Tension cooldown
	if event.tension_score > 0:
		var tension_cooldown = _calculate_modified_cooldown(event.tension_cooldown)
		var tension_key = "tension_%d" % event.tension_score
		active_cooldowns[tension_key] = tension_cooldown
		DebugLogger.debug(module_name, "Started tension cooldown: %s = %.1fs" % [tension_key, tension_cooldown])
	
	# Disruption cooldown
	if event.disruption_score > 0:
		var disruption_cooldown = _calculate_modified_cooldown(event.disruption_cooldown)
		var disruption_key = "disruption_%d" % event.disruption_score
		active_cooldowns[disruption_key] = disruption_cooldown
		DebugLogger.debug(module_name, "Started disruption cooldown: %s = %.1fs" % [disruption_key, disruption_cooldown])

func _calculate_modified_cooldown(base_cooldown: float) -> float:
	## Apply modifiers to cooldown time
	var modified_cooldown = base_cooldown
	
	# Insanity modifier (decreases cooldown)
	var insanity_modifier = 1.0 - (insanity_level / 200.0) # Max 50% reduction
	modified_cooldown *= insanity_modifier
	
	# Day progression modifier (10% decrease per day after day 1)
	var day_modifier = 1.0 - ((current_day - 1) * 0.1)
	modified_cooldown *= clamp(day_modifier, 0.1, 1.0) # Minimum 10% of original
	
	# Add randomization
	var variation = modified_cooldown * cooldown_variation
	var random_offset = randf_range(-variation, variation)
	modified_cooldown += random_offset
	
	# Ensure minimum cooldown
	modified_cooldown = max(modified_cooldown, 1.0)
	
	return modified_cooldown

func _update_cooldowns(delta: float) -> void:
	## Update all active cooldowns
	var keys_to_remove: Array[String] = []
	
	for key in active_cooldowns.keys():
		active_cooldowns[key] -= delta
		if active_cooldowns[key] <= 0:
			keys_to_remove.append(key)
	
	# Remove expired cooldowns
	for key in keys_to_remove:
		active_cooldowns.erase(key)
		DebugLogger.debug(module_name, "Cooldown expired: %s" % key)

func _check_prerequisites(event: EventData) -> bool:
	## Check if event prerequisites are met
	
	# Day requirement
	if event.min_day > 0 and current_day < event.min_day:
		return false
	
	if event.max_day > 0 and current_day > event.max_day:
		return false
	
	return true

func _schedule_planned_event(event: EventData) -> void:
	## Schedule a planned event for execution
	if event.scheduled_day <= 0:
		DebugLogger.error(module_name, "Planned event %s has invalid scheduled_day: %d" % [event.event_id, event.scheduled_day])
		return
	
	var scheduled = ScheduledEvent.new()
	scheduled.event_id = event.event_id
	scheduled.scheduled_day = event.scheduled_day
	scheduled.trigger_time = _calculate_trigger_time(event.scheduled_day, event.scheduled_time_hours)
	
	scheduled_events.append(scheduled)
	DebugLogger.debug(module_name, "Scheduled planned event: %s for day %d" % [event.event_id, event.scheduled_day])

func _calculate_trigger_time(day: int, time_hours: float) -> float:
	## Calculate unix timestamp for when event should trigger
	# This is simplified - in real game you'd calculate based on game start time + day progression
	return Time.get_unix_time_from_system() + (day * 24 * 3600) + (time_hours * 3600)

func _find_event_by_id(event_id: String) -> EventData:
	## Find event by ID
	for event in available_events:
		if event.event_id == event_id:
			return event
	return null

func _get_cooldown_key(tension: int, disruption: int) -> String:
	## Generate cooldown key for tension/disruption level
	if tension > disruption:
		return "tension_%d" % tension
	else:
		return "disruption_%d" % disruption

func _discover_event_handlers() -> void:
	## Automatically find all EventHandler nodes in the scene tree
	event_handlers.clear()
	
	# Search recursively for EventHandler nodes
	_find_handlers_recursive(get_tree().root)
	
	DebugLogger.debug(module_name, "Discovered %d event handlers" % event_handlers.size())

func _find_handlers_recursive(node: Node) -> void:
	## Recursively search for EventHandler nodes
	if node is EventHandler:
		event_handlers.append(node as EventHandler)
		DebugLogger.debug(module_name, "Registered handler: %s for events: %s" % [node.name, str(node.handled_event_ids)])
	
	for child in node.get_children():
		_find_handlers_recursive(child)

func _find_handler_for_event(event_id: String) -> EventHandler:
	## Find the appropriate handler for an event ID
	for handler in event_handlers:
		if handler.can_handle_event(event_id):
			return handler
	return null

## Legacy Support
func trigger_event(event_id: String) -> void:
	force_trigger_event(event_id)
	
func _on_event_triggered(event_data: EventData) -> void:
	## Handle when an event is triggered
	DebugLogger.info(module_name, "Event triggered: %s" % event_data.event_id)
	
	# Find handler for this event
	var handler = _find_handler_for_event(event_data.event_id)
	if handler:
		handler.execute_event(event_data, state_manager)
		DebugLogger.debug(module_name, "Event %s handled by: %s" % [event_data.event_id, handler.name])
	else:
		DebugLogger.warning(module_name, "No handler found for event: %s" % event_data.event_id)

func _on_event_completed(event_data: EventData) -> void:
	## Handle when an event is completed
	DebugLogger.info(module_name, "Event completed: %s" % event_data.event_id)
	
	# Find handler for this event
	var handler = _find_handler_for_event(event_data.event_id)
	if handler:
		handler.complete_event(event_data, state_manager)
		DebugLogger.debug(module_name, "Event completion %s handled by: %s" % [event_data.event_id, handler.name])

func _on_task_completed(task_id: String) -> void:
	## Handle task completion - applies chance boost
	DebugLogger.debug(module_name, "Task completed: %s - applying event chance boost" % task_id)
	task_completion_boost = 2.0
	task_completion_timer = 5.0

# Inner class for scheduled events
class ScheduledEvent:
	var event_id: String
	var scheduled_day: int
	var trigger_time: float
