# object_throw.gd
extends EventHandler
class_name ObjectThrowEvent

## Throws the nearest rigidbody at the player with distance-based force

@export_group("Throw Settings")
## Maximum distance to search for objects to throw
@export var max_search_distance: float = 10.0
## Base force multiplier
@export var base_force: float = 5.0
## Maximum force multiplier (applied at max distance)  
@export var max_force: float = 15.0
## Sound to play when object is thrown
@export var throw_sound: AudioStream

func _ready() -> void:
	super._ready()
	module_name = "ObjectThrowEvent"
	
	# Events this handler processes
	handled_event_ids = ["object_throw", "poltergeist"]
	
	DebugLogger.debug(module_name, "ObjectThrowEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.warning(module_name, "No player found")
		return false
	
	# Check if there's a rigidbody nearby to throw
	var closest_body = _find_closest_rigidbody(player.global_position)
	if not closest_body:
		DebugLogger.debug(module_name, "No rigidbody found within range")
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	DebugLogger.debug(module_name, "Executing object throw event")
	
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.error(module_name, "No player found during execution")
		return false
	
	var closest_body = _find_closest_rigidbody(player.global_position)
	if not closest_body:
		DebugLogger.debug(module_name, "No rigidbody found to throw")
		return false
	
	_throw_object_at_player(closest_body, player.global_position)
	
	# End event after a short delay
	get_tree().create_timer(1.0).timeout.connect(func(): 
		if is_active:
			end()
	)
	
	return true

func end() -> void:
	DebugLogger.info(module_name, "Object throw event completed")
	
	# Call base implementation
	super.end()

func _find_closest_rigidbody(player_pos: Vector3) -> RigidBody3D:
	## Find the closest rigidbody within range
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
	## Recursively find all RigidBody3D nodes in the scene
	var bodies = []
	_recursive_find_rigidbodies(get_tree().root, bodies)
	return bodies

func _recursive_find_rigidbodies(node: Node, bodies: Array) -> void:
	## Helper for recursive search
	if node is RigidBody3D:
		bodies.append(node)
	
	for child in node.get_children():
		_recursive_find_rigidbodies(child, bodies)

func _throw_object_at_player(body: RigidBody3D, player_pos: Vector3) -> void:
	## Actually throw the object at the player
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
	
	# Play throw sound at object location
	if throw_sound:
		# Create 3D audio at object location
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = throw_sound
		audio_player.bus = "SFX"
		audio_player.max_distance = 20.0
		get_tree().current_scene.add_child(audio_player)
		audio_player.global_position = object_pos
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)
	
	DebugLogger.debug(module_name, "Threw object '%s' at distance %.2f with force %.2f" % [body.name, distance, force_multiplier])
