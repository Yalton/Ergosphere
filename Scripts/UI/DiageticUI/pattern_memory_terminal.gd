extends DiegeticUIBase
class_name PatternMemoryDiageticUI

signal calibration_completed

## Task name displayed to the player
@export var task_name: String = "Calibrate System"

## Task description shown when interacting with the terminal
@export var task_description: String = "Complete the pattern memory sequence to calibrate the system"

## Number of successful sequences required to complete the task
@export_range(3, 10) var sequences_required: int = 5

@onready var pattern_memory_game: PatternMemoryGame = $SubViewport/PatternMemoryGame

func _ready() -> void:
	super._ready()
	module_name = "PatternMemoryDiageticUI"
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Add to calibration_terminals group for task system
	add_to_group("calibration_terminals")
	
	# Connect to the game's completion signal
	if pattern_memory_game:
		pattern_memory_game.sequences_to_win = sequences_required
		pattern_memory_game.calibration_complete.connect(_on_calibration_complete)
		DebugLogger.info(module_name, "Pattern memory game connected")
	else:
		DebugLogger.error(module_name, "Pattern memory game not found in SubViewport")

func _on_interaction_started() -> void:
	
	DebugLogger.info(module_name, "Starting pattern memory calibration")
	
	if pattern_memory_game:
		pattern_memory_game.start_game()

func _on_interaction_ended() -> void:
	
	DebugLogger.info(module_name, "Ending pattern memory calibration")
	
	if pattern_memory_game:
		pattern_memory_game.stop_game()

func _on_calibration_complete() -> void:
	DebugLogger.info(module_name, "Calibration completed, completing task")
	
	# Complete the task if we have a task component
	if task_aware_component:
		task_aware_component.complete_task()
	
	# Propagate signal
	calibration_completed.emit()
	
	# Auto-close after a short delay
	await get_tree().create_timer(1.0).timeout
	_on_interaction_ended()
