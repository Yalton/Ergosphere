extends Node
class_name EventManager

## Emitted when an event is successfully triggered
signal event_triggered(event_id: String)

## Emitted when an event ends
signal event_ended(event_id: String)

@export var enable_debug: bool = true
var module_name: String = "EventManager"

@export_group("Event Configuration")
## All available events in the game
@export var event_resources: Array[EventData] = []

## Base point accumulation per second (multiplied by current day)
@export var base_point_rate: float = 1.0

## Safety check - if no event has triggered in this many seconds, force an evaluation
@export var max_seconds_without_evaluation: float = 40.0

@export_group("Evaluation Delays")
## Short delay range (seconds)
@export var short_delay_min: float = 1.0
@export var short_delay_max: float = 5.0

## Medium delay range (seconds)
@export var medium_delay_min: float = 4.0
@export var medium_delay_max: float = 15.0

## Long delay range (seconds)
@export var long_delay_min: float = 14.0
@export var long_delay_max: float = 30.0

# Internal state
var current_points: float = 0.0
var current_disruption: int = 0
var active_events: Dictionary = {} # event_id -> {resource: EventData, handler: EventHandler}
var event_occurrences: Dictionary = {} # event_id -> int
var event_cooldowns: Dictionary = {} # event_id -> float (time remaining)

# Evaluation timing
var time_since_last_evaluation: float = 0.0
var next_evaluation_time: float = 0.0
var last_delay_type: String = "medium"

# References
var state_manager: StateManager

# Game state tracking
var is_initialized: bool = false
var game_is_running: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect to GameManager's day_ended signal
	if GameManager:
		GameManager.day_ended.connect(_on_day_ended)

func initialize(_state_manager: StateManager) -> void:
	state_manager = _state_manager
	
	# Reset everything
	_reset_event_system()
	
	# Schedule first evaluation
	_schedule_next_evaluation()
	
	is_initialized = true
	
	DebugLogger.info(module_name, "EventManager initialized with " + str(event_resources.size()) + " events")

func reset() -> void:
	"""Reset the event system - called when returning to menu"""
	_reset_event_system()
	is_initialized = false
	game_is_running = false
	DebugLogger.info(module_name, "EventManager reset")

func start() -> void:
	"""Start the event system - called when game actually starts"""
	if not is_initialized:
		DebugLogger.error(module_name, "Cannot start - not initialized")
		return
	
	game_is_running = true
	DebugLogger.info(module_name, "Event system started")

func stop() -> void:
	"""Stop the event system - called when returning to menu"""
	game_is_running = false
	DebugLogger.info(module_name, "Event system stopped")

func _reset_event_system() -> void:
	# End all active events
	for event_id in active_events.keys():
		var event_data = active_events[event_id]
		if event_data.handler and is_instance_valid(event_data.handler):
			event_data.handler.end()
			# DON'T delete handlers - they're reusable!
	
	# Clear all state
	active_events.clear()
	event_occurrences.clear()
	event_cooldowns.clear()
	current_points = 0.0
	current_disruption = 0
	time_since_last_evaluation = 0.0
	
	DebugLogger.debug(module_name, "Event system reset")

func _process(delta: float) -> void:
	# Don't process if not initialized or game not running
	if not is_initialized or not game_is_running:
		return
		
	if not GameManager or not GameManager.is_game_running():
		return
	
	# Accumulate points based on day and sanity
	var current_day = GameManager.get_current_day()
	var point_gain = base_point_rate * current_day * delta
	
	# Apply sanity modifier (placeholder - need to get actual sanity)
	var sanity_modifier = 1.0 # This should come from player stats
	point_gain *= sanity_modifier
	
	current_points += point_gain
	
	# Update cooldowns
	for event_id in event_cooldowns.keys():
		event_cooldowns[event_id] -= delta
		if event_cooldowns[event_id] <= 0:
			event_cooldowns.erase(event_id)
	
	# Check for evaluation
	time_since_last_evaluation += delta
	
	if time_since_last_evaluation >= next_evaluation_time:
		_evaluate_and_trigger_event()
	elif time_since_last_evaluation >= max_seconds_without_evaluation:
		DebugLogger.warning(module_name, "Safety check triggered - forcing evaluation")
		_evaluate_and_trigger_event()

