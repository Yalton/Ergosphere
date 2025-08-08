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

## Maximum time an event can be active before being force-ended (in seconds)
@export var max_event_duration: float = 30.0

@export_group("Grace Periods")
## Grace period after day starts (seconds) - no events during this time
@export var day_start_grace_period: float = 30.0

## Extended grace period for day 1 (seconds)
@export var day_1_grace_period: float = 180.0

## Day 1 event frequency multiplier (0.2 = 5x less frequent)
@export var day_1_frequency_multiplier: float = 0.2

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
var active_events: Dictionary = {} # event_id -> {resource: EventData, handler: EventHandler, start_time: float}
var event_occurrences: Dictionary = {} # event_id -> int
var event_cooldowns: Dictionary = {} # event_id -> float (time remaining)

# Evaluation timing
var time_since_last_evaluation: float = 0.0
var next_evaluation_time: float = 0.0
var last_delay_type: String = "medium"
var last_successful_event_time: float = 0.0

# Grace period tracking
var grace_period_active: bool = false
var grace_period_remaining: float = 0.0
var events_frozen: bool = false

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
	grace_period_active = false
	grace_period_remaining = 0.0
	events_frozen = false
	DebugLogger.info(module_name, "EventManager reset")

func start() -> void:
	"""Start the event system - called when game actually starts"""
	if not is_initialized:
		DebugLogger.error(module_name, "Cannot start - not initialized")
		return
	
	game_is_running = true
	last_successful_event_time = Time.get_ticks_msec() / 1000.0
	DebugLogger.info(module_name, "Event system started")

func stop() -> void:
	"""Stop the event system - called when returning to menu"""
	game_is_running = false
	grace_period_active = false
	grace_period_remaining = 0.0
	events_frozen = false
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
	
	# Handle grace period countdown
	if grace_period_active:
		grace_period_remaining -= delta
		if grace_period_remaining <= 0:
			grace_period_active = false
			grace_period_remaining = 0.0
			DebugLogger.info(module_name, "Grace period ended - events can now occur")
	
	# Don't accumulate points or evaluate events if frozen or in grace period
	if events_frozen or grace_period_active:
		return
	
	# Accumulate points based on day and sanity
	var current_day = GameManager.get_current_day()
	var point_gain = base_point_rate * current_day * delta
	
	# Apply day 1 frequency reduction
	if current_day == 1:
		point_gain *= day_1_frequency_multiplier
	
	# Apply sanity modifier (placeholder - need to get actual sanity)
	var sanity_modifier = 1.0 # This should come from player stats
	point_gain *= sanity_modifier
	
	current_points += point_gain
	
	# Update cooldowns
	for event_id in event_cooldowns.keys():
		event_cooldowns[event_id] -= delta
		if event_cooldowns[event_id] <= 0:
			event_cooldowns.erase(event_id)
	
	# Check for stuck events and clean them up
	_check_stuck_events()
	
	# Check for evaluation
	time_since_last_evaluation += delta
	
	if time_since_last_evaluation >= next_evaluation_time:
		_evaluate_and_trigger_event()
	elif time_since_last_evaluation >= max_seconds_without_evaluation:
		DebugLogger.warning(module_name, "Safety check triggered - forcing evaluation")
		_evaluate_and_trigger_event()

func _check_stuck_events() -> void:
	"""Remove events that have been active for too long"""
	var current_time = Time.get_ticks_msec() / 1000.0
	var events_to_remove = []
	
	for event_id in active_events:
		var event_data = active_events[event_id]
		var duration = current_time - event_data.start_time
		
		if duration > max_event_duration:
			DebugLogger.warning(module_name, "Force ending stuck event: " + event_id + " (active for " + str(duration) + " seconds)")
			events_to_remove.append(event_id)
	
	for event_id in events_to_remove:
		_force_remove_event(event_id)

