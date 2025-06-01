extends Node3D
class_name Microwave

signal food_generated
signal door_opened
signal door_closed

@export_group("Microwave Settings")
@export var food_scene: PackedScene  # The food scene to spawn
@export var food_spawn_position: Node3D  # Where to spawn the food
@export var animation_player: AnimationPlayer
@export var open_door_animation: String = "door_open"
@export var close_door_animation: String = "door_close"

@export_group("Testing")
@export var test_mode: bool = true
@export var test_delay: float = 5.0

@export var enable_debug: bool = true
var module_name: String = "Microwave"

# State tracking
var door_open: bool = false
var current_food: Node3D = null

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Ensure we have a spawn position
	if not food_spawn_position:
		food_spawn_position = Node3D.new()
		food_spawn_position.name = "FoodSpawnPosition"
		add_child(food_spawn_position)
		food_spawn_position.position = Vector3(0, 0.1, 0)  # Slightly above microwave floor
		DebugLogger.warning(module_name, "No food spawn position assigned, created default")
	
	DebugLogger.debug(module_name, "Microwave initialized")
	
	# Test mode - generate food after delay
	if test_mode:
		DebugLogger.info(module_name, "Test mode enabled - will generate food in " + str(test_delay) + " seconds")
		var test_timer = get_tree().create_timer(test_delay)
		test_timer.timeout.connect(generate_food)

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
	
	# Connect to food's tree_exiting signal to know when it's consumed
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
	
	# Play open animation
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
	
	# Play close animation
	if animation_player and animation_player.has_animation(close_door_animation):
		animation_player.play(close_door_animation)
		DebugLogger.debug(module_name, "Playing door close animation")
	
	DebugLogger.info(module_name, "Door closed")
	door_closed.emit()

func _on_food_removed() -> void:
	DebugLogger.info(module_name, "Food was removed")
	current_food = null
	
	# Close door after a short delay
	var close_timer = get_tree().create_timer(0.5)
	close_timer.timeout.connect(_close_door)
