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
	# Define which events this handler processes
	handled_event_ids = ["micro_blackhole", "dark_fog", "entity_appearance", "scene_spawn"]

func _can_execute_internal() -> Dictionary:
	# Check if we have a scene for this event
	match event_data.id:
		"micro_blackhole":
			if not micro_blackhole_scene:
				return {"success": false, "message": "No micro blackhole scene configured"}
		"dark_fog":
			if not dark_fog_scene:
				return {"success": false, "message": "No dark fog scene configured"}
		"entity_appearance":
			if not entity_appearance_scene:
				return {"success": false, "message": "No entity appearance scene configured"}
	
	# Check if spawn points exist
	var spawn_points = get_tree().get_nodes_in_group(spawn_group)
	if spawn_points.is_empty():
		return {"success": false, "message": "No spawn points found in group: " + spawn_group}
	
	return {"success": true, "message": "OK"}

func _execute_internal() -> Dictionary:
	match event_data.id:
		"micro_blackhole":
			return _handle_micro_blackhole()
		"dark_fog":
			return _handle_dark_fog()
		"entity_appearance":
			return _handle_entity_appearance()
		_:
			return {"success": false, "message": "Unknown event ID: " + event_data.id}

func end() -> void:
	# Clean up all spawned objects
	_cleanup_spawned_objects()
	
	# Call base implementation
	super.end()

func _handle_micro_blackhole() -> Dictionary:
	## Handle micro blackhole spawning
	return _spawn_vfx_scene(micro_blackhole_scene, "micro_blackhole")

func _handle_dark_fog() -> Dictionary:
	## Handle dark fog spawning
	return _spawn_vfx_scene(dark_fog_scene, "dark_fog")

func _handle_entity_appearance() -> Dictionary:
	## Handle entity appearance spawning
	return _spawn_vfx_scene(entity_appearance_scene, "entity_appearance")

func _spawn_vfx_scene(scene: PackedScene, event_id: String) -> Dictionary:
	## Spawn a specific VFX scene at a random off-screen spawn point
	if not scene:
		return {"success": false, "message": "No scene configured for " + event_id + " event"}
	
	# Get spawn points from group
	var spawn_points = get_tree().get_nodes_in_group(spawn_group)
	if spawn_points.is_empty():
		return {"success": false, "message": "No spawn points found in group: " + spawn_group}
	
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
		# Use any spawn point if no off-screen ones available
		offscreen_points = spawn_points
	
	# Select spawn point based on distance to player if enabled
	var spawn_point: Node
	if prefer_closest_to_player and player and player is Node3D:
		spawn_point = _get_closest_spawn_point(offscreen_points, player)
	else:
		# Pick random spawn point
		spawn_point = offscreen_points[randi() % offscreen_points.size()]
	
	return _spawn_scene_at_location(scene, spawn_point, event_id)

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
	
	return distances[selected_index].point

func _spawn_scene_at_location(scene: PackedScene, spawn_point: Node, event_id: String) -> Dictionary:
	## Spawn a specific scene at a specific location
	if not spawn_point:
		return {"success": false, "message": "Invalid spawn point for " + event_id + " event"}
	
	# Instantiate the scene
	var spawned_instance = scene.instantiate()
	if not spawned_instance:
		return {"success": false, "message": "Failed to instantiate " + event_id + " scene: " + scene.resource_path}
	
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
	
	return {"success": true, "message": "OK"}

func _on_spawned_object_cleanup_requested(spawned_object: Node) -> void:
	## Called when a spawned object requests cleanup
	_cleanup_specific_object(spawned_object)

func _cleanup_specific_object(spawned_object: Node) -> void:
	## Clean up a specific spawned object
	if not is_instance_valid(spawned_object):
		return
	
	if spawned_object in spawned_objects:
		spawned_objects.erase(spawned_object)
	
	spawned_object.queue_free()

func _cleanup_spawned_objects() -> void:
	## Clean up all spawned objects
	for spawned_object in spawned_objects:
		if is_instance_valid(spawned_object):
			spawned_object.queue_free()
	
	spawned_objects.clear()
