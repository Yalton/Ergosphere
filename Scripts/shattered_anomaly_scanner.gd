# ShatteredScanner.gd
extends Node3D
class_name ShatteredScanner

## Minimum impulse force applied to shards
@export var min_explosion_force: float = 5.0

## Maximum impulse force applied to shards
@export var max_explosion_force: float = 15.0

## Upward bias for explosion (makes it look more dramatic)
@export var upward_bias: float = 2.0

## Time before despawning all shards (seconds)
@export var despawn_time: float = 10.0

## Sound to play on explosion
@export var explosion_sound: AudioStream

# Internal
var module_name: String = "ShatteredScanner"
var enable_debug: bool = true
var rigid_body_shards: Array[RigidBody3D] = []
var despawn_timer: Timer

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	


func initialize(pos, rot) -> void: 
	global_position = pos
	global_rotation = rot

	# Find all rigid body children
	_find_rigid_body_shards()
	
	# Apply explosion forces
	_explode_shards()
	
	DebugLogger.info(module_name, "Instantiated at " + str(global_position))

	# Play explosion sound
	if explosion_sound:
		var audio_player = AudioStreamPlayer3D.new()
		audio_player.stream = explosion_sound
		audio_player.max_distance = 20.0
		audio_player.unit_size = 1.0
		audio_player.autoplay = true
		add_child(audio_player)
		# Clean up audio player after sound finishes
		audio_player.finished.connect(func(): audio_player.queue_free())
	
	# Setup despawn timer
	despawn_timer = Timer.new()
	despawn_timer.wait_time = despawn_time
	despawn_timer.one_shot = true
	despawn_timer.timeout.connect(_despawn_all)
	add_child(despawn_timer)
	despawn_timer.start()

	DebugLogger.info(module_name, "Shattered scanner created with " + str(rigid_body_shards.size()) + " shards")
	
func _find_rigid_body_shards() -> void:
	# Find all RigidBody3D children recursively
	rigid_body_shards.clear()
	_find_rigid_bodies_recursive(self)
	
	DebugLogger.debug(module_name, "Found " + str(rigid_body_shards.size()) + " rigid body shards")

func _find_rigid_bodies_recursive(node: Node) -> void:
	if node is RigidBody3D:
		rigid_body_shards.append(node)
		# Ensure physics properties are set correctly
		node.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		node.freeze = false
		node.gravity_scale = 1.0
	
	for child in node.get_children():
		_find_rigid_bodies_recursive(child)

func _explode_shards() -> void:
	for shard in rigid_body_shards:
		# Generate random explosion direction from center
		var direction = Vector3.ZERO
		
		# If shard is not at origin, use its position as direction
		if shard.position != Vector3.ZERO:
			direction = shard.position.normalized()
		else:
			# Generate random direction
			direction = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(0.0, 1.0),  # Slight upward bias
				randf_range(-1.0, 1.0)
			).normalized()
		
		# Add upward bias
		direction.y += upward_bias
		direction = direction.normalized()
		
		# Random force magnitude
		var force_magnitude = randf_range(min_explosion_force, max_explosion_force)
		var impulse = direction * force_magnitude
		
		# Apply impulse
		shard.apply_central_impulse(impulse)
		
		# Add some random rotation
		var torque = Vector3(
			randf_range(-5.0, 5.0),
			randf_range(-5.0, 5.0),
			randf_range(-5.0, 5.0)
		)
		shard.apply_torque_impulse(torque)
		
		DebugLogger.debug(module_name, "Applied impulse to shard: " + str(impulse))

func _despawn_all() -> void:
	DebugLogger.info(module_name, "Despawning all shards")
	
	# Fade out and remove each shard
	for shard in rigid_body_shards:
		if is_instance_valid(shard):
			_fade_and_remove_shard(shard)
	
	# Remove self after a short delay
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _fade_and_remove_shard(shard: RigidBody3D) -> void:
	# Create a tween for fade out effect
	var tween = create_tween()
	
	# Find mesh instance in shard
	var mesh_instance = null
	for child in shard.get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break
	if mesh_instance:
		# Fade out transparency if material supports it
		var material = mesh_instance.get_surface_override_material(0)
		if not material and mesh_instance.material_override:
			material = mesh_instance.material_override
		
		if material and material.has_property("transparency"):
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	
	# Scale down
	tween.parallel().tween_property(shard, "scale", Vector3.ZERO, 0.5)
	
	# Remove after tween
	tween.tween_callback(shard.queue_free)
