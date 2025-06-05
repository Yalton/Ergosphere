# GameManager.gd
extends Node

# Singleton reference
signal day_reset  # New signal for resetting things when starting a new day

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

func _ready() -> void:
	# Set up singleton
	
	# Register with debug logger
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
	
	# Initialize managers
	event_manager.initialize(state_manager)
	state_manager.initialize()
	task_manager.initialize(state_manager, event_manager)
	
	# Connect task manager signals
	task_manager.daily_tasks_completed.connect(_on_daily_tasks_completed)
	task_manager.emergency_task_failed.connect(_on_emergency_task_failed)
	
	DebugLogger.info(module_name, "GameManager initialized")
	
	# Start first day if enabled
	if auto_start_day:
		var start_timer = get_tree().create_timer(1.0)
		start_timer.timeout.connect(start_new_day)
	
	# Test events if enabled
	if auto_start_test:
		if test_power_outage_delay > 0:
			var power_timer = get_tree().create_timer(test_power_outage_delay)
			power_timer.timeout.connect(_test_power_outage)
		
		if test_oxygen_failure_delay > 0:
			var oxygen_timer = get_tree().create_timer(test_oxygen_failure_delay)
			oxygen_timer.timeout.connect(_test_oxygen_failure)
		
		if test_heatsink_failure_delay > 0:
			var heatsink_timer = get_tree().create_timer(test_heatsink_failure_delay)
			heatsink_timer.timeout.connect(_test_heatsink_failure)

func _test_power_outage() -> void:
	DebugLogger.debug(module_name, "Testing power outage")
	trigger_power_outage()

func _test_oxygen_failure() -> void:
	DebugLogger.debug(module_name, "Testing oxygen failure")
	trigger_oxygen_failure()

func _test_heatsink_failure() -> void:
	DebugLogger.debug(module_name, "Testing heatsink failure")
	trigger_heatsink_failure()

# Public API for triggering events
func trigger_power_outage() -> void:
	DebugLogger.debug(module_name, "Triggering power outage")
	event_manager.trigger_event("power_outage")
	Audio.play_sound(alarm_audio, true, 1.0,  -5.0,  "SFX")
	get_player().interaction_component.send_hint("", "WARNING: Power Outage has occured")
	# Power outage creates an emergency task
	task_manager.trigger_emergency_task("restore_power")

func trigger_oxygen_failure() -> void:
	DebugLogger.debug(module_name, "Triggering oxygen failure")
	event_manager.trigger_event("oxygen_failure")
	Audio.play_sound(alarm_audio, true, 1.0,  -5.0,  "SFX")
	get_player().interaction_component.send_hint("", "WARNING: Oxygen Generator has failed")
	# Oxygen failure creates an emergency task
	task_manager.trigger_emergency_task("replace_oxygen_filter")

func trigger_heatsink_failure() -> void:
	DebugLogger.debug(module_name, "Triggering heatsink failure")
	event_manager.trigger_event("heatsink_failure")
	Audio.play_sound(alarm_audio, true, 1.0,  -5.0,  "SFX")
	get_player().interaction_component.send_hint("", "WARNING: Engine Heatsink Failure")
	# Heatsink failure creates an emergency task
	task_manager.trigger_emergency_task("replace_heatsink")

func restore_power() -> void:
	DebugLogger.debug(module_name, "Restoring power")
	event_manager.reverse_event("power_outage")
	# Complete the emergency task
	task_manager.complete_task("restore_power")

# Called by interactables or other systems
func on_power_lever_interacted() -> void:
	restore_power()

# Called when a task is completed at an object
func on_task_completed_at_object(task_id: String) -> void:
	DebugLogger.debug(module_name, "Task completed at object: " + task_id)
	
	# Special handling for certain tasks
	match task_id:
		"restore_power":
			event_manager.reverse_event("power_outage")
		"replace_oxygen_filter":
			event_manager.end_event("oxygen_failure")
		"replace_heatsink":
			event_manager.end_event("heatsink_failure")

# Task system integration
func start_new_day() -> void:
	DebugLogger.info(module_name, "Starting new day")
	
	# Don't emit day_reset on day 1
	if task_manager.current_day > 1:
		DebugLogger.info(module_name, "Emitting day_reset signal")
		day_reset.emit()
	
	task_manager.start_new_day()

func _on_daily_tasks_completed() -> void:
	DebugLogger.info(module_name, "All daily tasks completed!")
	# You can add day transition logic here
	# For example: fade to black, show day complete screen, etc.

func _on_emergency_task_failed(task_id: String) -> void:
	DebugLogger.warning(module_name, "Emergency task failed: " + task_id)
	# Handle failure consequences
	match task_id:
		"restore_power":
			# Maybe damage equipment or reduce morale
			pass
		"replace_oxygen_filter":
			# Maybe damage health
			pass
		"replace_heatsink":
			# Maybe cause explosion
			pass

# Get current game state
func is_power_on() -> bool:
	return state_manager.get_state("power") == "on"

# Helper methods for UI or other systems
func get_current_day() -> int:
	return task_manager.current_day

func get_todays_tasks() -> Array:
	return task_manager.get_current_tasks()

func get_active_emergency_tasks() -> Array:
	return task_manager.get_active_emergency_tasks()


func get_player() -> Player: 
	
	# Find player and show message
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		return player
	
	return null
