# scene_spawn.gd
extends EventHandler
class_name SceneSpawnEvent

## Scene spawner event handler - spawns specific visual effects at random locations only on off-screen spawn points

@export_group("Visual Effect Scenes")
## VFX scene for micro_blackhole event
@export var micro_blackhole_scene: PackedScene
## VFX scene for dark_fog event
@export var dark_fog_scene: PackedScene
## VFX scene for entity_appearance event
@export var entity_appearance_scene: PackedScene

@export_group("Spawn Settings")
## Group name for spawn points (all events use same pool)
@export var spawn_group: String = "fx_spawn_points"
## Whether to prefer spawn points closest to player
@export var prefer_closest_to_player: bool = true
## Maximum number of closest points to randomly select from
@export var closest_points_pool_size: int = 3

# Track spawned objects for cleanup
var spawned_objects: Array[Node] = []

func _ready() -> void:
	module_name = "SceneSpawnEvent"
	super._ready()
	
	# Define which events this handler processes
	handled_event_ids = ["micro_blackhole", "dark_fog", "entity_appearance", "scene_spawn"]
	

	DebugLogger.debug(module_name, "SceneSpawnEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	# Check if we have a scene for this event
	match event_data.id:
		"micro_blackhole":
			if not micro_blackhole_scene:
				DebugLogger.warning(module_name, "No micro blackhole scene configured")
				return false
		"dark_fog":
			if not dark_fog_scene:
				DebugLogger.warning(module_name, "No dark fog scene configured")
				return false
		"entity_appearance":
			if not entity_appearance_scene:
				DebugLogger.warning(module_name, "No entity appearance scene configured")
				return false
	
	# Check if spawn points exist
	var spawn_points = get_tree().get_nodes_in_group(spawn_group)
	if spawn_points.is_empty():
		DebugLogger.warning(module_name, "No spawn points found in group: %s" % spawn_group)
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	DebugLogger.info(module_name, "Executing VFX spawn event: %s" % event_data.id)
	
	match event_data.id:
		"micro_blackhole":
			_handle_micro_blackhole()
		"dark_fog":
			_handle_dark_fog()
		"entity_appearance":
			_handle_entity_appearance()
		_:
			DebugLogger.warning(module_name, "Unknown event ID: %s" % event_data.id)
			return false
	
	return true

func end() -> void:
	# Clean up all spawned objects
	_cleanup_spawned_objects()
	
	DebugLogger.info(module_name, "VFX spawn event completed: %s" % event_data.id)
	
	# Call base implementation
	super.end()

func _handle_micro_blackhole() -> void:
	## Handle micro blackhole spawning
	DebugLogger.debug(module_name, "Spawning micro blackhole VFX")
	_spawn_vfx_scene(micro_blackhole_scene, "micro_blackhole")

func _handle_dark_fog() -> void:
	## Handle dark fog spawning
	DebugLogger.debug(module_name, "Spawning dark fog VFX")
	_spawn_vfx_scene(dark_fog_scene, "dark_fog")

func _handle_entity_appearance() -> void:
	## Handle entity appearance spawning
	DebugLogger.debug(module_name, "Spawning entity appearance VFX")
	_spawn_vfx_scene(entity_appearance_scene, "entity_appearance")

func _spawn_vfx_scene(scene: PackedScene, event_id: String) -> void:
	## Spawn a specific VFX scene at a random off-screen spawn point
	if not scene:
		DebugLogger.warning(module_name, "No scene configured for %s event" % event_id)
		return
	
	# Get spawn points from group
	var spawn_points = get_tree().get_nodes_in_group(spawn_group)
	if spawn_points.is_empty():
		DebugLogger.warning(module_name, "No spawn points found in group: %s" % spawn_group)
		return
	
	# Get player reference
	var player = get_tree().get_first_node_in_group("player")
	
	# Filter to only off-screen VFXSpawnPoints
	var offscreen_points = []
	for point in spawn_points:
		if point.has_method("is_on_screen") and not point.is_on_screen:
			offscreen_points.append(point)
		else:
			# If not a VFXSpawnPoint, assume it's valid
			offscreen_points.append(point)
	
	if offscreen_points.is_empty():
		DebugLogger.warning(module_name, "No off-screen spawn points available - using any spawn point")
		offscreen_points = spawn_points
	
	# Select spawn point based on distance to player if enabled
	var spawn_point: Node
	if prefer_closest_to_player and player and player is Node3D:
		spawn_point = _get_closest_spawn_point(offscreen_points, player)
	else:
		# Pick random spawn point
		spawn_point = offscreen_points[randi() % offscreen_points.size()]
	
	_spawn_scene_at_location(scene, spawn_point, event_id)

func _get_closest_spawn_point(points: Array, player: Node3D) -> Node:
	## Get spawn point closest to player (or randomly from closest few)
	if points.is_empty():
		return null
	
	# Calculate distances for all points
	var distances = []
	for point in points:
		if point is Node3D:
			var distance = point.global_position.distance_to(player.global_position)
			distances.append({"point": point, "distance": distance})
	
	# Sort by distance
	distances.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Select from the closest few points
	var pool_size = min(closest_points_pool_size, distances.size())
	var selected_index = randi() % pool_size
	
	var selected = distances[selected_index]
	DebugLogger.debug(module_name, "Selected spawn point at distance %.1f from player" % selected.distance)
	
	return selected.point

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
