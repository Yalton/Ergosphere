# ObjectThrowEvent.gd
extends EventHandler
class_name ObjectThrowEvent

## Throws the nearest rigidbody at the player with distance-based force



## Maximum distance to search for objects to throw
@export var max_search_distance: float = 10.0
## Base force multiplier
@export var base_force: float = 5.0
## Maximum force multiplier (applied at max distance)  
@export var max_force: float = 15.0

func _ready() -> void:
	module_name = "ObjectThrowEvent"
	super._ready()
	DebugLogger.register_module(module_name)
	
	# Events this handler processes
	handled_event_ids = ["object_throw"]

func _on_execute(event_data: EventData, state_manager: StateManager) -> void:
	DebugLogger.debug(module_name, "Executing object throw event")
	
	var player = _find_player_node()
	if not player:
		DebugLogger.error(module_name, "No player found")
		return
	
	var closest_body = _find_closest_rigidbody(player.global_position)
	if not closest_body:
		DebugLogger.debug(module_name, "No rigidbody found to throw")
		return
	
	_throw_object_at_player(closest_body, player.global_position)

func _find_player_node() -> Node3D:
	return CommonUtils.get_player()

func _find_closest_rigidbody(player_pos: Vector3) -> RigidBody3D:
	var closest_body: RigidBody3D = null
	var closest_distance: float = max_search_distance
	
	# Get all rigidbodies in scene
	var bodies = get_tree().get_nodes_in_group("rigidbody")
	if bodies.is_empty():
		# Fallback - search all RigidBody3D nodes
		bodies = _find_all_rigidbodies()
	
	for body in bodies:
		if body is RigidBody3D:
			var distance = player_pos.distance_to(body.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_body = body
	
	return closest_body

func _find_all_rigidbodies() -> Array:
	var bodies = []
	_recursive_find_rigidbodies(get_tree().root, bodies)
	return bodies

func _recursive_find_rigidbodies(node: Node, bodies: Array) -> void:
	if node is RigidBody3D:
		bodies.append(node)
	
	for child in node.get_children():
		_recursive_find_rigidbodies(child, bodies)

func _throw_object_at_player(body: RigidBody3D, player_pos: Vector3) -> void:
	var object_pos = body.global_position
	var distance = object_pos.distance_to(player_pos)
	
	# Calculate force based on distance - more distance = more force
	var force_multiplier = lerp(base_force, max_force, distance / max_search_distance)
	
	# Direction from object to player
	var throw_direction = (player_pos - object_pos).normalized()
	
	# Add slight upward component so it doesn't just slide on ground
	throw_direction.y += 0.3
	throw_direction = throw_direction.normalized()
	
	# Apply force
	var force_vector = throw_direction * force_multiplier
	body.apply_central_impulse(force_vector)
	
	DebugLogger.debug(module_name, "Threw object at distance %.2f with force %.2f" % [distance, force_multiplier])

func _on_complete(event_data: EventData, state_manager: StateManager) -> void:
	DebugLogger.debug(module_name, "Object throw event completed")
