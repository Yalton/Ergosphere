# SceneSpawnerHandler.gd
extends EventHandler
class_name SceneSpawnerHandler

## Scene spawner event handler - spawns specific visual effects at random locations

@export_group("Visual Effect Scenes")
## VFX scene for shadow_figure event
@export var shadow_figure_scene: PackedScene
## VFX scene for flickering_lights event
@export var flickering_lights_scene: PackedScene
## VFX scene for floating_objects event
@export var floating_objects_scene: PackedScene
## VFX scene for mysterious_fog event
@export var mysterious_fog_scene: PackedScene
## VFX scene for reality_glitch event
@export var reality_glitch_scene: PackedScene

@export_group("Spawn Settings")
## Group name for spawn points (all events use same pool)
@export var spawn_group: String = "fx_spawn_points"

# Track spawned objects for cleanup
var spawned_objects: Array[Node] = []

func _ready() -> void:
	super._ready()
	module_name = "SceneSpawnerHandler"
	
	# Define which events this handler processes
	handled_event_ids = ["shadow_figure", "flickering_lights", "floating_objects", "mysterious_fog", "reality_glitch"]
	
	DebugLogger.debug(module_name, "SceneSpawnerHandler ready")

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	## Handle scene spawning event execution
	DebugLogger.info(module_name, "Executing VFX spawn event: %s" % event_data.event_id)
	
	match event_data.event_id:
		"shadow_figure":
			_handle_shadow_figure(event_data, state_manager)
		"flickering_lights":
			_handle_flickering_lights(event_data, state_manager)
		"floating_objects":
			_handle_floating_objects(event_data, state_manager)
		"mysterious_fog":
			_handle_mysterious_fog(event_data, state_manager)
		"reality_glitch":
			_handle_reality_glitch(event_data, state_manager)

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	## Handle VFX spawn event completion
	DebugLogger.info(module_name, "Completing VFX spawn event: %s" % event_data.event_id)
	
	# VFX scenes handle their own cleanup, but we can force cleanup here if needed
	# _cleanup_spawned_objects()

func _handle_shadow_figure(event_data: EventData, state_manager: StateManager) -> void:
	## Handle shadow figure spawning
	DebugLogger.debug(module_name, "Spawning shadow figure VFX")
	
	_spawn_vfx_scene(shadow_figure_scene, "shadow_figure")
	
	# Optional atmospheric hint
	if CommonUtils and randf() < 0.5:
		CommonUtils.send_player_hint("", "A shadow moves in the corner of your eye...")

func _handle_flickering_lights(event_data: EventData, state_manager: StateManager) -> void:
	## Handle flickering lights spawning
	DebugLogger.debug(module_name, "Spawning flickering lights VFX")
	
	_spawn_vfx_scene(flickering_lights_scene, "flickering_lights")

func _handle_floating_objects(event_data: EventData, state_manager: StateManager) -> void:
	## Handle floating objects spawning
	DebugLogger.debug(module_name, "Spawning floating objects VFX")
	
	_spawn_vfx_scene(floating_objects_scene, "floating_objects")
	
	# Unsettling hint
	if CommonUtils:
		CommonUtils.send_player_hint("", "Objects defy gravity around you...")

func _handle_mysterious_fog(event_data: EventData, state_manager: StateManager) -> void:
	## Handle mysterious fog spawning
	DebugLogger.debug(module_name, "Spawning mysterious fog VFX")
	
	_spawn_vfx_scene(mysterious_fog_scene, "mysterious_fog")
	
	# Atmospheric hint
	if CommonUtils:
		CommonUtils.send_player_hint("", "An unnatural mist fills the air...")

func _handle_reality_glitch(event_data: EventData, state_manager: StateManager) -> void:
	## Handle reality glitch spawning
	DebugLogger.debug(module_name, "Spawning reality glitch VFX")
	
	_spawn_vfx_scene(reality_glitch_scene, "reality_glitch")
	
	# Reality-bending hint
	if CommonUtils:
		CommonUtils.send_player_hint("", "Reality fractures at the edges...")

func _spawn_vfx_scene(scene: PackedScene, event_id: String) -> void:
	## Spawn a specific VFX scene at a random spawn point
	if not scene:
		DebugLogger.warning(module_name, "No scene configured for %s event" % event_id)
		return
	
	# Get spawn points from group
	var spawn_points = get_tree().get_nodes_in_group(spawn_group)
	if spawn_points.is_empty():
		DebugLogger.warning(module_name, "No spawn points found in group: %s" % spawn_group)
		return
	
	# Pick random spawn point
	var random_spawn_point = spawn_points[randi() % spawn_points.size()]
	
	_spawn_scene_at_location(scene, random_spawn_point, event_id)

func _spawn_scene_at_location(scene: PackedScene, spawn_point: Node, event_id: String) -> void:
	## Spawn a specific scene at a specific location
	if not spawn_point:
		DebugLogger.warning(module_name, "Invalid spawn point for %s event" % event_id)
		return
	
	# Instantiate the scene
	var spawned_instance = scene.instantiate()
	if not spawned_instance:
		DebugLogger.error(module_name, "Failed to instantiate %s scene: %s" % [event_id, scene.resource_path])
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
	
	DebugLogger.info(module_name, "Spawned %s VFX at %s" % [event_id, spawn_point.name])

func _on_spawned_object_cleanup_requested(spawned_object: Node) -> void:
	## Called when a spawned object requests cleanup
	_cleanup_specific_object(spawned_object)

func _cleanup_specific_object(spawned_object: Node) -> void:
	## Clean up a specific spawned object
	if not is_instance_valid(spawned_object):
		return
	
	if spawned_object in spawned_objects:
		spawned_objects.erase(spawned_object)
	
	DebugLogger.debug(module_name, "Cleaning up spawned VFX: %s" % spawned_object.name)
	spawned_object.queue_free()

func _cleanup_spawned_objects() -> void:
	## Clean up all spawned objects
	DebugLogger.debug(module_name, "Cleaning up %d spawned VFX objects" % spawned_objects.size())
	
	for spawned_object in spawned_objects:
		if is_instance_valid(spawned_object):
			spawned_object.queue_free()
	
	spawned_objects.clear()
