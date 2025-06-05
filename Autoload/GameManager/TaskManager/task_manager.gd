# TaskManager.gd
extends Node
class_name TaskManager

signal task_completed(task_id: String)
signal task_assigned(task_id: String)
signal task_revealed(task_id: String)
signal task_hidden(task_id: String)
signal emergency_task_triggered(task_id: String)
signal daily_tasks_completed()
signal emergency_task_failed(task_id: String)
signal day_started(day_number: int)

@export var enable_debug: bool = true
var module_name: String = "TaskManager"

# Configuration
@export var day_configs: Array[DayConfigResource] = []
@export var default_tasks_per_day: int = 3
@export var sleep_task_id: String = "sleep"  # Always last task

# Fallback tasks if no day config
@export var default_available_tasks: Array[BaseTask] = []

# Current state
var current_day: int = 0
var current_day_config: DayConfigResource = null
var todays_tasks: Array[BaseTask] = []
var completed_tasks: Array[String] = []  # Task IDs completed today
var all_completed_tasks: Array[String] = []  # All task IDs ever completed
var active_emergency_tasks: Array[BaseTask] = []
var story_flags: Array[String] = []  # Persistent story progression

# References
var state_manager: StateManager
var event_manager: EventManager

# Emergency task timers
var emergency_timers: Dictionary = {}  # task_id -> Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	set_process(true)  # Enable _process for reveal system

func initialize(_state_manager: StateManager, _event_manager: EventManager) -> void:
	state_manager = _state_manager
	event_manager = _event_manager
	
	# Connect to state changes to update task availability
	state_manager.state_changed.connect(_on_state_changed)
	
	DebugLogger.info(module_name, "TaskManager initialized with " + str(day_configs.size()) + " day configs")

func start_new_day() -> void:
	current_day += 1
	completed_tasks.clear()
	todays_tasks.clear()
	
	# Reset daily completion state
	state_manager.set_state("all_daily_tasks_complete", false)
	
	# Find day config
	current_day_config = _get_day_config(current_day)
	
	if current_day_config:
		DebugLogger.info(module_name, "Using day config: " + current_day_config.day_name)
		
		# Apply starting states
		for state_key in current_day_config.starting_states:
			state_manager.set_state(state_key, current_day_config.starting_states[state_key])
		
		# Show intro message
		if current_day_config.intro_message:
			_show_day_message(current_day_config.intro_message)
		
		# Assign tasks from config
		_assign_tasks_from_config(current_day_config)
	else:
		DebugLogger.info(module_name, "No day config, using default task selection")
		_assign_random_tasks()
	
	# Update task availability
	_update_task_availability()
	
	# Notify event manager about available events
	if event_manager:
		event_manager.set_day_events(current_day_config)
	
	day_started.emit(current_day)
	DebugLogger.info(module_name, "Started day " + str(current_day) + " with " + str(todays_tasks.size()) + " tasks")

func _get_day_config(day_number: int) -> DayConfigResource:
	# First try exact match
	for config in day_configs:
		if config.day_number == day_number:
			# Check if we have required flags
			var has_flags = true
			for flag in config.requires_flags:
				if not flag in story_flags:
					has_flags = false
					break
			if has_flags:
				return config
	
	# No config for this day
	return null

