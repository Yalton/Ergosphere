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
signal ending_path_available(path_id: String)
signal ending_chosen(path_id: String)

@export var enable_debug: bool = true
var module_name: String = "TaskManager"

# Configuration
@export var day_configs: Array[DayConfigResource] = []
@export var default_tasks_per_day: int = 3
@export var sleep_task_id: String = "sleep"

# Fallback tasks if no day config
@export var default_available_tasks: Array[BaseTask] = []

# Current state
var current_day: int = 0
var current_day_config: DayConfigResource = null
var todays_tasks: Array[BaseTask] = []
var completed_tasks: Array[String] = []
var all_completed_tasks: Array[String] = []
var active_emergency_tasks: Array[BaseTask] = []
var story_flags: Array[String] = []

# Ending path tracking
var ending_paths: Dictionary = {
	"ending_a": {
		"tasks": ["secret_a_1", "secret_a_2", "secret_a_3"],
		"completed": [],
		"available": false
	},
	"ending_b": {
		"tasks": ["secret_b_1", "secret_b_2", "secret_b_3"],
		"completed": [],
		"available": false
	}
}
var chosen_ending: String = ""

# References
var state_manager: StateManager

# Emergency task timers
var emergency_timers: Dictionary = {}

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	set_process(true)

func initialize(_state_manager: StateManager) -> void:
	state_manager = _state_manager
	
	# Reset everything first
	_reset_task_system()
	
	# Connect to state changes to update task availability
	if not state_manager.state_changed.is_connected(_on_state_changed):
		state_manager.state_changed.connect(_on_state_changed)
	
	DebugLogger.info(module_name, "TaskManager initialized and reset with %d day configs" % day_configs.size())

func _reset_task_system() -> void:
	# Clean up any emergency timers
	for timer_id in emergency_timers:
		if is_instance_valid(emergency_timers[timer_id]):
			emergency_timers[timer_id].queue_free()
	emergency_timers.clear()
	
	# Reset all tracking variables
	current_day = 0
	current_day_config = null
	todays_tasks.clear()
	completed_tasks.clear()
	all_completed_tasks.clear()
	active_emergency_tasks.clear()
	story_flags.clear()
	
	# Reset ending paths
	for path_id in ending_paths:
		ending_paths[path_id]["completed"].clear()
		ending_paths[path_id]["available"] = false
	chosen_ending = ""
	
	# Reset task states
	for task in default_available_tasks:
		if task:
			task.reset()
	
	# Reset day configs' tasks
	for config in day_configs:
		if config:
			for task in config.available_tasks:
				if task:
					task.reset()
	
	DebugLogger.debug(module_name, "Task system reset")

func get_ending_path_for_task(task_id: String) -> String:
	for path_id in ending_paths:
		if task_id in ending_paths[path_id]["tasks"]:
			return path_id
	return ""

func is_ending_path_available(path_id: String) -> bool:
	if not ending_paths.has(path_id):
		return false
	
	var path_data = ending_paths[path_id]
	# Check if all tasks in the path are completed
	for task_id in path_data["tasks"]:
		if not task_id in path_data["completed"]:
			return false
	
	return true

func choose_ending(path_id: String) -> bool:
	if not is_ending_path_available(path_id):
		DebugLogger.warning(module_name, "Cannot choose ending %s - path not complete" % path_id)
		return false
	
	if chosen_ending != "":
		DebugLogger.warning(module_name, "Ending already chosen: %s" % chosen_ending)
		return false
	
	chosen_ending = path_id
	state_manager.set_state("chosen_ending", path_id)
	ending_chosen.emit(path_id)
	
	DebugLogger.info(module_name, "Ending chosen: %s" % path_id)
	return true

func get_available_endings() -> Array[String]:
	var available: Array[String] = []
	for path_id in ending_paths:
		if is_ending_path_available(path_id):
			available.append(path_id)
	return available

func start_new_day() -> void:
	current_day += 1
	completed_tasks.clear()
	todays_tasks.clear()
	
	# Reset daily completion state
	state_manager.set_state("all_daily_tasks_complete", false)
	
	# Find day config
	current_day_config = _get_day_config(current_day)
	
	if current_day_config:
		DebugLogger.info(module_name, "Using day config: %s" % current_day_config.day_name)
		
		# Apply starting states
		for state_key in current_day_config.starting_states:
			state_manager.set_state(state_key, current_day_config.starting_states[state_key])
		
		# Show intro message
		if current_day_config.intro_message:
			_show_day_message(current_day_config.intro_message)
		
		# Assign tasks from config
		_assign_tasks_from_config(current_day_config)
	else:
		# Use default tasks
		_assign_default_tasks()
	
	# Update task availability
	_update_task_availability()
	
	# Emit day started
	day_started.emit(current_day)
	
	DebugLogger.info(module_name, "Started day %d with %d tasks" % [current_day, todays_tasks.size()])

