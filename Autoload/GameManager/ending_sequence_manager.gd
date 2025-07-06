# EndingSequenceManager.gd
extends Node
class_name EndingSequenceManager

signal ending_sequence_started()
signal ending_choices_spawned()
signal ending_chosen(ending_type: String)
signal game_ended()

@export var enable_debug: bool = true
var module_name: String = "EndingSequenceManager"

@export_group("Ending Configuration")
## Day number that triggers the ending sequence
@export var final_day: int = 7
## Delay before starting escape sequence after all tasks complete
@export var sequence_delay: float = 5.0
## Emergency task ID for the escape sequence
@export var escape_task_id: String = "escape_inevitable"
## Time to wait after ending chosen before changing scene
@export var scene_transition_delay: float = 2.0

@export_group("Ending Scenes")
## Scene to load for default ending (timer runs out)
@export var default_ending_scene: PackedScene
## Scene to load for alternate ending A
@export var alt_a_ending_scene: PackedScene
## Scene to load for alternate ending B  
@export var alt_b_ending_scene: PackedScene

@export_group("Choice Interactables")
## Interactable scene for alternate ending A choice
@export var alt_a_choice_scene: PackedScene
## Interactable scene for alternate ending B choice
@export var alt_b_choice_scene: PackedScene
#
#@export_group("Spawn Positions")
### Where to spawn alternate A choice
#@export var alt_a_spawn_position: Vector3 = Vector3(-5, 0, 0)
### Where to spawn alternate B choice
#@export var alt_b_spawn_position: Vector3 = Vector3(5, 0, 0)
### Parent node path for spawned objects (empty = current scene root)
#@export var spawn_parent_path: NodePath = ""

# State tracking
var sequence_started: bool = false
var ending_selected: bool = false
var spawned_choices: Array[Node] = []

# References
var game_manager
var task_manager: TaskManager
var state_manager: StateManager

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Get references
	game_manager = GameManager
	if game_manager:
		task_manager = game_manager.task_manager
		state_manager = game_manager.state_manager
	
	if not task_manager:
		DebugLogger.error(module_name, "TaskManager not found!")
		return
		
	# Connect to task manager signals
	task_manager.daily_tasks_completed.connect(_on_daily_tasks_completed)
	task_manager.ending_chosen.connect(_on_ending_chosen)
	task_manager.emergency_task_failed.connect(_on_emergency_task_failed)
	
	DebugLogger.info(module_name, "EndingSequenceManager initialized")

func _on_daily_tasks_completed() -> void:
	# Check if this is the final day
	if not game_manager or game_manager.current_day != final_day:
		return
		
	if sequence_started:
		return
		
	DebugLogger.info(module_name, "Final day tasks completed! Starting ending sequence in %.1f seconds..." % sequence_delay)
	
	# Start the ending sequence after delay
	sequence_started = true
	await get_tree().create_timer(sequence_delay).timeout
	_start_ending_sequence()

func _start_ending_sequence() -> void:
	DebugLogger.info(module_name, "Starting ending sequence!")
	
	# Set state for reality collapse
	if state_manager:
		state_manager.set_state("reality_collapse", true)
	
	# Trigger the escape emergency task
	if task_manager:
		task_manager.trigger_emergency_task(escape_task_id)
	
	# Spawn ending choices based on completed paths
	_spawn_ending_choices()
	
	ending_sequence_started.emit()

func _spawn_ending_choices() -> void:
	var parent = _get_spawn_parent()
	
	# Check which endings are available
	var alt_a_available = task_manager.is_ending_path_available("ending_a")
	var alt_b_available = task_manager.is_ending_path_available("ending_b")
	
	if not alt_a_available and not alt_b_available:
		DebugLogger.info(module_name, "No alternate endings unlocked - only default ending available")
		return
	
	# Spawn alternate A choice if available
	if alt_a_available and alt_a_choice_scene:
		var choice_a = alt_a_choice_scene.instantiate()
		var station : Station = get_tree().get_first_node_in_group("station")
		station.ending_choice_container.add_child(choice_a)
		choice_a.position = station.alt_a_marker.global_position 
		spawned_choices.append(choice_a)
		DebugLogger.info(module_name, "Spawned alternate ending A choice at %s" % station.alt_a_marker.global_position )
	
	# Spawn alternate B choice if available  
	if alt_b_available and alt_b_choice_scene:
		var choice_b = alt_b_choice_scene.instantiate()
		var station : Station = get_tree().get_first_node_in_group("station")
		station.ending_choice_container.add_child(choice_b)
		choice_b.position = station.alt_b_marker.global_position 
		spawned_choices.append(choice_b)
		DebugLogger.info(module_name, "Spawned alternate ending B choice at %s" % station.alt_a_marker.global_position )
	
	if spawned_choices.size() > 0:
		ending_choices_spawned.emit()

func _get_spawn_parent() -> Node:
	var station : Station = get_tree().get_first_node_in_group("station")
	return station.ending_choice_container

func _on_ending_chosen(ending_type: String) -> void:
	if ending_selected:
		return
		
	ending_selected = true
	DebugLogger.info(module_name, "Ending chosen: %s" % ending_type)
	
	# Clean up choice squares
	_cleanup_choices()
	
	# Emit signal
	ending_chosen.emit(ending_type)
	
	# Transition to ending scene
	await get_tree().create_timer(scene_transition_delay).timeout
	_play_ending(ending_type)

func _on_emergency_task_failed(task_id: String) -> void:
	# Check if it was the escape task
	if task_id == escape_task_id and not ending_selected:
		DebugLogger.info(module_name, "Escape task failed - triggering default ending")
		_on_ending_chosen("default")

func _play_ending(ending_type: String) -> void:
	var ending_scene: PackedScene = null
	
	match ending_type:
		"ending_a":
			ending_scene = alt_a_ending_scene
			DebugLogger.info(module_name, "Loading alternate ending A")
		"ending_b":
			ending_scene = alt_b_ending_scene
			DebugLogger.info(module_name, "Loading alternate ending B")
		_:
			ending_scene = default_ending_scene
			DebugLogger.info(module_name, "Loading default ending")
	
	if not ending_scene:
		DebugLogger.error(module_name, "No scene configured for ending: %s" % ending_type)
		return
		
	# Emit game ended signal
	game_ended.emit()
	
	# Change to ending scene
	get_tree().change_scene_to_packed(ending_scene)

func _cleanup_choices() -> void:
	for choice in spawned_choices:
		if is_instance_valid(choice):
			choice.queue_free()
	spawned_choices.clear()

# Public methods
func get_available_endings() -> Array[String]:
	var available: Array[String] = ["default"]  # Default is always available
	
	if task_manager:
		if task_manager.is_ending_path_available("ending_a"):
			available.append("alt_a")
		if task_manager.is_ending_path_available("ending_b"):
			available.append("alt_b")
			
	return available

func is_sequence_active() -> bool:
	return sequence_started and not ending_selected

func force_ending(ending_type: String) -> void:
	## Force a specific ending (useful for testing)
	if not ending_selected:
		_on_ending_chosen(ending_type)

func reset() -> void:
	## Reset the ending sequence (useful for testing)
	sequence_started = false
	ending_selected = false
	_cleanup_choices()
	
	if state_manager:
		state_manager.set_state("reality_collapse", false)
