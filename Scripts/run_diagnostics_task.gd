# introduction_task.gd
extends Node

## The Introduction task handler that guides players through exploring the station
## Plays voice lines as they enter new rooms and completes when all rooms are visited

@export var enable_debug: bool = true
var module_name: String = "RunDiagnosticstask"


@export_group("Task Settings")
## Task aware component to handle task completion
@export var task_aware_component: TaskAwareComponent
## The three tasks to assign after intro completion

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if DevConsoleManager: 
		DevConsoleManager.diag_run.connect(_on_diag_run)
	
	if not task_aware_component:
		task_aware_component = get_node_or_null("TaskAwareComponent")
		if not task_aware_component:
			DebugLogger.error(module_name, "No TaskAwareComponent found!")
			return
	
func _on_diag_run() -> void:
	DebugLogger.info(module_name, "Diagnostics ran, completing task")
	
	# Complete the exploration task
	if task_aware_component:
		task_aware_component.complete_task()