func _get_day_config(day_number: int) -> DayConfigResource:
	for config in day_configs:
		if config.day_number == day_number:
			return config
	return null

func _assign_tasks_from_config(config: DayConfigResource) -> void:
	# Reset tasks from config
	for task in config.available_tasks:
		task.reset()
	
	# Assign mandatory tasks
	for task_id in config.mandatory_tasks:
		var task = _find_task_in_pool(task_id, config.available_tasks)
		if task and not task.is_emergency:
			todays_tasks.append(task)
			if task.revealed_under.is_empty():
				task.is_revealed = true
				task_assigned.emit(task.task_id)
			DebugLogger.debug(module_name, "Assigned mandatory task: %s" % task.task_name)
	
	# Assign random tasks
	var remaining_slots = config.tasks_per_day - todays_tasks.size()
	if remaining_slots > 0 and config.random_task_pool.size() > 0:
		var available_random = []
		for task_id in config.random_task_pool:
			var task = _find_task_in_pool(task_id, config.available_tasks)
			if task and not task in todays_tasks and not task.is_emergency:
				available_random.append(task)
		
		available_random.shuffle()
		var tasks_to_add = min(remaining_slots, available_random.size())
		
		for i in range(tasks_to_add):
			var task = available_random[i]
			todays_tasks.append(task)
			if task.revealed_under.is_empty():
				task.is_revealed = true
				task_assigned.emit(task.task_id)
			DebugLogger.debug(module_name, "Assigned random task: %s" % task.task_name)
	
	# Always add sleep task if specified
	if config.force_sleep_task and not _has_sleep_task():
		var sleep_task = _find_task_in_pool(sleep_task_id, config.available_tasks)
		if not sleep_task:
			sleep_task = _find_task_in_pool(sleep_task_id, default_available_tasks)
		
		if sleep_task:
			todays_tasks.append(sleep_task)
			sleep_task.reset()
			if sleep_task.revealed_under.is_empty():
				sleep_task.is_revealed = true
			else:
				sleep_task.is_revealed = false
				DebugLogger.debug(module_name, "Sleep task starts hidden, waiting for reveal conditions")

func _has_sleep_task() -> bool:
	for task in todays_tasks:
		if task.task_id == sleep_task_id:
			return true
	return false

func _assign_default_tasks() -> void:
	if default_available_tasks.is_empty():
		DebugLogger.error(module_name, "No default tasks available. Cannot assign tasks.")
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
			task.reset()
			if task.revealed_under.is_empty():
				task.is_revealed = true
				task_assigned.emit(task.task_id)
			DebugLogger.debug(module_name, "Assigned task: %s" % task.task_name)
	
	# Add sleep task if available
	var sleep_task = _find_task_in_pool(sleep_task_id, default_available_tasks)
	if sleep_task:
		todays_tasks.append(sleep_task)
		sleep_task.reset()
		if sleep_task.revealed_under.is_empty():
			sleep_task.is_revealed = true
		else:
			sleep_task.is_revealed = false
			DebugLogger.debug(module_name, "Sleep task starts hidden, waiting for reveal conditions")
	else:
		DebugLogger.warning(module_name, "No sleep task found in default tasks")

func _find_task_in_pool(task_id: String, pool: Array[BaseTask]) -> BaseTask:
	for task in pool:
		if task.task_id == task_id:
			return task
	return null

