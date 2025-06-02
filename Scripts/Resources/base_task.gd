# BaseTask.gd
extends Resource
class_name BaseTask

# Task properties
## Description 
@export var task_id: String = ""
@export var task_name: String = "Unnamed Task"
@export var task_description: String = ""
@export var is_emergency: bool = false
@export var emergency_time_limit: float = 0.0  # In seconds, 0 = no limit

# Task dependencies
@export var dependent_on_tasks: Array[String] = []  # Task IDs this depends on
@export var required_states: Dictionary = {}  # State requirements like {"power": "on"}
@export var blocked_by_states: Dictionary = {}  # States that block this task {"lockdown": true}

# Associated game objects
@export var related_object_groups: Array[String] = []  # Groups that contain objects for this task

# Task state
var is_completed: bool = false
var is_available: bool = false
var time_remaining: float = 0.0
var assigned_day: int = -1

# Debug
var enable_debug: bool = true
var module_name: String = "BaseTask"

func _init(p_id: String = "", p_name: String = "") -> void:
	task_id = p_id
	task_name = p_name
	module_name = "Task_" + task_id

func can_be_completed(state_manager: StateManager, completed_tasks: Array[String]) -> bool:
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
	time_remaining = emergency_time_limit

func get_display_name() -> String:
	if is_emergency:
		return "[EMERGENCY] " + task_name
	return task_name
