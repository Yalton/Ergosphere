# GameManager.gd - Updated with StorageManager
extends Node

signal day_reset
signal game_started

@export var enable_debug: bool = true
var module_name: String = "GameManager"

# Manager references
var event_manager: EventManager
var state_manager: StateManager
var task_manager: TaskManager
var storage_manager: StorageManager

# Test controls
@export var test_power_outage_delay: float = 5.0
@export var test_oxygen_failure_delay: float = 5.0
@export var test_heatsink_failure_delay: float = 5.0
@export var auto_start_test: bool = false
@export var auto_start_day: bool = true
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
	
	event_manager.initialize(state_manager)
	state_manager.initialize()
	task_manager.initialize(state_manager, event_manager)
	# StorageManager doesn't need initialization
	
	is_initialized = true
	
	DebugLogger.info(module_name, "All systems initialized and reset")
	
	if auto_start_day:
		CommonUtils.create_one_shot_timer(self, 1.0, start_new_day)
	
	if auto_start_test:
		_setup_test_events()
	
	game_started.emit()

func _setup_test_events() -> void:
	if test_power_outage_delay > 0:
		CommonUtils.create_one_shot_timer(self, test_power_outage_delay, _test_power_outage)
	
	if test_oxygen_failure_delay > 0:
		CommonUtils.create_one_shot_timer(self, test_oxygen_failure_delay, _test_oxygen_failure)
	
	if test_heatsink_failure_delay > 0:
		CommonUtils.create_one_shot_timer(self, test_heatsink_failure_delay, _test_heatsink_failure)

func _test_power_outage() -> void:
	DebugLogger.info(module_name, "TEST: Triggering power outage")
	if event_manager:
		event_manager.trigger_event("power_outage")

func _test_oxygen_failure() -> void:
	DebugLogger.info(module_name, "TEST: Triggering oxygen failure")
	if event_manager:
		event_manager.trigger_event("oxygen_failure")

func _test_heatsink_failure() -> void:
	DebugLogger.info(module_name, "TEST: Triggering heatsink failure")
	if event_manager:
		event_manager.trigger_event("heatsink_failure")

func start_new_day() -> void:
	if not is_initialized:
		DebugLogger.warning(module_name, "Cannot start day - game not initialized")
		return
	
	DebugLogger.info(module_name, "Starting new day")
	task_manager.start_new_day()

func reset_day() -> void:
	DebugLogger.info(module_name, "Resetting day")
	day_reset.emit()
	
	if task_manager:
		task_manager._reset_task_system()
	if event_manager:
		event_manager._reset_event_system()
	if state_manager:
		state_manager.initialize()
	
	# Give small delay then start new day
	CommonUtils.create_one_shot_timer(self, 0.5, start_new_day)

func _on_daily_tasks_completed() -> void:
	DebugLogger.info(module_name, "All daily tasks completed!")

func _on_emergency_task_failed(task_id: String) -> void:
	DebugLogger.warning(module_name, "Emergency task failed: " + task_id)
	
	if alarm_audio:
		Audio.play_sound(alarm_audio)

func _on_task_completed(task_id: String) -> void:
	# Award requisition for completed tasks
	var requisition_reward = _get_task_requisition_reward(task_id)
	if requisition_reward > 0:
		storage_manager.add_requisition(requisition_reward)
		DebugLogger.info(module_name, "Awarded " + str(requisition_reward) + " requisition for task: " + task_id)

## Get requisition reward for a task (can be customized per task)
func _get_task_requisition_reward(task_id: String) -> int:
	# Base reward for most tasks
	var base_reward = 50
	
	# Custom rewards for specific tasks
	match task_id:
		"emergency_task":
			return 100
		"sleep":
			return 25
		_:
			return base_reward

## Get storage manager reference
func get_storage_manager() -> StorageManager:
	return storage_manager
