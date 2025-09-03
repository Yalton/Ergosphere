# TetrisDiegeticUI.gd
extends DiegeticUIBase

## Signal emitted when transmission is completed
signal tetris_transmission_completed()

## Reference to the DataTetrisControl node
@export var tetris_control: Control

func _ready() -> void:
	module_name = "TetrisDiegeticUI"
	super._ready()
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set interaction text
	usable_interaction_text = "Upload Data to Earth"
	interaction_text = usable_interaction_text
	
	# Find tetris control in SubViewport if not assigned
	if not tetris_control and sub_viewport and sub_viewport.get_child_count() > 0:
		tetris_control = sub_viewport.get_child(0)
		DebugLogger.debug(module_name, "Found tetris control in SubViewport")
	
	# Connect to tetris game signals
	if tetris_control:
		if tetris_control.has_signal("transmission_completed"):
			tetris_control.transmission_completed.connect(_on_transmission_completed)
			DebugLogger.debug(module_name, "Connected to transmission completion signal")
		else:
			DebugLogger.error(module_name, "Tetris control doesn't have transmission_completed signal!")
	else:
		DebugLogger.error(module_name, "No tetris control assigned!")
	
	DebugLogger.debug(module_name, "Tetris Diegetic UI initialized")

func start_interaction() -> void:
	super.start_interaction()
	
	# Resume the tetris game when interaction starts
	if tetris_control:
		DebugLogger.debug(module_name, "Resuming tetris game")
		tetris_control.resume_game()
	
	DebugLogger.debug(module_name, "Tetris game interaction started")

func end_interaction() -> void:
	# Pause the tetris game when interaction ends
	if tetris_control:
		DebugLogger.debug(module_name, "Pausing tetris game")
		tetris_control.pause_game()
	
	super.end_interaction()
	DebugLogger.debug(module_name, "Tetris game interaction ended")

func _on_transmission_completed() -> void:
	DebugLogger.info(module_name, "Transmission completed - data uploaded to Earth!")
	
	# Relay the signal to external listeners
	tetris_transmission_completed.emit()
	
	# Complete the task if task-aware component exists
	if task_aware_component:
		task_aware_component.complete_task()
		DebugLogger.debug(module_name, "Task completed via task-aware component")
	
	# End interaction after completion
	await get_tree().create_timer(1.0).timeout
	end_interaction()
