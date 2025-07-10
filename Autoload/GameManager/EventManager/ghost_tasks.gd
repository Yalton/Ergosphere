# ghost_task_event.gd
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
	super._ready()
	module_name = "GhostTaskEvent"
	
	# This handler handles the ghost_task event
	handled_event_ids = ["ghost_task"]

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Initialize state if not exists
	var state_manager = get_state_manager()
	if state_manager and not state_manager.has_state("completed_ghost_tasks"):
		set_state("completed_ghost_tasks", [])
	
	# Get completed ghost tasks from state
	var completed_ghosts = state_manager.get_state("completed_ghost_tasks")
	if completed_ghosts == null:
		completed_ghosts = []
	
	# Check if we have any ghost tasks left
	for task_id in ghost_task_ids:
		if not task_id in completed_ghosts:
			return true
	
	DebugLogger.debug(module_name, "All ghost tasks already completed")
	return false

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
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
		return false
	
	# Pick random task
	var chosen_id = available.pick_random()
	
	# Get the task
	var task = GameManager.task_manager.get_task(chosen_id)
	if not task:
		task = GameManager.task_manager._find_task_by_id(chosen_id)
	
	if not task:
		DebugLogger.error(module_name, "Ghost task not found: %s" % chosen_id)
		return false
	
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
	
	DebugLogger.info(module_name, "Ghost task completed: %s" % chosen_id)
	
	# End immediately since this is instant
	end()
	
	return true

func end() -> void:
	# Nothing to clean up for this event
	super.end()
