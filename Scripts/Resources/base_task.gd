# SimpleTask.gd
extends Resource
class_name BaseTask

## Streamlined task definition with minimal complexity

#region Core Properties

## Unique task identifier
@export var id: String = ""

## Display name shown to player
@export var name: String = ""

## Detailed description of what the player needs to do
@export_multiline var description: String = ""

## Task category for organization
@export_enum("Daily", "Emergency", "Story", "Optional") var category: String = "Daily"

## Priority for sorting (higher = more important)
@export_range(0, 10) var priority: int = 5

#endregion

#region Task Requirements

## Simple state requirements (state_name: required_value)
## Example: {"power": "on", "lockdown": false}
@export var required_states: Dictionary = {}

## Required completed task IDs
@export var required_tasks: Array[String] = []

## Day range when task is available (0 = any day)
@export var available_from_day: int = 0
@export var available_until_day: int = 0

#endregion

#region Task Behavior

## Time limit in seconds (0 = no limit)
@export var time_limit: float = 0.0

## Can this task be failed?
@export var can_fail: bool = false

## What happens on failure
@export_enum("Nothing", "Game Over", "Penalty") var failure_type: String = "Nothing"

## Points/rewards for completion
@export var completion_reward: int = 0

## Should this task auto-complete when conditions are met?
@export var auto_complete: bool = false

## Associated object groups (for highlighting relevant objects)
@export var related_groups: Array[String] = []

#endregion

#region Runtime State (Not Exported)

var is_completed: bool = false
var is_assigned: bool = false
var is_available: bool = false
var time_remaining: float = 0.0
var start_time: float = 0.0

#endregion

#region Helper Methods

## Check if all requirements are met
func check_requirements(state_manager: StateManager, completed_tasks: Array[String]) -> bool:
	# Check state requirements
	for state_name in required_states:
		var required_value = required_states[state_name]
		var current_value = state_manager.get_state(state_name)
		if current_value != required_value:
			return false
	
	# Check task requirements
	for task_id in required_tasks:
		if not task_id in completed_tasks:
			return false
	
	return true

## Check if task is available on given day
func is_available_on_day(day: int) -> bool:
	if available_from_day > 0 and day < available_from_day:
		return false
	if available_until_day > 0 and day > available_until_day:
		return false
	return true

## Get formatted time remaining
func get_time_remaining_text() -> String:
	if time_limit <= 0:
		return ""
	
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	
	if minutes > 0:
		return "%d:%02d" % [minutes, seconds]
	else:
		return "%d seconds" % seconds

## Reset task to initial state
func reset() -> void:
	is_completed = false
	is_assigned = false
	is_available = false
	time_remaining = time_limit
	start_time = 0.0

## Start the task (when assigned)
func start() -> void:
	is_assigned = true
	time_remaining = time_limit
	start_time = Time.get_ticks_msec() / 1000.0

## Update timer (call from _process)
func update_timer(delta: float) -> bool:
	if not is_assigned or is_completed or time_limit <= 0:
		return false
		
	time_remaining -= delta
	
	if time_remaining <= 0 and can_fail:
		return true # Task failed
	
	return false

## Complete the task
func complete() -> void:
	is_completed = true
	is_assigned = false

## Create a duplicate for runtime use
func duplicate_for_runtime() -> SimpleTask:
	var copy = duplicate(true) as SimpleTask
	copy.reset()
	return copy

#endregion