func _evaluate_and_trigger_event() -> void:
	# Don't evaluate if game not running
	if not game_is_running:
		return
		
	DebugLogger.debug(module_name, "Evaluating events. Points: " + str(current_points) + ", Disruption: " + str(current_disruption) + "%")
	
	# Build list of valid events
	var valid_events: Array[EventData] = []
	
	for event in event_resources:
		if _can_trigger_event(event):
			valid_events.append(event)
	
	if valid_events.is_empty():
		DebugLogger.debug(module_name, "No valid events to trigger")
		_schedule_next_evaluation()
		return
	
	# Sort by cost (highest first)
	valid_events.sort_custom(func(a, b): return a.get_modified_cost(event_occurrences.get(a.id, 0)) > b.get_modified_cost(event_occurrences.get(b.id, 0)))
	
	# Try to trigger the most expensive event we can afford
	var triggered = false
	for event in valid_events:
		var modified_cost = event.get_modified_cost(event_occurrences.get(event.id, 0))
		
		if current_points >= modified_cost:
			var result = _try_trigger_event(event, false)
			if result.success:
				current_points -= modified_cost
				triggered = true
				DebugLogger.info(module_name, "Triggered event: " + event.name + " (cost: " + str(modified_cost) + ")" + " points remaining " + str(current_points))
				break
			else:
				DebugLogger.warning(module_name, "Event failed: " + event.name + " - " + result.message)
	
	if not triggered:
		DebugLogger.debug(module_name, "Could not trigger any event")
	
	# Schedule next evaluation
	_schedule_next_evaluation()

func _can_trigger_event(event: EventData) -> bool:
	# Check if already active
	if active_events.has(event.id):
		return false
	
	# Check cooldown
	if event_cooldowns.has(event.id):
		return false
	
	# Check day requirement
	if GameManager.get_current_day() < event.min_day:
		return false
	
	# Check disruption cap
	if current_disruption + event.disruption_percentage > 100:
		return false
	
	# Check for conflicts with active events
	for active_id in active_events:
		var active_event = active_events[active_id].resource
		if event.conflicts_with(active_event):
			return false
	
	return true

func start_new_day(day_number: int) -> void:
	"""Handle day transition - for compatibility with existing systems"""
	DebugLogger.info(module_name, "Starting new day: %d" % day_number)
	
	# Reset event system for new day
	#_reset_event_system()
	
	# Reset points to a base amount that scales with day
	current_points = 0
	
	# Clear all cooldowns for fresh start
	event_cooldowns.clear()
	
	# Normalize occurrences at day start
	_normalize_occurrences()
	
	# Schedule first evaluation after a brief grace period
	next_evaluation_time = 30.0  # 30 second grace period
	time_since_last_evaluation = 0.0
	
	DebugLogger.info(module_name, "Day %d started - Starting points: %.1f, Grace period: 30s" % [day_number, current_points])

func start_day(day_number: int) -> void:
	"""Alias for start_new_day to match GameManager's expectations"""
	start_new_day(day_number)

func end_day() -> void:
	"""Handle end of day"""
	var current_day = GameManager.get_current_day()
	DebugLogger.info(module_name, "Day %d ended - disruption: %d%%" % [current_day, current_disruption])
	
func _try_trigger_event(event: EventData, _forced: bool) -> Dictionary:
	# Find handler that handles this event ID
	var handler: EventHandler = null
	
	for child in get_children():
		if child is EventHandler and child.handles_event(event.id):
			handler = child
			break
	
	if not handler:
		return {"success": false, "message": "No handler found for event ID: " + event.id}
	
	# Set the event data on the handler
	handler.event_data = event
	
	if !_forced: 
		# Check if handler says it can execute and get status
		var can_execute_result = handler.can_execute_with_status()
		if not can_execute_result.success:
			# DON'T DELETE THE HANDLER! It should be reusable
			return can_execute_result
	
	# Try to execute and get status
	var execute_result = handler.execute_with_status()
	if not execute_result.success:
		# DON'T DELETE THE HANDLER! It should be reusable
		return execute_result
	
	# Success! Track the event
	active_events[event.id] = {
		"resource": event,
		"handler": handler
	}
	
	# Update tracking
	current_disruption += event.disruption_percentage
	event_occurrences[event.id] = event_occurrences.get(event.id, 0) + 1
	
	# Connect to completion signal
	handler.event_completed.connect(_on_event_completed.bind(event.id))
	
	event_triggered.emit(event.id)
	
	return {"success": true, "message": "OK"}