func trigger_emergency_task(task_id: String) -> void:
	DebugLogger.info(module_name, "Triggering emergency task: %s" % task_id)
	
	# Find task in available pools
	var task: BaseTask = null
	
	# First check current day config tasks
	if current_day_config and current_day_config.available_tasks.size() > 0:
		for t in current_day_config.available_tasks:
			if t.task_id == task_id:
				task = t
				break
	
	# Fall back to default tasks
	if not task:
		for t in default_available_tasks:
			if t.task_id == task_id:
				task = t
				break
	
	if not task:
		DebugLogger.error(module_name, "Emergency task not found: %s" % task_id)
		return
	
	if not task.is_emergency:
		DebugLogger.warning(module_name, "Task %s is not marked as emergency" % task_id)
		return
	
	# Check if already active
	for active_task in active_emergency_tasks:
		if active_task.task_id == task_id:
			DebugLogger.debug(module_name, "Emergency task already active: %s" % task_id)
			return
	
	# Add to active emergencies
	task.reset()
	task.is_revealed = true
	active_emergency_tasks.append(task)
	
	# Start timer if has time limit
	if task.emergency_time_limit > 0:
		var timer = Timer.new()
		timer.wait_time = task.emergency_time_limit
		timer.one_shot = true
		timer.timeout.connect(_on_emergency_timer_expired.bind(task_id))
		add_child(timer)
		timer.start()
		emergency_timers[task_id] = timer
		
		task.time_remaining = task.emergency_time_limit
	
	emergency_task_triggered.emit(task_id)
	task_assigned.emit(task_id)
	
	DebugLogger.info(module_name, "Emergency task triggered: %s (time limit: %0.1fs)" % [task.task_name, task.emergency_time_limit])

func _on_emergency_timer_expired(task_id: String) -> void:
	DebugLogger.warning(module_name, "Emergency task expired: %s" % task_id)
	
	# Find and remove the task
	var expired_task: BaseTask = null
	for task in active_emergency_tasks:
		if task.task_id == task_id:
			expired_task = task
			break
	
	if expired_task:
		active_emergency_tasks.erase(expired_task)
		emergency_task_failed.emit(task_id)
		
		# Apply failure consequences if any
		if expired_task.failure_consequence:
			state_manager.apply_state_changes(expired_task.failure_consequence)
	
	# Clean up timer
	if emergency_timers.has(task_id):
		emergency_timers[task_id].queue_free()
		emergency_timers.erase(task_id)

func can_be_completed(task_id: String) -> bool: 
	# Find the task
	var task: BaseTask = null
	for t in todays_tasks:
		if t.task_id == task_id:
			task = t
			break
	
	# Check emergency tasks too
	if not task:
		for t in active_emergency_tasks:
			if t.task_id == task_id:
				task = t
				break
	
	if not task:
		return false
		
	if task.is_completed:
		return false
		
	# Check if task can be completed
	if not task.can_be_completed(state_manager, completed_tasks):
		return false
	
	return true

func complete_task(task_id: String) -> void:
	# Find the task
	var task: BaseTask = null
	for t in todays_tasks:
		if t.task_id == task_id:
			task = t
			break
	
	# Check emergency tasks too
	if not task:
		for t in active_emergency_tasks:
			if t.task_id == task_id:
				task = t
				break
	
	if not task:
		DebugLogger.error(module_name, "Task not found: %s" % task_id)
		return
		
	if task.is_completed:
		DebugLogger.warning(module_name, "Task already completed: %s" % task_id)
		return
		
	# Check if task can be completed
	if not task.can_be_completed(state_manager, completed_tasks):
		DebugLogger.warning(module_name, "Task cannot be completed yet: %s" % task_id)
		return
	
	# Complete the task
	task.complete()
	completed_tasks.append(task_id)
	all_completed_tasks.append(task_id)
	
	# Handle secrets
	if task.is_secret:
		DebugLogger.info(module_name, "Secret task completed: %s" % task.task_name)
		_show_secret_completed_message(task)
		task_assigned.emit(task_id)  # Notify UI to update
		
		# Track for ending paths
		var path_id = get_ending_path_for_task(task_id)
		if path_id != "":
			ending_paths[path_id]["completed"].append(task_id)
			DebugLogger.info(module_name, "Added to ending path %s: %d/3 complete" % [path_id, ending_paths[path_id]["completed"].size()])
			
			# Check if path is now complete
			if is_ending_path_available(path_id) and not ending_paths[path_id]["available"]:
				ending_paths[path_id]["available"] = true
				ending_path_available.emit(path_id)
				DebugLogger.info(module_name, "Ending path %s is now available!" % path_id)
	
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
	var completion_timer = get_tree().create_timer(1.0)
	completion_timer.timeout.connect(_check_daily_completion)
	
	DebugLogger.info(module_name, "Task completed: %s" % task.task_name)

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

func _show_secret_completed_message(task: BaseTask) -> void:
	var message = "Secret discovered: %s!" % task.task_name
	
	# Find player and show message
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("receive_message"):
			player.receive_message(message)
			