func _assign_tasks_from_config(config: DayConfigResource) -> void:
	var available_pool: Array[BaseTask] = []
	
	# Use config's available tasks or default
	if config.available_tasks.size() > 0:
		available_pool = config.available_tasks.duplicate()
	else:
		available_pool = default_available_tasks.duplicate()
	
	# Remove excluded tasks
	for i in range(available_pool.size() - 1, -1, -1):
		if available_pool[i].task_id in config.excluded_tasks:
			available_pool.remove_at(i)
	
	# Add mandatory tasks first
	for task_id in config.mandatory_tasks:
		var task = _find_task_in_pool(task_id, available_pool)
		if task and not task in todays_tasks:
			todays_tasks.append(task)
			# Only emit if task is initially revealed
			if task.revealed_under.is_empty():
				task.is_revealed = true
				task_assigned.emit(task.task_id)
			DebugLogger.debug(module_name, "Assigned mandatory task: " + task.task_name)
	
	# Determine how many tasks we need
	var tasks_needed = config.task_count_override if config.task_count_override >= 0 else default_tasks_per_day
	tasks_needed -= 1  # Leave room for sleep task
	tasks_needed -= todays_tasks.size()  # Account for mandatory tasks
	
	# Add random tasks to fill remaining slots
	available_pool.shuffle()
	for i in range(min(tasks_needed, available_pool.size())):
		var task = available_pool[i]
		if not task in todays_tasks and not task.is_emergency and task.task_id != sleep_task_id:
			todays_tasks.append(task)
			# Only emit if task is initially revealed
			if task.revealed_under.is_empty():
				task.is_revealed = true
				task_assigned.emit(task.task_id)
			DebugLogger.debug(module_name, "Assigned task: " + task.task_name)
	
	# Add sleep task as last (but don't reveal it yet if it has reveal conditions)
	var sleep_task = _find_task_in_pool(sleep_task_id, available_pool)
	if not sleep_task:
		sleep_task = _find_task_in_pool(sleep_task_id, default_available_tasks)
	if sleep_task:
		todays_tasks.append(sleep_task)
		if sleep_task.revealed_under.is_empty():
			sleep_task.is_revealed = true
		DebugLogger.debug(module_name, "Added sleep task as final task")

func _assign_random_tasks() -> void:
	# CRITICAL FIX: Check if we have any default tasks
	if default_available_tasks.is_empty():
		DebugLogger.error(module_name, "No default tasks available! Cannot assign tasks.")
		return
		
	var available_pool = default_available_tasks.duplicate()
	available_pool.shuffle()
	
	# Calculate actual tasks to assign (don't exceed pool size)
	var tasks_to_assign = min(default_tasks_per_day - 1, available_pool.size())
	
	# Assign tasks (leaving room for sleep task)
	for i in range(tasks_to_assign):
		var task = available_pool[i]
		if not task.is_emergency and task.task_id != sleep_task_id:
			todays_tasks.append(task)
			# Only emit if task is initially revealed
			if task.revealed_under.is_empty():
				task.is_revealed = true
				task_assigned.emit(task.task_id)
			DebugLogger.debug(module_name, "Assigned task: " + task.task_name)
	
	# Add sleep task if available
	var sleep_task = _find_task_in_pool(sleep_task_id, default_available_tasks)
	if sleep_task:
		todays_tasks.append(sleep_task)
		if sleep_task.revealed_under.is_empty():
			sleep_task.is_revealed = true
	else:
		DebugLogger.warning(module_name, "No sleep task found in default tasks")

func _find_task_in_pool(task_id: String, pool: Array[BaseTask]) -> BaseTask:
	for task in pool:
		if task.task_id == task_id:
			return task
	return null

func trigger_emergency_task(task_id: String) -> void:
	var task: BaseTask = null
	
	# First check current day config
	if current_day_config:
		task = _find_task_in_pool(task_id, current_day_config.available_tasks)
	
	# Fall back to default tasks
	if not task:
		task = _find_task_in_pool(task_id, default_available_tasks)
	
	if not task:
		DebugLogger.error(module_name, "Emergency task not found: " + task_id)
		return
	
	if not task.is_emergency:
		DebugLogger.warning(module_name, "Task is not marked as emergency: " + task_id)
		return
	
	# Add to active emergency tasks
	if not task in active_emergency_tasks:
		active_emergency_tasks.append(task)
		task.is_revealed = true  # Emergency tasks are always revealed
		emergency_task_triggered.emit(task_id)
		
		# Start timer if it has a time limit
		if task.emergency_time_limit > 0:
			_start_emergency_timer(task)
		
		# Update task availability (emergency tasks block non-emergency)
		_update_task_availability()
		
		# Check daily completion state since emergency blocks it
		_check_daily_completion()
		
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
		_check_daily_completion()

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
	
	# Special handling for secret tasks
	if task.is_secret:
		DebugLogger.info(module_name, "Secret task completed: " + task.task_name)
		# Show notification
		_show_secret_completed_message(task)
		# Task will now appear in UI since it's completed
		task_assigned.emit(task_id)  # Notify UI to update
	
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
	
	# Check if all daily tasks are complete
	_check_daily_completion()
	
	DebugLogger.info(module_name, "Task completed: " + task.task_name)

