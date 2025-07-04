# EndingSequenceManager.gd
extends Node
class_name EndingSequenceManager

signal ending_sequence_started()
signal ending_choices_spawned()
signal ending_chosen(ending_type: String)

@export var enable_debug: bool = true
var module_name: String = "EndingSequenceManager"

@export_group("Ending Configuration")
## Day number that triggers the ending sequence
@export var final_day: int = 7
## Delay before starting escape sequence after all tasks complete
@export var sequence_delay: float = 5.0
## Emergency task ID for the escape sequence
@export var escape_task_id: String = "escape_inevitable"

@export_group("Ending Choice Scenes")
## Scene for ending A choice square (must have InteractionComponent + EndingChoiceComponent)
@export var ending_a_scene: PackedScene
## Scene for ending B choice square
@export var ending_b_scene: PackedScene
## Where to spawn the choice squares
@export var ending_a_spawn_pos: Vector3 = Vector3(-5, 0, 0)
@export var ending_b_spawn_pos: Vector3 = Vector3(5, 0, 0)
## Parent node path for spawned objects
@export var spawn_parent_path: NodePath = ""

var sequence_started: bool = false
var spawned_choices: Array[Node] = []

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect to task manager signals
	if GameManager.task_manager:
		GameManager.task_manager.daily_tasks_completed.connect(_on_daily_tasks_completed)
		GameManager.task_manager.ending_chosen.connect(_on_ending_chosen)

func _on_daily_tasks_completed() -> void:
	# Check if this is the final day
	if GameManager.task_manager.current_day != final_day:
		return
	
	if sequence_started:
		return
	
	DebugLogger.info(module_name, "Final day tasks completed! Starting ending sequence in %d seconds..." % sequence_delay)
	
	# Start the ending sequence after delay
	sequence_started = true
	await get_tree().create_timer(sequence_delay).timeout
	_start_ending_sequence()

func _start_ending_sequence() -> void:
	DebugLogger.info(module_name, "Starting ending sequence!")
	
	# Set state for reality collapse
	GameManager.state_manager.set_state("reality_collapse", true)
	
	# Trigger the escape emergency task
	GameManager.task_manager.trigger_emergency_task(escape_task_id)
	
	# Spawn ending choices based on completed paths
	_spawn_ending_choices()
	
	ending_sequence_started.emit()

func _spawn_ending_choices() -> void:
	var parent = _get_spawn_parent()
	
	# Check which endings are available
	var ending_a_available = GameManager.task_manager.is_ending_path_available("ending_a")
	var ending_b_available = GameManager.task_manager.is_ending_path_available("ending_b")
	
	if not ending_a_available and not ending_b_available:
		DebugLogger.info(module_name, "No secret endings available - default ending will play")
		return
	
	# Spawn ending A choice if available
	if ending_a_available and ending_a_scene:
		var choice_a = ending_a_scene.instantiate()
		parent.add_child(choice_a)
		
		if choice_a is Node3D:
			choice_a.position = ending_a_spawn_pos
		elif choice_a is Node2D:
			choice_a.position = Vector2(ending_a_spawn_pos.x, ending_a_spawn_pos.y)
		
		spawned_choices.append(choice_a)
		DebugLogger.info(module_name, "Spawned ending A choice")
	
	# Spawn ending B choice if available
	if ending_b_available and ending_b_scene:
		var choice_b = ending_b_scene.instantiate()
		parent.add_child(choice_b)
		
		if choice_b is Node3D:
			choice_b.position = ending_b_spawn_pos
		elif choice_b is Node2D:
			choice_b.position = Vector2(ending_b_spawn_pos.x, ending_b_spawn_pos.y)
		
		spawned_choices.append(choice_b)
		DebugLogger.info(module_name, "Spawned ending B choice")
	
	ending_choices_spawned.emit()

func _get_spawn_parent() -> Node:
	if spawn_parent_path.is_empty():
		return get_tree().root
	
	var parent = get_node(spawn_parent_path)
	if not parent:
		DebugLogger.warning(module_name, "Spawn parent not found, using root")
		return get_tree().root
	
	return parent

func _on_ending_chosen(ending_type: String) -> void:
	DebugLogger.info(module_name, "Ending chosen: %s" % ending_type)
	
	# Clean up choice squares
	for choice in spawned_choices:
		if is_instance_valid(choice):
			choice.queue_free()
	spawned_choices.clear()
	
	# Emit signal for other systems to handle cutscene
	ending_chosen.emit(ending_type)
	
	# You could trigger cutscene directly here or let another system handle it
	_play_ending_cutscene(ending_type)

func _play_ending_cutscene(ending_type: String) -> void:
	# This is where you'd trigger the appropriate cutscene
	match ending_type:
		"ending_a":
			DebugLogger.info(module_name, "Playing ending A cutscene")
			# GameManager.cutscene_manager.play_cutscene("ending_a")
		"ending_b":
			DebugLogger.info(module_name, "Playing ending B cutscene")
			# GameManager.cutscene_manager.play_cutscene("ending_b")
		_:
			DebugLogger.info(module_name, "Playing default ending cutscene")
			# GameManager.cutscene_manager.play_cutscene("ending_default")

func get_available_endings() -> Array[String]:
	return GameManager.task_manager.get_available_endings()

func reset() -> void:
	sequence_started = false
	for choice in spawned_choices:
		if is_instance_valid(choice):
			choice.queue_free()
	spawned_choices.clear()
