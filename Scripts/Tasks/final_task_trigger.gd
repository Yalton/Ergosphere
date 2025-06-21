# FinalTaskTrigger.gd
extends Node

## Node that monitors for Day 5 completion and triggers the final emergency task
@export var enable_debug: bool = true
var module_name: String = "FinalTaskTrigger"

## ID of the final emergency task to trigger
@export var final_task_id: String = "total_reality_collapse"

## Delay in seconds after all tasks complete before triggering final task
@export var trigger_delay: float = 10.0

## Path to default cutscene for timeout ending
@export_file("*.tscn") var default_cutscene_path: String = ""

## Path to alternate cutscene 1
@export_file("*.tscn") var alternate_cutscene_1_path: String = ""

## Path to alternate cutscene 2  
@export_file("*.tscn") var alternate_cutscene_2_path: String = ""

## Path to credits scene (goes back to main menu for now)
@export_file("*.tscn") var main_menu_path: String = "res://scenes/main_menu.tscn"

var task_manager: TaskManager
var game_manager
var delay_timer: Timer
var monitoring: bool = false
var final_task_triggered: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Find managers
	task_manager = GameManager.task_manager
	game_manager = GameManager
	
	if not task_manager:
		DebugLogger.error(module_name, "TaskManager not found!")
		return
		
	if not game_manager:
		DebugLogger.error(module_name, "GameManager not found!")
		return
	
	# Connect to task completion signals
	task_manager.daily_tasks_completed.connect(_on_daily_tasks_completed)
	task_manager.emergency_task_failed.connect(_on_emergency_task_failed)
	task_manager.task_completed.connect(_on_task_completed)
	
	# Setup delay timer
	delay_timer = Timer.new()
	delay_timer.one_shot = true
	delay_timer.timeout.connect(_trigger_final_task)
	add_child(delay_timer)
	
	DebugLogger.info(module_name, "Final task trigger ready, waiting for day 5")

func _on_daily_tasks_completed() -> void:
	# Check if we're on day 5
	if game_manager.current_day != 5:
		DebugLogger.debug(module_name, "Daily tasks complete on day %d, not day 5" % game_manager.current_day)
		return
		
	if final_task_triggered:
		DebugLogger.debug(module_name, "Final task already triggered")
		return
		
	DebugLogger.info(module_name, "Day 5 tasks complete! Starting %d second countdown..." % trigger_delay)
	monitoring = true
	delay_timer.start(trigger_delay)

func _trigger_final_task() -> void:
	if final_task_triggered:
		return
		
	final_task_triggered = true
	DebugLogger.info(module_name, "Triggering final emergency task: %s" % final_task_id)
	
	# Trigger the emergency task
	task_manager.trigger_emergency_task(final_task_id)

func _on_emergency_task_failed(task_id: String) -> void:
	if task_id != final_task_id:
		return
		
	DebugLogger.info(module_name, "Final task timed out - loading default ending")
	_load_ending_sequence(default_cutscene_path)

func _on_task_completed(task_id: String) -> void:
	if task_id != final_task_id:
		return
		
	DebugLogger.info(module_name, "Final task completed - checking which ending to load")
	
	# Check story flags or states to determine which ending
	var state_manager = game_manager.state_manager
	
	# Example: Check for alternate path items/states
	if state_manager.get_state("has_artifact_1", false):
		DebugLogger.info(module_name, "Loading alternate ending 1")
		_load_ending_sequence(alternate_cutscene_1_path)
	elif state_manager.get_state("has_artifact_2", false):
		DebugLogger.info(module_name, "Loading alternate ending 2")
		_load_ending_sequence(alternate_cutscene_2_path)
	else:
		DebugLogger.info(module_name, "Loading default completion ending")
		_load_ending_sequence(default_cutscene_path)

func _load_ending_sequence(cutscene_path: String) -> void:
	DebugLogger.info(module_name, "Starting ending sequence with cutscene: %s" % cutscene_path)
	
	# First, fade to black
	if TransitionManager:
		await TransitionManager.fade_to_black()
		
		# Unload game scene
		get_tree().current_scene.queue_free()
		
		# Load cutscene if path provided
		if cutscene_path and cutscene_path != "":
			DebugLogger.info(module_name, "Loading cutscene: %s" % cutscene_path)
			
			# Load and instantiate cutscene
			var cutscene_resource = load(cutscene_path)
			if cutscene_resource:
				var cutscene_instance = cutscene_resource.instantiate()
				get_tree().root.add_child(cutscene_instance)
				get_tree().current_scene = cutscene_instance
				
				# Connect to cutscene finished signal if it exists
				if cutscene_instance.has_signal("cutscene_finished"):
					cutscene_instance.cutscene_finished.connect(_on_cutscene_finished)
				else:
					# If no signal, wait a default time then go to credits
					await get_tree().create_timer(5.0).timeout
					_on_cutscene_finished()
			else:
				DebugLogger.error(module_name, "Failed to load cutscene: %s" % cutscene_path)
				_on_cutscene_finished()
		else:
			DebugLogger.warning(module_name, "No cutscene path provided, going straight to main menu")
			_on_cutscene_finished()
			
		# Fade back in
		await TransitionManager.fade_from_black()
	else:
		# No transition manager, just change scene
		if cutscene_path and cutscene_path != "":
			get_tree().change_scene_to_file(cutscene_path)
			# Wait for scene to load then setup finish timer
			await get_tree().create_timer(0.5).timeout
			await get_tree().create_timer(5.0).timeout
			_go_to_main_menu()
		else:
			_go_to_main_menu()

func _on_cutscene_finished() -> void:
	DebugLogger.info(module_name, "Cutscene finished, transitioning to main menu")
	_go_to_main_menu()

func _go_to_main_menu() -> void:
	DebugLogger.info(module_name, "Loading main menu")
	
	if TransitionManager:
		TransitionManager.transition_to_scene(main_menu_path)
	else:
		get_tree().change_scene_to_file(main_menu_path)
