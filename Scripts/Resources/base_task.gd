# BaseTask.gd
extends Resource
class_name BaseTask

# Core task properties
## Unique identifier for this task. Used by TaskManager and TaskAwareComponent to reference this task.
@export var task_id: String = ""

## Display name shown to the player in the UI
@export var task_name: String = "Unnamed Task"

## Longer description of what the player needs to do. Can be shown as tooltip or help text.
@export var task_description: String = ""

## If true, this task is an emergency that blocks normal tasks and may have a time limit
@export var is_emergency: bool = false

## If true, this task is a secret task that only appears when completed
@export var is_secret: bool = false

## Time limit in seconds for emergency tasks. 0 = no time limit. Task fails if timer expires.
@export var emergency_time_limit: float = 0.0

## Failure consequence type (1-3 for different bad endings). 0 = no consequence
@export var failure_consequence: int = 0

## List of task IDs that must be completed before this task becomes available
@export var dependent_on_tasks: Array[String] = []

## Groups that contain objects related to this task. Objects in these groups may show task-specific UI.
@export var related_object_groups: Array[String] = []

# Task state
var is_completed: bool = false
var is_available: bool = true  # Default to available unless dependencies not met
var is_revealed: bool = true   # Default to revealed unless it's a secret
var time_remaining: float = 0.0

# Debug
var enable_debug: bool = false
var module_name: String = "BaseTask"

func _init(p_id: String = "", p_name: String = "") -> void:
	task_id = p_id
	task_name = p_name
	module_name = "Task_" + p_name
	DebugLogger.register_module(module_name, enable_debug)

func can_be_completed(completed_tasks: Array[String]) -> bool:
	# Secret tasks can always be completed (if found)
	if is_secret:
		return true
	
	# Must be revealed
	if not is_revealed:
		return false
	
	# Check dependencies
	for dep_task in dependent_on_tasks:
		if not dep_task in completed_tasks:
			DebugLogger.debug(module_name, "Cannot complete - missing dependency: %s" % dep_task)
			return false
	
	return true

func complete() -> void:
	is_completed = true
	# Reveal secret tasks when completed
	if is_secret:
		is_revealed = true
	DebugLogger.info(module_name, "Task completed: %s" % task_name)

func reset() -> void:
	is_completed = false
	is_available = true
	# Hide secret tasks on reset
	is_revealed = not is_secret
	time_remaining = emergency_time_limit

func get_display_name() -> String:
	if is_emergency:
		return "[EMERGENCY] %s" % task_name
	return task_name