func _check_daily_completion() -> void:
	# Don't mark complete if there are active emergencies
	if active_emergency_tasks.size() > 0:
		state_manager.set_state("all_daily_tasks_complete", false)
		return
		
	# Check if all non-sleep tasks are complete
	var all_complete = true
	for task in todays_tasks:
		# Skip sleep task and secrets in this check
		if task.task_id == sleep_task_id or task.is_secret:
			continue
		if not task.is_completed:
			all_complete = false
			break
	
	# Update state
	var was_complete = state_manager.get_state("all_daily_tasks_complete")
	state_manager.set_state("all_daily_tasks_complete", all_complete)
	
	if all_complete and not was_complete:
		DebugLogger.info(module_name, "All daily tasks complete - sleep task should reveal soon")

# Show message when secret is completed
func _show_secret_completed_message(task: BaseTask) -> void:
	var message = "Secret discovered: " + task.task_name + "!"
	
	# Find player and show message
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("receive_message"):
			player.receive_message(message)
			
func _on_day_completed() -> void:
	DebugLogger.info(module_name, "Day " + str(current_day) + " completed!")
	
	# Set story flags if configured
	if current_day_config:
		for flag in current_day_config.sets_flags:
			if not flag in story_flags:
				story_flags.append(flag)
				DebugLogger.debug(module_name, "Set story flag: " + flag)
		
		# Show completion message
		if current_day_config.completion_message:
			_show_day_message(current_day_config.completion_message)
	
	daily_tasks_completed.emit()

# Get visible tasks (only revealed tasks)
func get_visible_tasks() -> Array[BaseTask]:
	var visible_tasks: Array[BaseTask] = []
	
	for task in todays_tasks:
		if task.is_revealed:
			visible_tasks.append(task)
	
	return visible_tasks

# Get count of secret tasks (completed and uncompleted)
func get_secret_task_count() -> Dictionary:
	var total_secrets = 0
	var completed_secrets = 0
	
	for task in todays_tasks:
		if task.is_secret:
			total_secrets += 1
			if task.is_completed:
				completed_secrets += 1
	
	return {
		"total": total_secrets,
		"completed": completed_secrets,
		"remaining": total_secrets - completed_secrets
	}

# Check if a task exists (including secrets)
func has_task(task_id: String) -> bool:
	return _get_task_by_id(task_id) != null
	
func _show_day_message(message: String) -> void:
	# Find player and show message
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("receive_message"):
			player.receive_message(message)

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
	
	# Emergency tasks
	for task in active_emergency_tasks:
		task.is_available = true
	
	# Notify task-aware components about availability changes
	_notify_task_aware_components()

func _notify_task_aware_components() -> void:
	# Find all task-aware components and update them
	var task_aware_components = get_tree().get_nodes_in_group("task_aware")
	for component in task_aware_components:
		if component.has_method("update_task_availability"):
			component.update_task_availability()

func _on_state_changed(_state_name: String, _new_value: Variant) -> void:
	# Update task availability when game state changes
	_update_task_availability()

func _get_task_by_id(task_id: String) -> BaseTask:
	# Check today's tasks
	for task in todays_tasks:
		if task.task_id == task_id:
			return task
	
	# Check emergency tasks
	for task in active_emergency_tasks:
		if task.task_id == task_id:
			return task
	
	# Check in current config
	if current_day_config:
		var task = _find_task_in_pool(task_id, current_day_config.available_tasks)
		if task:
			return task
	
	# Check default pool
	return _find_task_in_pool(task_id, default_available_tasks)

