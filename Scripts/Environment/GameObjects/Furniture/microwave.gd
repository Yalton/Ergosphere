extends AwareGameObject
class_name Microwave

signal food_generated
signal door_opened
signal door_closed

@export_group("Microwave Settings")
## The food scene to spawn when eat_food task is assigned
@export var food_scene: PackedScene
## Where to spawn the food inside the microwave
@export var food_spawn_position: Node3D
## Animation player for door animations
@export var animation_player: AnimationPlayer
## Name of the door opening animation
@export var open_door_animation: String = "door_open"
## Name of the door closing animation
@export var close_door_animation: String = "door_close"

@export_group("Task Settings")
## The task ID for eating food
@export var eat_food_task_id: String = "eat_food"

@export_group("Testing")
## Enable test mode to generate food after delay
@export var test_mode: bool = false
## Delay before generating food in test mode
@export var test_delay: float = 5.0

# State tracking
var door_open: bool = false
var current_food: Node3D = null

func _ready() -> void:
	super._ready()
	module_name = "Microwave"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Ensure we have a spawn position
	if not food_spawn_position:
		food_spawn_position = Node3D.new()
		food_spawn_position.name = "FoodSpawnPosition"
		add_child(food_spawn_position)
		food_spawn_position.position = Vector3(0, 0.1, 0)
		DebugLogger.warning(module_name, "No food spawn position assigned, created default")
	
	# Set up task aware component
	if task_aware_component:
		task_aware_component.associated_task_id = eat_food_task_id
		task_aware_component.associated_task_assigned.connect(_on_eat_food_task_assigned)
		DebugLogger.debug(module_name, "Connected to task aware component")
	
	DebugLogger.debug(module_name, "Microwave initialized")
	
	# Test mode
	if test_mode:
		DebugLogger.info(module_name, "Test mode enabled - will generate food in " + str(test_delay) + " seconds")
		var test_timer = get_tree().create_timer(test_delay)
		test_timer.timeout.connect(generate_food)

func _on_eat_food_task_assigned(task_id: String) -> void:
	DebugLogger.info(module_name, "Eat food task assigned, generating food")
	generate_food()

func generate_food() -> void:
	if not food_scene:
		DebugLogger.error(module_name, "No food scene assigned")
		return
	
	if current_food:
		DebugLogger.warning(module_name, "Food already present, removing old food")
		current_food.queue_free()
		current_food = null
	
	DebugLogger.info(module_name, "Generating food")
	
	# Spawn the food
	current_food = food_scene.instantiate()
	get_tree().current_scene.add_child(current_food)
	current_food.global_position = food_spawn_position.global_position
	
	# Connect to food's tree_exiting signal
	if not current_food.is_connected("tree_exiting", _on_food_removed):
		current_food.tree_exiting.connect(_on_food_removed)
	
	# Open the door
	_open_door()
	
	# Emit signal
	food_generated.emit()

func _open_door() -> void:
	if door_open:
		return
	
	door_open = true
	
	if animation_player and animation_player.has_animation(open_door_animation):
		animation_player.play(open_door_animation)
		DebugLogger.debug(module_name, "Playing door open animation")
	else:
		DebugLogger.warning(module_name, "No animation player or animation found")
	
	DebugLogger.info(module_name, "Door opened")
	door_opened.emit()

func _close_door() -> void:
	if not door_open:
		return
	
	door_open = false
	
	if animation_player and animation_player.has_animation(close_door_animation):
		animation_player.play(close_door_animation)
		DebugLogger.debug(module_name, "Playing door close animation")
	
	DebugLogger.info(module_name, "Door closed")
	door_closed.emit()

func _on_food_removed() -> void:
	DebugLogger.info(module_name, "Food was removed")
	current_food = null
	
	# Complete the task if it's active
	task_aware_component.complete_task()
	
	# Close door after delay
	var close_timer = get_tree().create_timer(0.5)
	close_timer.timeout.connect(_close_door)
