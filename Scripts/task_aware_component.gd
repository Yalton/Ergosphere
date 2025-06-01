# TaskAwareComponent.gd
extends Node
class_name TaskAwareComponent

signal task_completed_at_object(task_id: String)
signal task_availability_changed(is_available: bool)

@export var enable_debug: bool = true
var module_name: String = "TaskAwareComponent"

@export_group("Task Settings")
@export var associated_task_id: String = ""
@export var complete_on_interact: bool = true
@export var show_task_in_interaction_text: bool = true

@export_group("UI Settings")
@export var task_available_text: String = "Complete Task: {task_name}"
@export var task_unavailable_text: String = "Task Unavailable: {task_name}"
@export var task_completed_text: String = "Task Already Completed"
@export var emergency_prefix: String = "[EMERGENCY] "

var parent_node: Node
var interaction_component: InteractionComponent
var state_aware_component: StateAwareComponent
var current_task: BaseTask = null
var is_task_available: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	parent_node = get_parent()
	
	# Find interaction component
	for child in parent_node.get_children():
		if child is InteractionComponent:
			interaction_component = child
		elif child is StateAwareComponent:
			state_aware_component = child
	
	if not interaction_component:
		DebugLogger.error(module_name, "No InteractionComponent found on parent")
		return
	
	# Add to task_aware group
	add_to_group("task_aware")
	
	# Connect to parent's interact signal if it's a GameObject
	if parent_node is GameObject and parent_node.has_signal("object_state_updated"):
		# We'll update interaction text through this
		pass
	
	# Initial update
	update_task_availability()
	
	DebugLogger.debug(module_name, "TaskAwareComponent initialized for task: " + associated_task_id)

func update_task_availability() -> void:
	if not GameManager or not GameManager.has_node("TaskManager"):
		DebugLogger.warning(module_name, "No TaskManager found")
		return
	
	var task_manager = GameManager.get_node("TaskManager")
	
	# Check if this task exists and is available
	current_task = null
	for task in task_manager.get_current_tasks():
		if task.task_id == associated_task_id:
			current_task = task
			break
	
	# Also check emergency tasks
	if not current_task:
		for task in task_manager.get_active_emergency_tasks():
			if task.task_id == associated_task_id:
				current_task = task
				break
	
	# Determine availability
	var was_available = is_task_available
	
	if not current_task:
		is_task_available = false
		_update_interaction_state(false, "No active task")
	elif task_manager.is_task_completed(associated_task_id):
		is_task_available = false
		_update_interaction_state(false, task_completed_text)
	elif not current_task.is_available:
		is_task_available = false
		var reason = _format_task_text(task_unavailable_text)
		_update_interaction_state(false, reason)
	else:
		is_task_available = true
		var text = _format_task_text(task_available_text)
		if current_task.is_emergency:
			text = emergency_prefix + text
			if current_task.time_remaining > 0:
				text += " (" + str(int(current_task.time_remaining)) + "s)"
		_update_interaction_state(true, text)
	
	# Emit signal if availability changed
	if was_available != is_task_available:
		task_availability_changed.emit(is_task_available)
	
	DebugLogger.debug(module_name, "Task availability updated: " + str(is_task_available))

func _format_task_text(template: String) -> String:
	if current_task and show_task_in_interaction_text:
		return template.replace("{task_name}", current_task.task_name)
	return template.replace("{task_name}", "")

func _update_interaction_state(available: bool, text: String) -> void:
	if interaction_component:
		interaction_component.is_disabled = not available
		interaction_component.interaction_text = text
		
		# Notify parent GameObject to update UI
		if parent_node.has_signal("object_state_updated"):
			parent_node.object_state_updated.emit(text)

func on_interact(player_interaction: PlayerInteractionComponent) -> void:
	if not is_task_available or not current_task:
		DebugLogger.debug(module_name, "Task interaction blocked - not available")
		return
	
	if complete_on_interact:
		complete_task()

func complete_task() -> void:
	if not associated_task_id:
		DebugLogger.error(module_name, "No task ID associated with this component")
		return
	
	if not GameManager or not GameManager.has_node("TaskManager"):
		DebugLogger.error(module_name, "No TaskManager found")
		return
	
	var task_manager = GameManager.get_node("TaskManager")
	task_manager.complete_task(associated_task_id)
	
	# Emit local signal
	task_completed_at_object.emit(associated_task_id)
	
	# Update our state
	update_task_availability()
	
	DebugLogger.info(module_name, "Task completed at object: " + associated_task_id)

# Helper to check if any emergency tasks are active
func has_active_emergency_tasks() -> bool:
	if not GameManager or not GameManager.has_node("TaskManager"):
		return false
	
	var task_manager = GameManager.get_node("TaskManager")
	return task_manager.get_active_emergency_tasks().size() > 0

# Connect this to parent's interact method
func _on_parent_interact(player_interaction: PlayerInteractionComponent) -> void:
	on_interact(player_interaction)
