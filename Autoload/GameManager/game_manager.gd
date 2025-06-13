# GameManager.gd
extends Node

signal day_reset
signal game_started

## Enable debug logging for the GameManager
@export var enable_debug: bool = true
var module_name: String = "GameManager"

# Manager references
var event_manager: EventManager
var state_manager: StateManager
var task_manager: TaskManager
var storage_manager: StorageManager

## Current day counter
var current_day: int = 0

## Automatically start the first day
@export var auto_start_day: bool = true
## Audio stream to play for alarms
@export var alarm_audio: AudioStream

var is_initialized: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find managers
	event_manager = get_node("EventManager")
	state_manager = get_node("StateManager")
	task_manager = get_node("TaskManager")
	storage_manager = get_node("StorageManager")
	
	if not event_manager:
		DebugLogger.error(module_name, "EventManager not found!")
		return
		
	if not state_manager:
		DebugLogger.error(module_name, "StateManager not found!")
		return
		
	if not task_manager:
		DebugLogger.error(module_name, "TaskManager not found!")
		return
	
	if not storage_manager:
		DebugLogger.error(module_name, "StorageManager not found!")
		return
	
	# Connect task manager signals using CommonUtils
	CommonUtils.connect_signal_safe(task_manager, "daily_tasks_completed", self, "_on_daily_tasks_completed")
	CommonUtils.connect_signal_safe(task_manager, "emergency_task_failed", self, "_on_emergency_task_failed")
	CommonUtils.connect_signal_safe(task_manager, "task_completed", self, "_on_task_completed")
	
	DebugLogger.info(module_name, "GameManager ready, waiting for game start")
	
	if auto_start_day:
		CommonUtils.create_one_shot_timer(self, 0.1, func(): 
			if not is_initialized:
				DebugLogger.info(module_name, "Auto-starting game")
				start_game()
		)

func start_game() -> void:
	DebugLogger.info(module_name, "Starting game - initializing all systems")
	
	# Initialize all systems
	state_manager.initialize()
	event_manager.initialize(state_manager)
	task_manager.initialize(state_manager)
	# StorageManager doesn't need initialization
	
	is_initialized = true
	
	DebugLogger.info(module_name, "All systems initialized")
	
	if auto_start_day:
		CommonUtils.create_one_shot_timer(self, 1.0, start_new_day)
	
	game_started.emit()

func start_new_day() -> void:
	if not is_initialized:
		DebugLogger.warning(module_name, "Cannot start day - game not initialized")
		return
	
	current_day += 1
	DebugLogger.info(module_name, "Starting day %d" % current_day)
	
	# Notify event manager of new day (handles grace period and event cleanup)
	event_manager.start_new_day(current_day)
	
	# Start new day in task manager
	task_manager.start_new_day()
	
	DebugLogger.info(module_name, "Day %d started successfully" % current_day)

func end_current_day() -> void:
	## Called when day should end (all tasks complete, time limit, etc.)
	if not is_initialized:
		DebugLogger.warning(module_name, "Cannot end day - game not initialized")
		return
	
	DebugLogger.info(module_name, "Ending day %d" % current_day)
	
	# Emit day reset signal for any systems that need to clean up
	day_reset.emit()
	
	# Brief pause before starting next day
	CommonUtils.create_one_shot_timer(self, 2.0, start_new_day)

func reset_day() -> void:
	## Reset current day (for debugging/testing)
	DebugLogger.info(module_name, "Resetting day %d" % current_day)
	day_reset.emit()
	
	# Reset systems
	CommonUtils.safe_call(task_manager, "_reset_task_system")
	CommonUtils.safe_call(event_manager, "_end_all_active_events")
	CommonUtils.safe_call(state_manager, "initialize")
	
	# Restart current day
	current_day -= 1  # Will be incremented in start_new_day
	CommonUtils.create_one_shot_timer(self, 0.5, start_new_day)

func force_trigger_event(event_id: String) -> void:
	## Force trigger an event (for dev console, scripted events)
	if not is_initialized:
		DebugLogger.warning(module_name, "Cannot trigger events before game start")
		return
		
	DebugLogger.debug(module_name, "Force triggering event: %s" % event_id)
	event_manager.force_trigger_event(event_id)

func complete_event(event_id: String) -> void:
	## Mark an event as completed
	if not is_initialized:
		DebugLogger.warning(module_name, "Cannot complete events before game start")
		return
		
	DebugLogger.debug(module_name, "Completing event: %s" % event_id)
	event_manager.complete_event(event_id)

func set_insanity_level(level: float) -> void:
	## Update insanity level in event manager
	if not is_initialized:
		return
		
	event_manager.set_insanity_level(level)

func get_current_day() -> int:
	return current_day

func get_todays_tasks() -> Array:
	return task_manager.get_current_tasks() if task_manager else []

func get_active_emergency_tasks() -> Array:
	return task_manager.get_active_emergency_tasks() if task_manager else []

# Task system event handlers
func _on_daily_tasks_completed() -> void:
	DebugLogger.info(module_name, "All daily tasks completed!")
	# Update state using CommonUtils constant
	state_manager.set_state(CommonUtils.STATE_ALL_DAILY_TASKS_COMPLETE, true)
	
	# Could automatically end day here if desired
	# end_current_day()

func _on_emergency_task_failed(task_id: String) -> void:
	DebugLogger.warning(module_name, "Emergency task failed: %s" % task_id)
	# Handle failure consequences - could trigger more events based on failure type

func _on_task_completed(task_id: String) -> void:
	DebugLogger.debug(module_name, "Task completed: %s" % task_id)
	
	# Special handling for certain tasks that resolve events
	match task_id:
		"restore_power":
			complete_event("power_outage")
		"replace_oxygen_filter":
			complete_event("oxygen_failure")
		"replace_heatsink":
			complete_event("heatsink_failure")

# Dev console integration
func get_debug_info() -> Dictionary:
	## Get debug information about all systems
	var info = {
		"initialized": is_initialized,
		"current_day": current_day,
		"active_tasks": 0,
		"active_emergency_tasks": 0,
		"event_system": {}
	}
	
	if task_manager:
		info["active_tasks"] = task_manager.get_current_tasks().size()
		info["active_emergency_tasks"] = task_manager.get_active_emergency_tasks().size()
	
	if event_manager:
		info["event_system"] = {
			"active_cooldowns": event_manager.active_cooldowns.size(),
			"available_events": event_manager.available_events.size(),
			"current_insanity": event_manager.insanity_level
		}
	
	return info
