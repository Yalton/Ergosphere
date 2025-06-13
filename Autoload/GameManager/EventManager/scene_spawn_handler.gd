# SceneSpawnerHandler.gd
extends EventHandler
class_name SceneSpawnerHandler

## Scene spawner event handler - spawns visual effects and objects at random locations

@export_group("Spawn Scene Categories")
## Subtle visual scenes - barely noticeable effects
@export var subtle_visual_scenes: Array[PackedScene] = []
## Jarring visual scenes - obvious, attention-grabbing effects
@export var jarring_visual_scenes: Array[PackedScene] = []
## Confusing visual scenes - reality-bending, disorienting effects
@export var confusing_visual_scenes: Array[PackedScene] = []

@export_group("Spawn Location Groups")
## Group name for subtle spawn points
@export var subtle_spawn_group: String = "subtle_spawn_points"
## Group name for jarring spawn points
@export var jarring_spawn_group: String = "jarring_spawn_points"
## Group name for confusing spawn points
@export var confusing_spawn_group: String = "confusing_spawn_points"

# Track spawned objects for cleanup
var spawned_objects: Array[Node] = []

func _ready() -> void:
	super._ready()
	module_name = "SceneSpawnerHandler"
	
	# Define which events this handler processes
	handled_event_ids = ["subtle_visual", "jarring_visual", "confusing_visual"]
	
	DebugLogger.debug(module_name, "SceneSpawnerHandler ready")

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	## Handle scene spawning event execution
	DebugLogger.info(module_name, "Executing visual spawn event: %s" % event_data.event_id)
	
	match event_data.event_id:
		"subtle_visual":
			_handle_subtle_visual(event_data, state_manager)
		"jarring_visual":
			_handle_jarring_visual(event_data, state_manager)
		"confusing_visual":
			_handle_confusing_visual(event_data, state_manager)

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	## Handle visual spawn event completion
	DebugLogger.info(module_name, "Completing visual spawn event: %s" % event_data.event_id)
	
	# Clean up any remaining spawned objects
	_cleanup_spawned_objects()

func _handle_subtle_visual(event_data: EventData, state_manager: StateManager) -> void:
	## Handle subtle visual spawning
	DebugLogger.debug(module_name, "Spawning subtle visual effect")
	
	_spawn_from_scene_pool(subtle_visual_scenes, subtle_spawn_group, "subtle visual")

func _handle_jarring_visual(event_data: EventData, state_manager: StateManager) -> void:
	## Handle jarring visual spawning
	DebugLogger.debug(module_name, "Spawning jarring visual effect")
	
	_spawn_from_scene_pool(jarring_visual_scenes, jarring_spawn_group, "jarring visual")
	
	# Optional hint for jarring effects
	if CommonUtils:
		var hints = [
			"Did you see that?",
			"Something moved in your peripheral vision...",
			"Was that always there?"
		]
		CommonUtils.send_player_hint("", hints[randi() % hints.size()])

func _handle_confusing_visual(event_data: EventData, state_manager: StateManager) -> void:
	## Handle confusing visual spawning
	DebugLogger.debug(module_name, "Spawning confusing visual effect")
	
	_spawn_from_scene_pool(confusing_visual_scenes, confusing_spawn_group, "confusing visual")
	
	# Unsettling hints for confusing effects
	if CommonUtils:
		var hints = [
			"The walls seem to shift and breathe...",
			"Reality bends at the edges of your vision.",
			"Nothing is as it appears.",
			"The station doesn't look quite right..."
		]
		CommonUtils.send_player_hint("", hints[randi() % hints.size()])

func _spawn_from_scene_pool(scene_pool: Array[PackedScene], spawn_group: String, category: String) -> void:
	## Spawn a random scene from the specified pool at a random spawn point
	if scene_pool.is_empty():
		DebugLogger.warning(module_name, "No scenes configured for %s pool" % category)
		return
	
	# Get spawn points from group
	var spawn_points = get_tree().get_nodes_in_group(spawn_group)
	if spawn_points.is_empty():
		DebugLogger.warning(module_name, "No spawn points found in group: %s" % spawn_group)
		return
	
	# Pick random scene and spawn point
	var random_scene = scene_pool[randi() % scene_pool.size()]
	var random_spawn_point = spawn_points[randi() % spawn_points.size()]
	
	_spawn_scene_at_location(random_scene, random_spawn_point, category)

func _spawn_scene_at_location(scene: PackedScene, spawn_point: Node, category: String) -> void:
	## Spawn a specific scene at a specific location
	if not scene:
		DebugLogger.warning(module_name, "Attempted to spawn null scene for %s category" % category)
		return
	
	if not spawn_point:
		DebugLogger.warning(module_name, "Invalid spawn point for %s category" % category)
		return
	
	# Instantiate the scene
	var spawned_instance = scene.instantiate()
	if not spawned_instance:
		DebugLogger.error(module_name, "Failed to instantiate %s scene: %s" % [category, scene.resource_path])
		return
	
	# Add to scene tree at spawn point location
	spawn_point.add_child(spawned_instance)
	
	# Set position if spawn point is a Node3D
	if spawn_point is Node3D and spawned_instance is Node3D:
		spawned_instance.global_position = spawn_point.global_position
		spawned_instance.global_rotation = spawn_point.global_rotation
	
	# Track spawned object for cleanup
	spawned_objects.append(spawned_instance)
	
	# Connect to cleanup signal if the spawned object supports it
	if spawned_instance.has_signal("cleanup_requested"):
		spawned_instance.cleanup_requested.connect(_on_spawned_object_cleanup_requested.bind(spawned_instance))
	
	# Set a fallback timer for cleanup if spawned object doesn't handle its own cleanup
	if not spawned_instance.has_method("handle_own_cleanup"):
		var cleanup_timer = get_tree().create_timer(30.0)  # 30 second fallback
		cleanup_timer.timeout.connect(_cleanup_specific_object.bind(spawned_instance))
	
	DebugLogger.info(module_name, "Spawned %s scene: %s at %s" % [category, scene.resource_path, spawn_point.name])

func _on_spawned_object_cleanup_requested(spawned_object: Node) -> void:
	## Called when a spawned object requests cleanup
	_cleanup_specific_object(spawned_object)

func _cleanup_specific_object(spawned_object: Node) -> void:
	## Clean up a specific spawned object
	if not is_instance_valid(spawned_object):
		return
	
	if spawned_object in spawned_objects:
		spawned_objects.erase(spawned_object)
	
	DebugLogger.debug(module_name, "Cleaning up spawned object: %s" % spawned_object.name)
	spawned_object.queue_free()

func _cleanup_spawned_objects() -> void:
	## Clean up all spawned objects
	DebugLogger.debug(module_name, "Cleaning up %d spawned objects" % spawned_objects.size())
	
	for spawned_object in spawned_objects:
		if is_instance_valid(spawned_object):
			spawned_object.queue_free()
	
	spawned_objects.clear()
