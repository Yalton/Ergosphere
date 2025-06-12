# introduction_task.gd
extends Node

## The Introduction task handler that guides players through exploring the station
## Plays voice lines as they enter new rooms and completes when all rooms are visited

@export var enable_debug: bool = true
var module_name: String = "RebootSystemsStask"


@export_group("Task Settings")
## Task aware component to handle task completion
@export var task_aware_component: TaskAwareComponent
## The three tasks to assign after intro completion

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if GameManager.storage_manager: 
		GameManager.storage_manager.item_ordered.connect(_on_item_ordered)
	
	if not task_aware_component:
		task_aware_component = get_node_or_null("TaskAwareComponent")
		if not task_aware_component:
			DebugLogger.error(module_name, "No TaskAwareComponent found!")
			return


func _on_item_ordered(item_id: String, container_location: String): 
		# Complete the exploration task
	if item_id == "heatsink" and task_aware_component: 
		task_aware_component.complete_task()
