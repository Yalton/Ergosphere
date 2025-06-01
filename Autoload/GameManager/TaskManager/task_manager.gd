# TaskManager.gd
extends Node
class_name TaskManager

signal task_completed(task_id: String)
signal task_assigned(task_id: String)
signal emergency_task_triggered(task_id: String)
signal daily_tasks_completed()
signal emergency_task_failed(task_id: String)

@export var enable_debug: bool = true
var module_name: String = "TaskManager"

# Task management
@export var available_tasks: Array[BaseTask] = []
@export var tasks_per_day: int = 3
@export var sleep_task_id: String = "sleep"  # Always last task

# Current state
var current_day: int = 1
var todays_tasks: Array[BaseTask] = []
var completed_tasks: Array[String] = []  # Task IDs completed today
var all_completed_tasks: Array[String] = []  # All task IDs ever completed
var active_emergency_tasks: Array[BaseTask] = []

# References
var state_manager: StateManager
var event_manager: EventManager

# Emergency task timers
var emergency_timers: Dictionary = {}  # task_id -> Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)

func initialize(_state_manager: StateManager, _event_manager: EventManager) -> void:
	state_manager = _state_manager
	event_manager = _event_manager
	
	# Connect to state changes to update task availability
	state_manager.state_changed.connect(_on_state_changed)
	
	DebugLogger.info(module_name, "TaskManager initialized with " + str(available_tasks.size()) + " available tasks")

func start_new_day() -> void:
	current_day += 1
	completed_tasks.clear()
	todays_tasks.clear()
	
	# Select random tasks for today
	var valid_tasks = _get_valid_tasks_for_assignment()
	valid_tasks.shuffle()
	
	# Assign tasks (leaving room for sleep task)
	for i in range(min(tasks_per_day - 1, valid_tasks.size())):
		var task = valid_tasks[i]
		task.assigned_day = current_day
		todays_tasks.append(task)
		task_assigned.emit(task.task_id)
		DebugLogger.debug(module_name, "Assigned task: " + task.task_name)
	
	# Add sleep task as last
	var sleep_task = _get_task_by_id(sleep_task_id)
	if sleep_task:
		todays_tasks.append(sleep_task)
		DebugLogger.debug(module_name, "Added sleep task as final task")
	
	# Update task availability
	_update_task_availability()
	
	DebugLogger.info(module_name, "Started day " + str(current_day) + " with " + str(todays_tasks.size()) + " tasks")

func _get_valid_tasks_for_assignment() -> Array[BaseTask]:
	var valid_tasks: Array[BaseTask] = []
	
	for task in available_tasks:
		# Skip emergency tasks (they're triggered by events)
		if task.is_emergency:
			continue
		
		# Skip sleep task (added separately)
		if task.task_id == sleep_task_id:
			continue
		
		# Skip already completed tasks if they're one-time only
		# (You can add a property for this later if needed)
		
		valid_tasks.append(task)
	
	return valid_tasks

func trigger_emergency_task(task_id: String) -> void:
	var task = _get_task_by_id(task_id)
	if not task:
		DebugLogger.error(module_name, "Emergency task not found: " + task_id)
		return
	
	if not task.is_emergency:
		DebugLogger.warning(module_name, "Task is not marked as emergency: " + task_id)
		return
	
	# Add to active emergency tasks
	if not task in active_emergency_tasks:
		active_emergency_tasks.append(task)
		emergency_task_triggered.emit(task_id)
		
		# Start timer if it has a time limit
		if task.emergency_time_limit > 0:
			_start_emergency_timer(task)
		
		# Update task availability (emergency tasks block non-emergency)
		_update_task_availability()
		
		DebugLogger.info(module_name, "Emergency task triggered: " + task.task_name)

func _start_emergency_timer(task: BaseTask) -> void:
	var timer = Timer.new()
	timer.wait_time = task.emergency_time_limit
	timer.one_shot = true
	timer.timeout.connect(_on_emergency_timer_timeout.bind(task.task_id))
	add_child(timer)
	timer.start()
	
	emergency_timers[task.task_id] = timer
	task.time_remaining = task.emergency_time_limit
	
	DebugLogger.debug(module_name, "Started emergency timer for " + task.task_name + ": " + str(task.emergency_time_limit) + "s")

