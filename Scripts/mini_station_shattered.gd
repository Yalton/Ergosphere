# ShatteredStationController.gd
extends Node3D

## Enable debug logging for this module
@export var enable_debug: bool = true
var module_name: String = "ShatteredStation"

## Force applied to rigid bodies for power failure (small)
@export var power_failure_impulse: float = 2.0

## Force applied to rigid bodies for engine explosion (large)  
@export var engine_explosion_impulse: float = 15.0

## Whether to apply random spin to pieces
@export var apply_random_torque: bool = true

## Maximum torque applied to pieces
@export var max_torque: float = 5.0

# Internal state
var rigid_bodies: Array[RigidBody3D] = []
var explosion_type: String = ""
var original_gravity: Vector3

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Store original gravity
	original_gravity = PhysicsServer3D.area_get_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR)
	
	# Find all rigid body children
	_collect_rigid_bodies()
	
	DebugLogger.info(module_name, "Shattered station ready with %d pieces" % rigid_bodies.size())

func _collect_rigid_bodies() -> void:
	rigid_bodies.clear()
	
	# Get all RigidBody3D children (direct children based on your scene structure)
	for child in get_children():
		if child is RigidBody3D:
			rigid_bodies.append(child)
			# Ensure physics properties
			child.freeze = false
			child.gravity_scale = 1.0  # Use normal gravity scale
	
	DebugLogger.debug(module_name, "Collected %d rigid bodies" % rigid_bodies.size())

func explode(shatter_type: String) -> void:
	explosion_type = shatter_type
	
	DebugLogger.info(module_name, "Exploding with type: %s" % shatter_type)
	
	# Change global gravity to point toward black hole with orbital drift
	# Reduced Z gravity to 1/3 and added X component for orbital motion
	PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, Vector3(2.0, 0, -3.3))
	DebugLogger.debug(module_name, "Set gravity to pull toward black hole with orbital drift")
	
	var impulse_strength = power_failure_impulse
	if shatter_type == "engine_explosion":
		impulse_strength = engine_explosion_impulse
	
	_apply_explosion_forces(impulse_strength)

func _apply_explosion_forces(impulse_strength: float) -> void:
	for body in rigid_bodies:
		if not is_instance_valid(body):
			continue
		
		# Generate explosion direction
		var direction: Vector3
		
		if explosion_type == "engine_explosion":
			# More chaotic explosion for engine failure
			direction = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-0.5, 1.0),  # Slight upward bias
				randf_range(-1.0, 1.0)
			).normalized()
		else:
			# More controlled separation for power failure
			# Use piece position relative to origin as direction
			if body.position.length() > 0.1:
				direction = body.position.normalized()
			else:
				direction = Vector3(
					randf_range(-0.5, 0.5),
					randf_range(-0.2, 0.2),
					randf_range(-0.5, 0.5)
				).normalized()
		
		# Apply the impulse
		body.apply_central_impulse(direction * impulse_strength)
		
		# Apply random torque if enabled
		if apply_random_torque:
			var torque = Vector3(
				randf_range(-max_torque, max_torque),
				randf_range(-max_torque, max_torque),
				randf_range(-max_torque, max_torque)
			)
			body.apply_torque_impulse(torque)
	
	DebugLogger.debug(module_name, "Applied impulse of %f to %d bodies" % [impulse_strength, rigid_bodies.size()])

func restore_gravity() -> void:
	# Restore original gravity
	PhysicsServer3D.area_set_param(get_viewport().find_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY_VECTOR, original_gravity)
	DebugLogger.debug(module_name, "Restored original gravity")
