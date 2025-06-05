# BaseTask.gd
extends Resource
class_name BaseTask

# Task properties
## Unique identifier for this task. Used by TaskManager and TaskAwareComponent to reference this task.
@export var task_id: String = ""

## Display name shown to the player in the UI
@export var task_name: String = "Unnamed Task"

## Longer description of what the player needs to do. Can be shown as tooltip or help text.
@export var task_description: String = ""

## If true, this task is an emergency that blocks normal tasks and may have a time limit
@export var is_emergency: bool = false

## If true, this task is an emergency that blocks normal tasks and may have a time limit
@export var is_secret: bool = false

## Time limit in seconds for emergency tasks. 0 = no time limit. Task fails if timer expires.
@export var emergency_time_limit: float = 0.0

# Task dependencies
## List of task IDs that must be completed before this task becomes available
@export var dependent_on_tasks: Array[String] = []

## Game states that must match for this task to be available. Example: {"power": "on", "doors_unlocked": true}
@export var required_states: Dictionary = {}

## Game states that prevent this task from being available. Example: {"lockdown": true} blocks during lockdown
@export var blocked_by_states: Dictionary = {}

# Visibility conditions
## Conditions that must be met for this task to be revealed. Example: {"all_daily_tasks_complete": true}
## Task will be hidden until these conditions are met, then shown. Can become hidden again if conditions change.
@export var revealed_under: Dictionary = {}

## Delay in seconds before revealing task after conditions are met. Prevents flickering.
@export var reveal_delay: float = 1.0

# Associated game objects
## Groups that contain objects related to this task. Objects in these groups may show task-specific UI.
@export var related_object_groups: Array[String] = []

# Task state
var is_completed: bool = false
var is_available: bool = false
var is_revealed: bool = false  # Changed default to false
var time_remaining: float = 0.0
var assigned_day: int = -1

# Reveal system tracking
var reveal_timer: float = 0.0
var reveal_conditions_met: bool = false

# Debug
var enable_debug: bool = true
var module_name: String = "BaseTask"

func _init(p_id: String = "", p_name: String = "") -> void:
	task_id = p_id
	task_name = p_name
	module_name = "Task_" + p_name
	DebugLogger.register_module(module_name, enable_debug)

## Check if task should be revealed based on current state
func check_reveal_conditions(state_manager: StateManager, completed_tasks: Array[String]) -> bool:
	# If no reveal conditions, task is always revealed
	if revealed_under.is_empty():
		return true
	
	# Check all reveal conditions
	for condition_key in revealed_under:
		var required_value = revealed_under[condition_key]
		
		# Special handling for task completion checks
		if condition_key == "all_daily_tasks_complete":
			# This will be set by TaskManager
			if state_manager.get_state("all_daily_tasks_complete") != required_value:
				return false
		elif condition_key.begins_with("task_"):
			# Check if specific task is completed
			var check_task_id = condition_key.substr(5)  # Remove "task_" prefix
			if required_value and not check_task_id in completed_tasks:
				return false
			elif not required_value and check_task_id in completed_tasks:
				return false
		else:
			# Regular state check
			if state_manager.get_state(condition_key) != required_value:
				return false
	
	return true

## Update reveal state with delay system
func update_reveal_state(state_manager: StateManager, completed_tasks: Array[String], delta: float) -> void:
	var should_reveal = check_reveal_conditions(state_manager, completed_tasks)
	
	# Check blocking states - these force immediate hide
	for state_key in blocked_by_states:
		if state_manager.get_state(state_key) == blocked_by_states[state_key]:
			# Immediate hide if blocked
			if is_revealed:
				is_revealed = false
				reveal_timer = 0.0
				reveal_conditions_met = false
				DebugLogger.debug(module_name, "Task hidden due to blocking state: " + state_key)
			return
	
	# Handle reveal with delay
	if should_reveal and not is_revealed:
		if not reveal_conditions_met:
			reveal_conditions_met = true
			reveal_timer = 0.0
			DebugLogger.debug(module_name, "Reveal conditions met, starting timer")
		
		reveal_timer += delta
		if reveal_timer >= reveal_delay:
			is_revealed = check_reveal_conditions(state_manager, completed_tasks)
			DebugLogger.info(module_name, "Task revealed: " + task_name)
	elif not should_reveal and is_revealed:
		# Immediate hide when conditions no longer met
		is_revealed = false
		reveal_timer = 0.0
		reveal_conditions_met = false
		DebugLogger.debug(module_name, "Task hidden: conditions no longer met")
	elif not should_reveal:
		# Reset timer if conditions aren't met
		reveal_timer = 0.0
		reveal_conditions_met = false

func can_be_completed(state_manager: StateManager, completed_tasks: Array[String]) -> bool:
	# Task must be revealed to be completed
	if not is_revealed:
		DebugLogger.debug(module_name, "Cannot complete - task not revealed")
		return false
	
	# Check if dependencies are met
	for dep_task in dependent_on_tasks:
		if not dep_task in completed_tasks:
			DebugLogger.debug(module_name, "Cannot complete - missing dependency: " + dep_task)
			return false
	
	# Check required states
	for state_key in required_states:
		if state_manager.get_state(state_key) != required_states[state_key]:
			DebugLogger.debug(module_name, "Cannot complete - required state not met: " + state_key)
			return false
	
	# Check blocking states
	for state_key in blocked_by_states:
		if state_manager.get_state(state_key) == blocked_by_states[state_key]:
			DebugLogger.debug(module_name, "Cannot complete - blocked by state: " + state_key)
			return false
	
	return true

func complete() -> void:
	is_completed = true
	DebugLogger.info(module_name, "Task completed: " + task_name)

func reset() -> void:
	is_completed = false
	is_available = false
	is_revealed = false
	reveal_timer = 0.0
	reveal_conditions_met = false
	time_remaining = emergency_time_limit

func get_display_name() -> String:
	if is_emergency:
		return "[EMERGENCY] " + task_name
	return task_name