func _on_emergency_timer_timeout(task_id: String) -> void:
	var task = _get_task_by_id(task_id)
	if task and task in active_emergency_tasks:
		DebugLogger.warning(module_name, "Emergency task failed: " + task.task_name)
		emergency_task_failed.emit(task_id)
		
		# Remove from active emergency tasks
		active_emergency_tasks.erase(task)
		
		# Clean up timer
		if emergency_timers.has(task_id):
			emergency_timers[task_id].queue_free()
			emergency_timers.erase(task_id)
		
		_update_task_availability()

func complete_task(task_id: String) -> void:
	var task = _get_task_by_id(task_id)
	if not task:
		DebugLogger.error(module_name, "Task not found: " + task_id)
		return
	
	# Check if task can be completed
	if not task.can_be_completed(state_manager, completed_tasks):
		DebugLogger.warning(module_name, "Task cannot be completed: " + task.task_name)
		return
	
	# Complete the task
	task.complete()
	
	# Track completion
	if not task_id in completed_tasks:
		completed_tasks.append(task_id)
	if not task_id in all_completed_tasks:
		all_completed_tasks.append(task_id)
	
	# Remove from emergency tasks if applicable
	if task in active_emergency_tasks:
		active_emergency_tasks.erase(task)
		
		# Clean up timer
		if emergency_timers.has(task_id):
			emergency_timers[task_id].stop()
			emergency_timers[task_id].queue_free()
			emergency_timers.erase(task_id)
	
	task_completed.emit(task_id)
	
	# Check if it was the sleep task (end of day)
	if task_id == sleep_task_id:
		_on_day_completed()
	
	# Update availability for other tasks
	_update_task_availability()
	
	DebugLogger.info(module_name, "Task completed: " + task.task_name)

func _on_day_completed() -> void:
	DebugLogger.info(module_name, "Day " + str(current_day) + " completed!")
	daily_tasks_completed.emit()
	
	# You can add day transition logic here
	# For now, we'll wait for something to call start_new_day()

func _update_task_availability() -> void:
	# Check if any emergency tasks are active
	var has_emergency = active_emergency_tasks.size() > 0
	
	# Update all today's tasks
	for task in todays_tasks:
		if task.is_emergency:
			task.is_available = task in active_emergency_tasks
		else:
			# Non-emergency tasks are blocked if there's an emergency
			if has_emergency:
				task.is_available = false
			else:
				task.is_available = task.can_be_completed(state_manager, completed_tasks)
	
	# Notify task-aware components about availability changes
	_notify_task_aware_components()

func _notify_task_aware_components() -> void:
	# Find all task-aware components and update them
	var task_aware_components = get_tree().get_nodes_in_group("task_aware")
	for component in task_aware_components:
		if component.has_method("update_task_availability"):
			component.update_task_availability()

func _on_state_changed(state_name: String, new_value: Variant) -> void:
	# Update task availability when game state changes
	_update_task_availability()

func _get_task_by_id(task_id: String) -> BaseTask:
	for task in available_tasks:
		if task.task_id == task_id:
			return task
	return null

func get_current_tasks() -> Array[BaseTask]:
	return todays_tasks

func get_active_emergency_tasks() -> Array[BaseTask]:
	return active_emergency_tasks

func is_task_available(task_id: String) -> bool:
	var task = _get_task_by_id(task_id)
	return task != null and task.is_available

func is_task_completed(task_id: String) -> bool:
	return task_id in completed_tasks

# Process to update emergency task timers
func _process(delta: float) -> void:
	for task in active_emergency_tasks:
		if task.emergency_time_limit > 0 and emergency_timers.has(task.task_id):
			var timer = emergency_timers[task.task_id]
			task.time_remaining = timer.time_left
