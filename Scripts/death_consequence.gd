# DeathCutsceneTrigger.gd
extends Node

## Enable debug logging for this module
@export var enable_debug: bool = true
var module_name: String = "DeathCutsceneTrigger"

## Path to the death cutscene scene
@export_file("*.tscn") var death_cutscene_path: String = "res://scenes/cutscenes/death_cutscene.tscn"

var task_manager: TaskManager

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Get task manager
	task_manager = GameManager.task_manager
	
	if not task_manager:
		DebugLogger.error(module_name, "TaskManager not found!")
		return
	
	# Connect to emergency task failure signal
	task_manager.emergency_task_failed.connect(_on_emergency_task_failed)
	
	# Store the failed task ID in TaskManager if property doesn't exist
	if not "last_failed_emergency_task" in task_manager:
		task_manager.set("last_failed_emergency_task", "")
	
	DebugLogger.info(module_name, "Death cutscene trigger ready")

func _on_emergency_task_failed(task_id: String) -> void:
	DebugLogger.info(module_name, "Emergency task failed: %s" % task_id)
	
	# Check if this is a fatal emergency task
	if task_id == "restore_power" or task_id == "replace_heatsink" or task_id == "collapse_inevitable":
		# Store which task killed the player
		if task_id == "collapse_inevitable":
			GameManager.died_to = "ending"
		else:
			GameManager.died_to = task_id
		
		# Trigger death cutscene
		_trigger_death_cutscene()

func _trigger_death_cutscene() -> void:
	DebugLogger.info(module_name, "Triggering death cutscene")
	
	# Use TransitionManager if available
	if TransitionManager:
		await TransitionManager.fade_to_black()
		get_tree().change_scene_to_file(death_cutscene_path)
		# The death cutscene will handle its own fade in
	else:
		# Direct scene change
		get_tree().change_scene_to_file(death_cutscene_path)
