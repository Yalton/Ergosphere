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

## Timer for emergency task delay
var emergency_delay_timer: Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if GameManager.storage_manager: 
		GameManager.storage_manager.item_ordered.connect(_on_item_ordered)
	
	if not task_aware_component:
		task_aware_component = get_node_or_null("TaskAwareComponent")
		if not task_aware_component:
			DebugLogger.error(module_name, "No TaskAwareComponent found!")
			return
	
	# Setup emergency delay timer
	emergency_delay_timer = Timer.new()
	emergency_delay_timer.one_shot = true
	emergency_delay_timer.wait_time = 5.0
	emergency_delay_timer.timeout.connect(_trigger_emergency_heatsink_replacement)
	add_child(emergency_delay_timer)

func _on_item_ordered(item_id: String, container_location: String): 
	# Complete the exploration task
	if item_id == "heatsink" and task_aware_component: 
		task_aware_component.complete_task()
		
		# Start 5 second timer for emergency task
		DebugLogger.info(module_name, "Heatsink ordered, starting 5 second countdown to engine failure")
		emergency_delay_timer.start()

func _trigger_emergency_heatsink_replacement() -> void:
	DebugLogger.info(module_name, "Triggering emergency heatsink replacement task")
	GameManager.task_manager.trigger_emergency_task("replace_heatsink")