func _on_event_completed(event_id: String) -> void:
	if not active_events.has(event_id):
		return
	
	var event_data = active_events[event_id]
	var event = event_data.resource
	
	# Remove from active
	active_events.erase(event_id)
	
	# Update disruption
	current_disruption -= event.disruption_percentage
	current_disruption = max(0, current_disruption)
	
	# Start cooldown
	event_cooldowns[event_id] = event.cooldown
	
	# DON'T DELETE THE HANDLER! It should be reusable
	
	event_ended.emit(event_id)
	
	DebugLogger.info(module_name, "Event completed: " + event.name)

func _schedule_next_evaluation() -> void:
	# Reset time
	time_since_last_evaluation = 0.0
	
	# Choose delay based on disruption
	var delay_type: String
	var delay_time: float
	
	if current_disruption > 70:
		delay_type = "long"
		delay_time = randf_range(long_delay_min, long_delay_max)
	elif current_disruption > 30:
		delay_type = "medium"
		delay_time = randf_range(medium_delay_min, medium_delay_max)
	else:
		delay_type = "short"
		delay_time = randf_range(short_delay_min, short_delay_max)
	
	# Apply weighting based on last delay type
	if delay_type == last_delay_type:
		# 10% less likely to repeat
		if randf() < 0.1:
			# Switch to a different type
			var types = ["short", "medium", "long"]
			types.erase(delay_type)
			delay_type = types[randi() % types.size()]
			
			# Recalculate delay time
			match delay_type:
				"short":
					delay_time = randf_range(short_delay_min, short_delay_max)
				"medium":
					delay_time = randf_range(medium_delay_min, medium_delay_max)
				"long":
					delay_time = randf_range(long_delay_min, long_delay_max)
	
	next_evaluation_time = delay_time
	last_delay_type = delay_type
	
	DebugLogger.debug(module_name, "Next evaluation in " + str(delay_time) + " seconds (" + delay_type + " delay)")

func _on_day_ended(day_number: int) -> void:
	DebugLogger.info(module_name, "Day %d ended - ending all events" % day_number)
	
	# End all active events
	var events_to_end = active_events.keys().duplicate()
	for event_id in events_to_end:
		end_event(event_id)
	
	# Normalize occurrences
	_normalize_occurrences()

func _normalize_occurrences() -> void:
	# Find minimum occurrences
	var min_occurrences = 999999
	for event_id in event_occurrences:
		min_occurrences = min(min_occurrences, event_occurrences[event_id])
	
	# Subtract minimum from all
	if min_occurrences > 0:
		for event_id in event_occurrences:
			event_occurrences[event_id] -= min_occurrences
		
		DebugLogger.debug(module_name, "Normalized occurrences by subtracting " + str(min_occurrences))

# Public API to maintain compatibility
func trigger_event(event_id: String) -> void:
	"""Force trigger an event by ID (for testing/story moments)"""
	var event_data: EventData = null
	
	for event in event_resources:
		if event.id == event_id:
			event_data = event
			break
	
	if not event_data:
		DebugLogger.error(module_name, "Event not found: " + event_id)
		return
	
	# Force trigger - if event is already active, end it first
	if active_events.has(event_id):
		DebugLogger.info(module_name, "Force trigger: ending existing instance of " + event_id)
		end_event(event_id)
	
	# Find handler and try to execute
	var result = _try_trigger_event(event_data, true)
	if not result.success:
		DebugLogger.warning(module_name, "Cannot force trigger event: " + event_id + " - " + result.message)
	else:
		DebugLogger.info(module_name, "Force triggered event: " + event_id)

func end_event(event_id: String) -> void:
	"""End an active event"""
	if not active_events.has(event_id):
		DebugLogger.warning(module_name, "Cannot end inactive event: " + event_id)
		return
	
	var event_data = active_events[event_id]
	if event_data.handler and is_instance_valid(event_data.handler):
		event_data.handler.end()

func reverse_event(event_id: String) -> void:
	"""For backwards compatibility - just calls end_event"""
	DebugLogger.debug(module_name, "reverse_event called - redirecting to end_event")
	end_event(event_id)

func is_event_active(event_id: String) -> bool:
	"""Check if an event is currently active"""
	return active_events.has(event_id)

func get_active_events() -> Array[EventHandler]:
	"""For backwards compatibility - returns empty array"""
	DebugLogger.warning(module_name, "get_active_events called but returns empty - use event IDs instead")
	return []

# Debug helpers

func get_debug_info() -> Dictionary:
	return {
		"points": current_points,
		"disruption": current_disruption,
		"active_events": active_events.keys(),
		"cooldowns": event_cooldowns,
		"occurrences": event_occurrences,
		"next_evaluation": next_evaluation_time - time_since_last_evaluation,
		"game_running": game_is_running,
		"initialized": is_initialized
	}
