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
	
	# Find managers using CommonUtils
	event_manager = CommonUtils.safe_get_node(self, "EventManager") as EventManager
	state_manager = CommonUtils.safe_get_node(self, "StateManager") as StateManager
	task_manager = CommonUtils.safe_get_node(self, "TaskManager") as TaskManager
	storage_manager = CommonUtils.safe_get_node(self, "StorageManager") as StorageManager
	
	# Validate managers
	if not CommonUtils.ensure_valid(event_manager, module_name, "EventManager"):
		return
	if not CommonUtils.ensure_valid(state_manager, module_name, "StateManager"):
		return
	if not CommonUtils.ensure_valid(task_manager, module_name, "TaskManager"):
		return
	if not CommonUtils.ensure_valid(storage_manager, module_name, "StorageManager"):
		return
	
	# Connect task manager signals using CommonUtils
	CommonUtils.connect_signal_safe(task_manager, "daily_tasks_completed", self, "_on_daily_tasks_completed")
	CommonUtils.connect_signal_safe(task_manager, "emergency_task_failed", self, "_on_emergency_task_failed")
	CommonUtils.connect_signal_safe(task_manager, "task_completed", self, "_on_task_completed")
	
	DebugLogger.info(module_name, "GameManager ready, waiting for game start")
	
	if auto_start_day:
		var timer = Timer.new()
		timer.wait_time = 0.1
		timer.one_shot = true
		timer.timeout.connect(func(): 
			if not is_initialized:
				DebugLogger.info(module_name, "Auto-starting game")
				start_game()
		)
		add_child(timer)
		timer.start()

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
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.one_shot = true
		timer.timeout.connect(start_new_day)
		add_child(timer)
		timer.start()
	
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
	DebugLogger.info(module_name, "Ending day %d" % current_day)
	
	# Could add end-of-day summary, scoring, etc. here
	
	# Reset for next day
	day_reset.emit()
	
	# Start next day after a delay
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(start_new_day)
	add_child(timer)
	timer.start()

func _on_daily_tasks_completed() -> void:
	DebugLogger.info(module_name, "All daily tasks completed!")
	CommonUtils.set_game_state(CommonUtils.STATE_ALL_DAILY_TASKS_COMPLETE, true)
	
	# Could trigger end of day or special events here

func _on_emergency_task_failed(task_id: String) -> void:
	DebugLogger.warning(module_name, "Emergency task failed: " + task_id)
	
	# Play alarm if configured
	if alarm_audio and Audio:
		Audio.play_sound(alarm_audio, false, 1.0, 0.8)
	
	# Could trigger game over or penalty here

func _on_task_completed(task: BaseTask) -> void:
	DebugLogger.debug(module_name, "Task completed: " + task.task_name)
	
	# Update event manager with task completion
	if event_manager:
		event_manager.on_task_completed()

func get_current_day() -> int:
	return current_day

func is_game_initialized() -> bool:
	return is_initialized
