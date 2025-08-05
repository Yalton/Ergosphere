extends EventHandler
class_name GhostTaskEvent

@export_group("Ghost Task Settings")
## Ghost task IDs that can be randomly completed
@export var ghost_task_ids: Array[String] = [
	"ghost_commune_entity",
	"ghost_sync_neural", 
	"ghost_calibrate_dimensional"
]

func _ready() -> void:
	# This handler handles the ghost_task event
	handled_event_ids = ["ghost_task"]

func _can_execute_internal() -> Dictionary:
	# Initialize state if not exists
	var state_manager = get_state_manager()
	if not state_manager:
		return {"success": false, "message": "No state manager available"}
	
	if not state_manager.has_state("completed_ghost_tasks"):
		set_state("completed_ghost_tasks", [])
	
	# Get completed ghost tasks from state
	var completed_ghosts = state_manager.get_state("completed_ghost_tasks")
	if completed_ghosts == null:
		completed_ghosts = []
	
	# Check if we have any ghost tasks left
	var available_count = 0
	for task_id in ghost_task_ids:
		if not task_id in completed_ghosts:
			available_count += 1
	
	if available_count == 0:
		return {"success": false, "message": "All ghost tasks already completed"}
	
	# Check if task manager exists
	if not GameManager or not GameManager.task_manager:
		return {"success": false, "message": "Task manager not available"}
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	# Get completed ghost tasks
	var state_manager = get_state_manager()
	var completed_ghosts = state_manager.get_state("completed_ghost_tasks")
	if completed_ghosts == null:
		completed_ghosts = []
	
	# Find available ghost tasks
	var available = []
	for task_id in ghost_task_ids:
		if not task_id in completed_ghosts:
			available.append(task_id)
	
	if available.is_empty():
		return {"success": false, "message": "No available ghost tasks to complete"}
	
	# Pick random task
	var chosen_id = available.pick_random()
	
	# Get the task
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
	
	# Complete it immediately
	GameManager.task_manager.complete_task(chosen_id)
	
	# Update state
	completed_ghosts.append(chosen_id)
	set_state("completed_ghost_tasks", completed_ghosts)
	
	# End immediately since this is instant
	end()
	
	return {"success": true, "message": "OK"}

func end() -> void:
	# Nothing to clean up for this event
	super.end()
