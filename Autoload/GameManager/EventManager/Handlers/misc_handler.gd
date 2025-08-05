extends EventHandler
class_name MiscEventHandler

## Handles miscellaneous events: door resistance and ghost tasks

# ============== DOOR RESISTANCE SETTINGS ==============
@export_group("Door Resistance Settings")
## How far the door opens before getting stuck (0.0 to 1.0)
@export var stuck_at_progress: float = 0.25
## How long the door stays stuck in seconds
@export var stuck_duration: float = 0.5
## Maximum distance to find a door from the player
@export var max_door_distance: float = 1000.0
## Group name for door wrappers
@export var door_wrapper_group: String = "door_wrappers"

# ============== GHOST TASK SETTINGS ==============
@export_group("Ghost Task Settings")
## Ghost task IDs that can be randomly completed
@export var ghost_task_ids: Array[String] = [
	"ghost_commune_entity",
	"ghost_sync_neural", 
	"ghost_calibrate_dimensional"
]

func _ready() -> void:
	# All events this consolidated handler processes
	handled_event_ids = [
		"door_malfunction",
		"ghost_task"
	]
	
	DebugLogger.register_module("MiscEventHandler")

func _can_execute_internal() -> Dictionary:
	DebugLogger.log_message("MiscEventHandler", "Checking if can execute: " + event_data.id)
	
	match event_data.id:
		"door_malfunction":
			return _can_execute_door_resistance()
		"ghost_task":
			return _can_execute_ghost_task()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func _execute_internal() -> Dictionary:
	DebugLogger.log_message("MiscEventHandler", "Executing event: " + event_data.id)
	
	match event_data.id:
		"door_malfunction":
			return _execute_door_resistance()
		"ghost_task":
			return _execute_ghost_task()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func end() -> void:
	DebugLogger.log_message("MiscEventHandler", "Ending event: " + event_data.id)
	
	# No special cleanup needed for these events
	
	# Call base implementation
	super.end()

# ============== DOOR RESISTANCE FUNCTIONS ==============
func _can_execute_door_resistance() -> Dictionary:
	var nearest_door = _find_nearest_closed_door()
	if not nearest_door:
		return {"success": false, "message": "No valid closed door found within " + str(max_door_distance) + " units of player"}
	
	if not nearest_door.has_method("set_resistance_next_open"):
		return {"success": false, "message": "Door does not support resistance functionality"}
	
	return {"success": true, "message": "OK"}

func _execute_door_resistance() -> Dictionary:
	var door = _find_nearest_closed_door()
	if not door:
		return {"success": false, "message": "No door found during execution"}
	
	# Tell the door to resist next time it opens
	door.set_resistance_next_open(stuck_at_progress, stuck_duration)
	
	DebugLogger.log_message("MiscEventHandler", "Set resistance on door at progress: " + str(stuck_at_progress))
	
	# End immediately - the door will handle the rest
	end()
	
	return {"success": true, "message": "OK"}

func _find_nearest_closed_door() -> Node:
	var player = CommonUtils.get_player()
	if not player:
		return null
	
	var door_wrappers : Array[Node] = get_tree().get_nodes_in_group(door_wrapper_group)
	
	var nearest_door = null
	var nearest_distance = max_door_distance
	
	for wrapper in door_wrappers:
		var door = wrapper.door
		
		var distance = player.global_position.distance_to(wrapper.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_door = door
	
	return nearest_door

# ============== GHOST TASK FUNCTIONS ==============
func _can_execute_ghost_task() -> Dictionary:
	var state_manager = get_state_manager()
	if not state_manager:
		return {"success": false, "message": "No state manager available"}
	
	if not state_manager.has_state("completed_ghost_tasks"):
		set_state("completed_ghost_tasks", [])
	
	var completed_ghosts = state_manager.get_state("completed_ghost_tasks")
	if completed_ghosts == null:
		completed_ghosts = []
	
	var available_count = 0
	for task_id in ghost_task_ids:
		if not task_id in completed_ghosts:
			available_count += 1
	
	if available_count == 0:
		return {"success": false, "message": "All ghost tasks already completed"}
	
	if not GameManager or not GameManager.task_manager:
		return {"success": false, "message": "Task manager not available"}
	
	return {"success": true, "message": "OK"}

func _execute_ghost_task() -> Dictionary:
	var state_manager = get_state_manager()
	var completed_ghosts = state_manager.get_state("completed_ghost_tasks")
	if completed_ghosts == null:
		completed_ghosts = []
	
	var available = []
	for task_id in ghost_task_ids:
		if not task_id in completed_ghosts:
			available.append(task_id)
	
	if available.is_empty():
		return {"success": false, "message": "No available ghost tasks to complete"}
	
	var chosen_id = available.pick_random()
	
	DebugLogger.log_message("MiscEventHandler", "Chosen ghost task: " + chosen_id)
	
	var task = GameManager.task_manager.get_task(chosen_id)
	if not task:
		task = GameManager.task_manager._find_task_by_id(chosen_id)
	
	if not task:
		return {"success": false, "message": "Ghost task not found: " + chosen_id}
	
	# Add to today's tasks if not already there
	if not task in GameManager.task_manager.todays_tasks:
		task.reset()
		task.is_revealed = true
		GameManager.task_manager.todays_tasks.append(task)
		GameManager.task_manager.task_assigned.emit(chosen_id)
		DebugLogger.log_message("MiscEventHandler", "Added ghost task to today's tasks: " + chosen_id)
	
	# Complete it immediately
	GameManager.task_manager.complete_task(chosen_id)
	
	# Update state
	completed_ghosts.append(chosen_id)
	set_state("completed_ghost_tasks", completed_ghosts)
	
	DebugLogger.log_message("MiscEventHandler", "Completed ghost task: " + chosen_id)
	
	# End immediately since this is instant
	end()
	
	return {"success": true, "message": "OK"}
