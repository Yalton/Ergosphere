# object_levitate.gd
extends EventHandler
class_name ObjectLevitateEvent

## Levitates the nearest rigidbody for 5-10 seconds to freak out the player

@export_group("Levitate Settings")
## Maximum distance to search for objects to levitate
@export var max_search_distance: float = 10.0
## Upward force to counteract gravity and lift object
@export var lift_force: float = 15.0
## Force to maintain hovering (multiplier on gravity compensation)
@export var hover_force_multiplier: float = 1.1
## Height to levitate object above its starting position
@export var levitate_height: float = 2.0
## Base hold time (seconds) - will be randomized between 5-10
@export var min_hold_time: float = 5.0
@export var max_hold_time: float = 10.0
## Sound to play when object starts levitating
@export var levitate_sound: AudioStream

var levitating_body: RigidBody3D = null
var original_gravity_scale: float = 1.0
var start_position: Vector3
var target_height: float
var hold_timer: float = 0.0
var is_levitating: bool = false

func _ready() -> void:
	super._ready()
	module_name = "ObjectLevitateEvent"
	
	# Events this handler processes
	handled_event_ids = ["object_levitate", "levitation", "telekinesis"]
	
	DebugLogger.debug(module_name, "ObjectLevitateEvent ready")

func can_execute() -> bool:
	# First check base requirements
	if not super.can_execute():
		return false
	
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.warning(module_name, "No player found")
		return false
	
	# Check if there's a rigidbody nearby to levitate
	var closest_body = _find_closest_rigidbody(player.global_position)
	if not closest_body:
		DebugLogger.debug(module_name, "No rigidbody found within range")
		return false
	
	return true

func execute() -> bool:
	# Call base implementation
	if not super.execute():
		return false
	
	DebugLogger.debug(module_name, "Executing object levitate event")
	
	var player = CommonUtils.get_player()
	if not player:
		DebugLogger.error(module_name, "No player found during execution")
		return false
	
	var closest_body = _find_closest_rigidbody(player.global_position)
	if not closest_body:
		DebugLogger.debug(module_name, "No rigidbody found to levitate")
		return false
	
	# Set up levitation
	levitating_body = closest_body
	start_position = levitating_body.global_position
	target_height = start_position.y + levitate_height
	
	# Store original gravity scale
	if levitating_body.has_property("gravity_scale"):
		original_gravity_scale = levitating_body.gravity_scale
	
	# Calculate hold time
	hold_timer = randf_range(min_hold_time, max_hold_time)
	
	# Play levitate sound at object location
	if levitate_sound:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = levitate_sound
		audio_player.bus = "SFX"
		audio_player.max_distance = 20.0
		get_tree().current_scene.add_child(audio_player)
		audio_player.global_position = levitating_body.global_position
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)
	
	is_levitating = true
	DebugLogger.info(module_name, "Started levitating object '%s' for %.1f seconds" % [levitating_body.name, hold_timer])
	
	return true

func _physics_process(delta: float) -> void:
	if not is_levitating or not levitating_body:
		return
	
	# Apply upward force to counteract gravity and create lift
	var gravity_force = ProjectSettings.get_setting("physics/3d/default_gravity") * levitating_body.mass
	var current_height = levitating_body.global_position.y
	
	# Calculate force needed to reach/maintain target height
	var height_difference = target_height - current_height
	var vertical_force = gravity_force * hover_force_multiplier
	
	# Add extra lift force if we're below target height
	if height_difference > 0.1:
		vertical_force += lift_force * clamp(height_difference, 0.0, 1.0)
	
	# Apply the force
	levitating_body.apply_central_force(Vector3.UP * vertical_force)
	
	# Reduce horizontal movement to keep it relatively stable
	var current_velocity = levitating_body.linear_velocity
	current_velocity.x *= 0.9
	current_velocity.z *= 0.9
	levitating_body.linear_velocity = current_velocity
	
	# Update timer
	hold_timer -= delta
	if hold_timer <= 0:
		end()

func end() -> void:
	if levitating_body:
		# Restore original gravity scale
		if levitating_body.has_property("gravity_scale"):
			levitating_body.gravity_scale = original_gravity_scale
		
		DebugLogger.info(module_name, "Released levitating object '%s'" % levitating_body.name)
		levitating_body = null
	
	is_levitating = false
	
	DebugLogger.info(module_name, "Object levitate event completed")
	
	# Call base implementation
	super.end()

func _find_closest_rigidbody(player_pos: Vector3) -> RigidBody3D:
	## Find the closest rigidbody within range
	var closest_body: RigidBody3D = null
	var closest_distance: float = max_search_distance
	
	# Get all rigidbodies in scene
	var bodies = _find_all_rigidbodies()
	
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
