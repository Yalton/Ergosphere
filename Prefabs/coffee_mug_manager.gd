# CoffeeMugManager.gd
extends Node
class_name CoffeeMugManager

## Minimum number of coffee mugs to spawn
@export var min_mugs: int = 1

## Maximum number of coffee mugs to spawn
@export var max_mugs: int = 3

## Minimum time between mug scatters (seconds)
@export var min_scatter_interval: float = 30.0

## Maximum time between mug scatters (seconds)
@export var max_scatter_interval: float = 120.0

## Coffee mug scene to spawn
@export var coffee_mug_scene: PackedScene

## Reference to the player detection system
@export var player_detection: PlayerDetection

# Internal
var module_name: String = "CoffeeMugManager"
var enable_debug: bool = true
var active_mugs: Dictionary = {} # spawn_point: mug_instance
var scatter_timer: Timer
var current_player_room: String = ""

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect to player detection system
	if player_detection:
		player_detection.player_in_room.connect(_on_player_room_changed)
	else:
		DebugLogger.error(module_name, "PlayerDetection reference not set!")
	
	# Initial spawn
	_spawn_initial_mugs()
	
	# Setup scatter timer
	_setup_scatter_timer()
	
	var spawn_points = get_tree().get_nodes_in_group("coffee_mug_spawn_points")
	DebugLogger.info(module_name, "Coffee mug system initialized with " + str(spawn_points.size()) + " spawn points")

func _spawn_initial_mugs() -> void:
	var spawn_points = get_tree().get_nodes_in_group("coffee_mug_spawn_points")
	var num_mugs = randi_range(min_mugs, max_mugs)
	var available_points = spawn_points.duplicate()
	var used_rooms: Array[String] = []
	
	for i in range(num_mugs):
		if available_points.is_empty():
			break
			
		# Pick random spawn point
		var idx = randi() % available_points.size()
		var spawn_point = available_points[idx]
		
		# Check if room already has a mug
		if spawn_point.room_tag in used_rooms:
			available_points.erase(spawn_point)
			continue
		
		# Spawn mug
		_spawn_mug_at_point(spawn_point)
		used_rooms.append(spawn_point.room_tag)
		available_points.erase(spawn_point)
	
	DebugLogger.info(module_name, "Spawned " + str(active_mugs.size()) + " initial mugs")

func _spawn_mug_at_point(spawn_point: CoffeeMugSpawnPoint) -> void:
	if not coffee_mug_scene:
		DebugLogger.error(module_name, "Coffee mug scene not set!")
		return
		
	var mug = coffee_mug_scene.instantiate()
	spawn_point.add_child(mug)
	mug.position = Vector3.ZERO
	mug.rotation = Vector3.ZERO
	
	# Connect to mug's broken signal
	mug.mug_broken.connect(_on_mug_broken.bind(spawn_point))
	
	active_mugs[spawn_point] = mug
	
	DebugLogger.debug(module_name, "Spawned mug in room: " + spawn_point.room_tag)

func _on_mug_broken(spawn_point: CoffeeMugSpawnPoint) -> void:
	DebugLogger.info(module_name, "Mug broken in room: " + spawn_point.room_tag)
	active_mugs.erase(spawn_point)

func _setup_scatter_timer() -> void:
	scatter_timer = Timer.new()
	scatter_timer.one_shot = true
	scatter_timer.timeout.connect(_scatter_mugs)
	add_child(scatter_timer)
	_start_scatter_timer()

func _start_scatter_timer() -> void:
	var wait_time = randf_range(min_scatter_interval, max_scatter_interval)
	scatter_timer.wait_time = wait_time
	scatter_timer.start()
	
	DebugLogger.debug(module_name, "Next scatter in " + str(wait_time) + " seconds")

func _scatter_mugs() -> void:
	DebugLogger.info(module_name, "Scattering mugs. Player in room: " + current_player_room)
	
	# Remove mugs not in player's room
	var mugs_to_remove: Array[CoffeeMugSpawnPoint] = []
	for spawn_point in active_mugs:
		if spawn_point.room_tag != current_player_room:
			mugs_to_remove.append(spawn_point)
	
	for spawn_point in mugs_to_remove:
		var mug = active_mugs[spawn_point]
		if is_instance_valid(mug):
			mug.queue_free()
		active_mugs.erase(spawn_point)
	
	# Spawn new mugs
	var num_mugs = randi_range(min_mugs, max_mugs)
	var available_points: Array[CoffeeMugSpawnPoint] = []
	var used_rooms: Array[String] = []
	
	# Collect currently used rooms (excluding player's room)
	for spawn_point in active_mugs:
		used_rooms.append(spawn_point.room_tag)
	
	# Find available spawn points
	var spawn_points = get_tree().get_nodes_in_group("coffee_mug_spawn_points")
	for spawn_point in spawn_points:
		if spawn_point.room_tag != current_player_room and spawn_point not in active_mugs:
			available_points.append(spawn_point)
	
	# Spawn new mugs
	var mugs_spawned = 0
	while mugs_spawned < num_mugs and not available_points.is_empty():
		var idx = randi() % available_points.size()
		var spawn_point = available_points[idx]
		
		# Check if room already has a mug
		if spawn_point.room_tag in used_rooms:
			available_points.erase(spawn_point)
			continue
		
		_spawn_mug_at_point(spawn_point)
		used_rooms.append(spawn_point.room_tag)
		available_points.erase(spawn_point)
		mugs_spawned += 1
	
	DebugLogger.info(module_name, "Scatter complete. Active mugs: " + str(active_mugs.size()))
	
	# Restart timer
	_start_scatter_timer()

func _on_player_room_changed(room_id: String) -> void:
	current_player_room = room_id
	DebugLogger.debug(module_name, "Player entered room: " + room_id)
