# GameManager.gd
extends Node

signal day_reset
signal game_started

@export var enable_debug: bool = true
var module_name: String = "GameManager"

# Manager references
var event_manager: EventManager
var state_manager: StateManager
var task_manager: TaskManager

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
	
	if not event_manager:
		DebugLogger.error(module_name, "EventManager not found!")
		return
		
	if not state_manager:
		DebugLogger.error(module_name, "StateManager not found!")
		return
		
	if not task_manager:
		DebugLogger.error(module_name, "TaskManager not found!")
		return
	
	# Connect task manager signals using CommonUtils
	CommonUtils.connect_signal_safe(task_manager, "daily_tasks_completed", self, "_on_daily_tasks_completed")
	CommonUtils.connect_signal_safe(task_manager, "emergency_task_failed", self, "_on_emergency_task_failed")
	
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
	DebugLogger.debug(module_name, "Testing power outage")
	trigger_power_outage()

func _test_oxygen_failure() -> void:
	DebugLogger.debug(module_name, "Testing oxygen failure")
	trigger_oxygen_failure()

func _test_heatsink_failure() -> void:
	DebugLogger.debug(module_name, "Testing heatsink failure")
	trigger_heatsink_failure()

func trigger_power_outage() -> void:
	if not is_initialized:
		DebugLogger.warning(module_name, "Cannot trigger events before game start")
		return
		
	DebugLogger.debug(module_name, "Triggering power outage")
	event_manager.trigger_event("power_outage")
	Audio.play_sound(alarm_audio, true, 1.0,  -5.0,  "SFX")
	
	# Use CommonUtils to get player and send message
	var player = CommonUtils.get_player()
	if player and player.interaction_component:
		player.interaction_component.send_hint("", "WARNING: Power Outage has occured")
	
	task_manager.trigger_emergency_task("restore_power")

func trigger_oxygen_failure() -> void:
	if not is_initialized:
		DebugLogger.warning(module_name, "Cannot trigger events before game start")
		return
		
	DebugLogger.debug(module_name, "Triggering oxygen failure")
	event_manager.trigger_event("oxygen_failure")
	Audio.play_sound(alarm_audio, true, 1.0,  -5.0,  "SFX")
	
	var player = CommonUtils.get_player()
	if player and player.interaction_component:
		player.interaction_component.send_hint("", "WARNING: Oxygen Generator has failed")
		
	task_manager.trigger_emergency_task("replace_oxygen_filter")

func trigger_heatsink_failure() -> void:
	if not is_initialized:
		DebugLogger.warning(module_name, "Cannot trigger events before game start")
		return
		
	DebugLogger.debug(module_name, "Triggering heatsink failure")
	event_manager.trigger_event("heatsink_failure")
	Audio.play_sound(alarm_audio, true, 1.0,  -5.0,  "SFX")
	
	var player = CommonUtils.get_player()
	if player and player.interaction_component:
		player.interaction_component.send_hint("", "WARNING: Engine Heatsink Failure")
		
	task_manager.trigger_emergency_task("replace_heatsink")

func restore_power() -> void:
	DebugLogger.debug(module_name, "Restoring power")
	event_manager.reverse_event("power_outage")
	task_manager.complete_task("restore_power")

func on_power_lever_interacted() -> void:
	restore_power()

func on_task_completed_at_object(task_id: String) -> void:
	DebugLogger.debug(module_name, "Task completed at object: " + task_id)
	
	match task_id:
		"restore_power":
			event_manager.reverse_event("power_outage")
		"replace_oxygen_filter":
			event_manager.end_event("oxygen_failure")
		"replace_heatsink":
			event_manager.end_event("heatsink_failure")

func start_new_day() -> void:
	DebugLogger.info(module_name, "Starting new day")
	
	if task_manager.current_day > 1:
		DebugLogger.info(module_name, "Emitting day_reset signal")
		day_reset.emit()
	
	task_manager.start_new_day()

func _on_daily_tasks_completed() -> void:
	DebugLogger.info(module_name, "All daily tasks completed!")

func _on_emergency_task_failed(task_id: String) -> void:
	DebugLogger.warning(module_name, "Emergency task failed: " + task_id)
	# Handle failure consequences based on task_id

# Simplified helper methods using CommonUtils
func is_power_on() -> bool:
	return CommonUtils.check_game_state("power", "on")

func get_current_day() -> int:
	return task_manager.current_day if task_manager else 0

func get_todays_tasks() -> Array:
	return task_manager.get_current_tasks() if task_manager else []

func get_active_emergency_tasks() -> Array:
	return task_manager.get_active_emergency_tasks() if task_manager else []

# Remove get_player() - use CommonUtils.get_player() instead