func _evaluate_and_trigger_event() -> void:
	# Don't evaluate if game not running, frozen, or in grace period
	if not game_is_running or events_frozen or grace_period_active:
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
				last_successful_event_time = Time.get_ticks_msec() / 1000.0
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
	
	# Don't check for conflicts with different event types - let different types run simultaneously
	# Only check conflicts within the same handler type
	for active_id in active_events:
		var active_event = active_events[active_id].resource
		# Only conflict if they're handled by the same type of handler
		if event.conflicts_with(active_event) and _same_handler_type(event.id, active_id):
			return false
	
	return true

func _same_handler_type(event_id1: String, event_id2: String) -> bool:
	"""Check if two events are handled by the same handler"""
	var handler1: EventHandler = null
	var handler2: EventHandler = null
	
	for child in get_children():
		if child is EventHandler:
			if child.handles_event(event_id1):
				handler1 = child
			if child.handles_event(event_id2):
				handler2 = child
	
	return handler1 == handler2

func start_new_day(day_number: int) -> void:
	"""Handle day transition - for compatibility with existing systems"""
	DebugLogger.info(module_name, "Starting new day: %d" % day_number)
	
	# Unfreeze events first
	events_frozen = false
	
	# Reset points to a base amount that scales with day
	current_points = 0
	
	# Clear all cooldowns for fresh start
	event_cooldowns.clear()
	
	# Normalize occurrences at day start
	_normalize_occurrences()
	
	# Set up grace period
	if day_number == 1:
		grace_period_remaining = day_1_grace_period
		DebugLogger.info(module_name, "Day 1 started - Extended grace period of %.1f seconds" % day_1_grace_period)
	else:
		grace_period_remaining = day_start_grace_period
		DebugLogger.info(module_name, "Day %d started - Grace period of %.1f seconds" % [day_number, day_start_grace_period])
	
	grace_period_active = true
	
	# Reset evaluation timing - will start after grace period
	time_since_last_evaluation = 0.0
	next_evaluation_time = grace_period_remaining + randf_range(5.0, 10.0)

func start_day(day_number: int) -> void:
	"""Alias for start_new_day to match GameManager's expectations"""
	start_new_day(day_number)

func end_day() -> void:
	"""Handle end of day"""
	var current_day = GameManager.get_current_day()
	DebugLogger.info(module_name, "Day %d ending - freezing events" % current_day)
	
	# Freeze events when day is ending
	events_frozen = true
	
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
	
	# Reset handler state if it thinks it's active but it's not tracked
	if handler.is_active and not _is_handler_tracked(handler):
		DebugLogger.warning(module_name, "Handler thinks it's active but not tracked, resetting: " + event.id)
		handler.is_active = false
	
	# Set the event data on the handler
	handler.event_data = event
	
	if !_forced: 
		# Check if handler says it can execute and get status
		var can_execute_result = handler.can_execute_with_status()
		if not can_execute_result.success:
			# DON'T DELETE THE HANDLER! It should be reusable
			# Also don't mark as active if it can't execute
			return can_execute_result
	
	# Try to execute and get status
	var execute_result = handler.execute_with_status()
	if not execute_result.success:
		# DON'T DELETE THE HANDLER! It should be reusable
		# Also don't mark as active if execution failed
		return execute_result
	
	# Success! Track the event
	active_events[event.id] = {
		"resource": event,
		"handler": handler,
		"start_time": Time.get_ticks_msec() / 1000.0
	}
	
	# Update tracking
	current_disruption += event.disruption_percentage
	event_occurrences[event.id] = event_occurrences.get(event.id, 0) + 1
	
	# Disconnect any existing connections first
	if handler.event_completed.is_connected(_on_event_completed):
		handler.event_completed.disconnect(_on_event_completed)
	
	# Connect to completion signal
	handler.event_completed.connect(_on_event_completed.bind(event.id), CONNECT_ONE_SHOT)
	
	event_triggered.emit(event.id)
	
	return {"success": true, "message": "OK"}

func _is_handler_tracked(handler: EventHandler) -> bool:
	"""Check if a handler is tracked in active_events"""
	for event_id in active_events:
		if active_events[event_id].handler == handler:
			return true
	return false

