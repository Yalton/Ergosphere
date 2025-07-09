extends DiegeticUIBase
class_name PatternMemoryDiageticUI

signal calibration_completed

## Task name displayed to the player
@export var task_name: String = "Calibrate System"

## Task description shown when interacting with the terminal
@export var task_description: String = "Complete the pattern memory sequence to calibrate the system"

## Number of successful sequences required to complete the task
@export_range(3, 10) var sequences_required: int = 5

func _ready() -> void:
	module_name = "PatternMemoryDiageticUI"
	super._ready()

	
	# Find task aware component
	
	# Add to calibration_terminals group for task system
	add_to_group("calibration_terminals")
	
	# Connect to the game's completion signal
	if ui_content:
		ui_content.sequences_to_win = sequences_required
		ui_content.calibration_complete.connect(_on_calibration_complete)
		DebugLogger.info(module_name, "Pattern memory game connected")
	else:
		DebugLogger.error(module_name, "Pattern memory game not found in SubViewport")

func _on_interaction_started() -> void:
	
	DebugLogger.info(module_name, "Starting pattern memory calibration")
	
	if ui_content:
		ui_content.start_game()

func _on_interaction_ended() -> void:
	
	DebugLogger.info(module_name, "Ending pattern memory calibration")
	
	if ui_content:
		ui_content.stop_game()

func _on_calibration_complete() -> void:
	DebugLogger.info(module_name, "Calibration completed, completing task")
	
	# Complete the task if we have a task component
	if task_aware_component:
		task_aware_component.complete_task()
	else: 
		DebugLogger.info(module_name, "No task_aware_component available")
	
	# Propagate signal
	calibration_completed.emit()
	
	# Auto-close after a short delay
	await get_tree().create_timer(1.0).timeout
	_on_interaction_ended()