func _on_day_completed() -> void:
	DebugLogger.info(module_name, "Day %d completed!" % current_day)
	daily_tasks_completed.emit()

func _update_task_availability() -> void:
	# Update regular tasks
	for task in todays_tasks:
		# Update reveal state
		if not task.revealed_under.is_empty():
			var was_revealed = task.is_revealed
			task.update_reveal_state(state_manager, completed_tasks, get_process_delta_time())
			
			# Emit signals if reveal state changed
			if task.is_revealed and not was_revealed:
				task_revealed.emit(task.task_id)
				task_assigned.emit(task.task_id)
				DebugLogger.info(module_name, "Task revealed: %s" % task.task_name)
			elif not task.is_revealed and was_revealed:
				task_hidden.emit(task.task_id)
				DebugLogger.info(module_name, "Task hidden: %s" % task.task_name)
		
		# Update availability
		task.is_available = task.can_be_completed(state_manager, completed_tasks)
	
	# Update emergency tasks
	for task in active_emergency_tasks:
		task.is_available = task.can_be_completed(state_manager, completed_tasks)
		
		# Update time remaining if applicable
		if task.emergency_time_limit > 0 and emergency_timers.has(task.task_id):
			var timer = emergency_timers[task.task_id]
			if timer:
				task.time_remaining = timer.time_left

func _process(delta: float) -> void:
	# Update task availability periodically
	_update_task_availability()

# Public API methods
func get_todays_tasks() -> Array[BaseTask]:
	return todays_tasks

func get_current_tasks() -> Array[BaseTask]:
	return todays_tasks

func get_emergency_tasks() -> Array[BaseTask]:
	return active_emergency_tasks

func get_active_emergency_tasks() -> Array[BaseTask]:
	return active_emergency_tasks

func is_task_completed(task_id: String) -> bool:
	return task_id in completed_tasks

func get_task(task_id: String) -> BaseTask:
	for task in todays_tasks:
		if task.task_id == task_id:
			return task
	for task in active_emergency_tasks:
		if task.task_id == task_id:
			return task
	return null

func get_visible_tasks() -> Array[BaseTask]:
	var visible_tasks: Array[BaseTask] = []
	
	for task in todays_tasks:
		if task.is_revealed:
			visible_tasks.append(task)
	
	return visible_tasks

func has_active_tasks() -> bool:
	# Check if we have any non-completed revealed tasks
	for task in todays_tasks:
		if task.is_revealed and not task.is_completed:
			return true
	
	# Check emergency tasks
	return active_emergency_tasks.size() > 0

func are_all_tasks_completed() -> bool:
	if todays_tasks.is_empty():
		return false
		
	for task in todays_tasks:
		# Only check revealed tasks
		if task.is_revealed and not task.is_completed:
			return false
	
	return active_emergency_tasks.is_empty()

func assign_mandatory_tasks(task_ids: Array[String]) -> void:
	if task_ids.is_empty():
		return
	
	var assigned_count = 0
	
	for task_id in task_ids:
		# Find the task in available pools
		var task = _find_task_in_current_pools(task_id)
		
		if not task:
			DebugLogger.warning(module_name, "Task not found for mid-day assignment: %s" % task_id)
			continue
		
		# Check if task is already assigned today
		if task in todays_tasks:
			DebugLogger.debug(module_name, "Task already assigned today: %s" % task_id)
			continue
		
		# Add to today's tasks
		todays_tasks.append(task)
		assigned_count += 1
		
		# Check if it should be revealed immediately
		if task.revealed_under.is_empty():
			task.is_revealed = true
			task_assigned.emit(task_id)
		
		DebugLogger.info(module_name, "Assigned mandatory task mid-day: %s" % task.task_name)
	
	# Update task availability after adding new tasks
	_update_task_availability()
	
	DebugLogger.info(module_name, "Assigned %d mandatory tasks mid-day" % assigned_count)

func _find_task_in_current_pools(task_id: String) -> BaseTask:
	# First check current day config if available
	if current_day_config and current_day_config.available_tasks.size() > 0:
		var task = _find_task_in_pool(task_id, current_day_config.available_tasks)
		if task:
			return task
	
	# Fall back to default tasks
	return _find_task_in_pool(task_id, default_available_tasks)

func _show_day_message(message: String) -> void:
	# Find UI manager or player to show message
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("receive_message"):
			player.receive_message(message)

func _on_state_changed(key: String, value) -> void:
	# Update task availability when states change
	_update_task_availability()