func _on_event_completed(event_id: String) -> void:
	if not active_events.has(event_id):
		return
	
	var event_data = active_events[event_id]
	var event = event_data.resource
	
	# Disconnect signal if still connected
	if event_data.handler and is_instance_valid(event_data.handler):
		if event_data.handler.event_completed.is_connected(_on_event_completed):
			event_data.handler.event_completed.disconnect(_on_event_completed)
	
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
	
	# If in grace period or frozen, delay evaluation
	if grace_period_active or events_frozen:
		next_evaluation_time = 999999.0  # Effectively never
		return
	
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
	
	# Apply day 1 frequency reduction to delays as well
	if GameManager and GameManager.get_current_day() == 1:
		delay_time = delay_time / day_1_frequency_multiplier
	
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
			
			# Re-apply day 1 modifier if needed
			if GameManager and GameManager.get_current_day() == 1:
				delay_time = delay_time / day_1_frequency_multiplier
	
	next_evaluation_time = delay_time
	last_delay_type = delay_type
	
	DebugLogger.debug(module_name, "Next evaluation in " + str(delay_time) + " seconds (" + delay_type + " delay)")

func _on_day_ended(day_number: int) -> void:
	DebugLogger.info(module_name, "Day %d ending - freezing events and ending all active events" % day_number)
	
	# Freeze events first
	events_frozen = true
	
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
	
	# ALWAYS force trigger - if event is already active, end it first
	if active_events.has(event_id):
		DebugLogger.info(module_name, "Force trigger: ending existing instance of " + event_id)
		end_event(event_id)
		# Small delay to let the event clean up
		await get_tree().create_timer(0.1).timeout
	
	# Find handler and try to execute - force=true bypasses all checks
	var result = _try_trigger_event(event_data, true)
	if not result.success:
		DebugLogger.warning(module_name, "Force trigger failed: " + event_id + " - " + result.message)
		# If force trigger failed, try to reset the handler and try again
		var handler: EventHandler = null
		for child in get_children():
			if child is EventHandler and child.handles_event(event_id):
				handler = child
				break
		
		if handler:
			DebugLogger.info(module_name, "Resetting handler and retrying force trigger: " + event_id)
			handler.is_active = false
			handler.end()  # Force end the handler
			await get_tree().create_timer(0.1).timeout
			result = _try_trigger_event(event_data, true)
			if result.success:
				DebugLogger.info(module_name, "Force triggered event after reset: " + event_id)
			else:
				DebugLogger.error(module_name, "Force trigger still failed after reset: " + event_id)
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
		# Also ensure the handler knows it's not active
		event_data.handler.is_active = false
	
	# If the event didn't remove itself via signal, do it manually
	if active_events.has(event_id):
		_on_event_completed(event_id)

func _force_remove_event(event_id: String) -> void:
	"""Force remove an event without calling handler.end() to avoid infinite loops"""
	if not active_events.has(event_id):
		return
	
	var event_data = active_events[event_id]
	var event = event_data.resource
	
	# Force the handler to inactive state
	if event_data.handler and is_instance_valid(event_data.handler):
		event_data.handler.is_active = false
		# Disconnect signal if connected
		if event_data.handler.event_completed.is_connected(_on_event_completed):
			event_data.handler.event_completed.disconnect(_on_event_completed)
	
	# Remove from active
	active_events.erase(event_id)
	
	# Update disruption
	current_disruption -= event.disruption_percentage
	current_disruption = max(0, current_disruption)
	
	# Start cooldown
	event_cooldowns[event_id] = event.cooldown
	
	event_ended.emit(event_id)
	
	DebugLogger.info(module_name, "Force removed stuck event: " + event_id)

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
		"initialized": is_initialized,
		"grace_period_active": grace_period_active,
		"grace_period_remaining": grace_period_remaining,
		"events_frozen": events_frozen,
		"current_day": GameManager.get_current_day() if GameManager else 0
	}
