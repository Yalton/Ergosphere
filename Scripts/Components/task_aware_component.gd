# TaskAwareComponent.gd
extends Node
class_name TaskAwareComponent

signal associated_task_assigned(taks_id: String)
signal task_completed_at_object(task_id: String)
signal task_availability_changed(is_available: bool)

@export var enable_debug: bool = true
var module_name: String = "TaskAwareComponent"

@export_group("Task Settings")
## The ID of the task this component is associated with
@export var associated_task_id: String = ""
## Whether to show task name in interaction text
@export var show_task_in_interaction_text: bool = true

@export_group("UI Settings")
## Text shown when task is available. Use {task_name} to insert task name
@export var task_available_text: String = "Complete Task: {task_name}"
## Text shown when task is unavailable. Use {task_name} to insert task name
@export var task_unavailable_text: String = "Task Unavailable: {task_name}"
## Text shown when task is already completed
@export var task_completed_text: String = "Task Already Completed"
## Prefix added to emergency tasks
@export var emergency_prefix: String = "[EMERGENCY] "

var parent_node: Node
var interaction_component: InteractionComponent
var current_task: BaseTask = null
var is_task_available: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	parent_node = get_parent()
	
	# Find interaction component
	#for child in parent_node.get_children():
		#if child is InteractionComponent:
			#interaction_component = child
			#break
	#
	#if not interaction_component:
		#DebugLogger.error(module_name, "No InteractionComponent found on parent")
		#return
	
	# Add to task_aware group
	add_to_group("task_aware")
	
	GameManager.task_manager.task_completed.connect(_on_any_task_complete)
	# Initial update
	update_task_availability()
	
	DebugLogger.debug(module_name, "TaskAwareComponent initialized for task: " + associated_task_id)

func update_task_availability() -> void:
	if not GameManager or not GameManager.task_manager:
		DebugLogger.warning(module_name, "No TaskManager found")
		return
	
	var task_manager = GameManager.task_manager
	
	# Find our specific task
	current_task = task_manager._get_task_by_id(associated_task_id)

	# Connect to TaskManager singleton signal
	if GameManager.task_manager:
		GameManager.task_manager.task_assigned.connect(_on_task_assigned)
		DebugLogger.info(module_name, "Connected to TaskManager")
	else:
		DebugLogger.error(module_name, "TaskManager not found in GameManager!")
		
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
	
	DebugLogger.debug(module_name, "Task availability for "+str(associated_task_id)+ " updated: " + str(is_task_available))

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

# Call this from the parent when task should be completed
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

func _on_any_task_complete(_task_id):
	DebugLogger.debug(module_name, "TaskAware component detected task completion for id " + str(_task_id) + " updating task availability...")

	update_task_availability()

func _on_task_assigned(task_id: String) -> void:
	# Check if this is our associated task
	if task_id == associated_task_id:
		DebugLogger.info(module_name, "Associated task assigned: " + task_id)
		associated_task_assigned.emit(task_id)
		
# Check if our task is available for completion
func can_complete_task() -> bool:
	return is_task_available and current_task != null