# Get current tasks (only revealed non-emergency tasks)
func get_current_tasks() -> Array[BaseTask]:
	var visible_tasks: Array[BaseTask] = []
	
	for task in todays_tasks:
		if task.is_revealed and not task.is_emergency:
			visible_tasks.append(task)
	
	return visible_tasks

func get_active_emergency_tasks() -> Array[BaseTask]:
	return active_emergency_tasks

func is_task_available(task_id: String) -> bool:
	var task = _get_task_by_id(task_id)
	return task != null and task.is_available

func is_task_completed(task_id: String) -> bool:
	return task_id in completed_tasks

# Check if we have any active tasks (for UI visibility)
func has_active_tasks() -> bool:
	# Check if we have any non-completed revealed tasks
	for task in todays_tasks:
		if task.is_revealed and not task.is_completed:
			return true
	
	# Check emergency tasks
	return active_emergency_tasks.size() > 0

# Check if all daily tasks are completed
func are_all_tasks_completed() -> bool:
	if todays_tasks.is_empty():
		return false
		
	for task in todays_tasks:
		# Only check revealed tasks
		if task.is_revealed and not task.is_completed:
			return false
	
	return active_emergency_tasks.is_empty()

## Assign mandatory tasks during the current day
func assign_mandatory_tasks_midday(task_ids: Array[String]) -> void:
	if not GameManager or not GameManager.task_manager:
		DebugLogger.error(module_name, "Cannot assign tasks - TaskManager not found!")
		return
	
	var assigned_count = 0
	
	for task_id in task_ids:
		# Find the task in available pools
		var task = _find_task_in_current_pools(task_id)
		
		if not task:
			DebugLogger.warning(module_name, "Task not found for mid-day assignment: " + task_id)
			continue
		
		# Check if task is already assigned today
		if task in todays_tasks:
			DebugLogger.debug(module_name, "Task already assigned today: " + task_id)
			continue
		
		# Add to today's tasks
		todays_tasks.append(task)
		assigned_count += 1
		
		# Check if it should be revealed immediately
		if task.revealed_under.is_empty():
			task.is_revealed = true
			task_assigned.emit(task_id)
		
		DebugLogger.info(module_name, "Assigned mandatory task mid-day: " + task.task_name)
	
	# Update task availability after adding new tasks
	_update_task_availability()
	
	DebugLogger.info(module_name, "Assigned " + str(assigned_count) + " mandatory tasks mid-day")

## Find task in current day's available pools or fallback to defaults
func _find_task_in_current_pools(task_id: String) -> BaseTask:
	# First check current day config if available
	if current_day_config and current_day_config.available_tasks.size() > 0:
		var task = _find_task_in_pool(task_id, current_day_config.available_tasks)
		if task:
			return task
	
	# Fall back to default tasks
	return _find_task_in_pool(task_id, default_available_tasks)
			
# Process to update emergency task timers and reveal system
func _process(delta: float) -> void:
	# Update emergency task timers
	for task in active_emergency_tasks:
		if task.emergency_time_limit > 0 and emergency_timers.has(task.task_id):
			var timer = emergency_timers[task.task_id]
			task.time_remaining = timer.time_left
	
	# Update reveal state for all today's tasks
	for task in todays_tasks:
		var was_revealed = task.is_revealed
		task.update_reveal_state(state_manager, completed_tasks, delta)
		
		# Emit signals when reveal state changes
		if task.is_revealed and not was_revealed:
			task_revealed.emit(task.task_id)
			task_assigned.emit(task.task_id)  # Also emit assigned for UI update
			DebugLogger.info(module_name, "Task revealed: " + task.task_name)
		elif not task.is_revealed and was_revealed:
			task_hidden.emit(task.task_id)
			DebugLogger.info(module_name, "Task hidden: " + task.task_name)
