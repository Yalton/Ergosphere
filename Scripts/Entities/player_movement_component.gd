# PlayerMovementComponent.gd
class_name PlayerMovementComponent
extends Node

## Speed when walking
@export var walk_speed: float = 5.0
## Speed when crouched
@export var crouch_speed: float = 2.5
## Acceleration factor
@export var acceleration: float = 8.0
## Deceleration factor
@export var deceleration: float = 10.0
## Enable crouching functionality
@export var enable_crouch: bool = true
## Crouched camera height offset from standing position
@export var crouch_camera_offset: float = -0.3
## Crouched collision shape height multiplier
@export var crouch_height_multiplier: float = 0.75
## Duration of crouch transition animation
@export var crouch_transition_duration: float = 0.3
## Force applied when pushing rigid bodies
@export var push_force: float = 1.3

# State
var is_crouched: bool = false
var is_crouching: bool = false
var is_slowed: bool = false
var is_moving: bool = false
var noclip_enabled: bool = false
var noclip_speed: float = 10.0

# Speed variables
var current_speed: float
var normal_walk_speed: float
var normal_crouch_speed: float
var target_walk_speed: float
var target_crouch_speed: float
var movement_slow_factor: float = 0.3

# Stored values
var original_camera_y: float
var original_collision_height: float

# Tweens
var crouch_tween: Tween
var collision_tween: Tween
var movement_tween: Tween

# References
var player: CharacterBody3D
var camera: Camera3D
var collision_shape: CollisionShape3D
var module_name: String = "PlayerMovementComponent"

func _ready() -> void:
	DebugLogger.register_module(module_name, false)

func setup(player_ref: CharacterBody3D, camera_ref: Camera3D, collision_ref: CollisionShape3D) -> void:
	player = player_ref
	camera = camera_ref
	collision_shape = collision_ref
	
	# Store original values
	if camera:
		original_camera_y = camera.position.y
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		original_collision_height = capsule.height
	
	# Initialize speeds
	normal_walk_speed = walk_speed
	normal_crouch_speed = crouch_speed
	target_walk_speed = walk_speed
	target_crouch_speed = crouch_speed
	current_speed = walk_speed

func process_movement(delta: float, input_disabled: bool, can_control: bool) -> Vector3:
	if input_disabled or !can_control:
		return Vector3.ZERO
	
	# Handle noclip
	if noclip_enabled:
		return _handle_noclip_movement(delta)
	
	# Get input
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_action_strength("d") - Input.get_action_strength("a")
	input_dir.y = -(Input.get_action_strength("s") - Input.get_action_strength("w"))
	input_dir = input_dir.normalized()
	
	# Create 3D direction
	var forward = -player.global_transform.basis.z
	var right = player.global_transform.basis.x
	var direction = (forward * input_dir.y + right * input_dir.x)
	
	# Calculate velocity
	var velocity = player.velocity
	
	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, acceleration * delta)
		is_moving = true
	else:
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta)
		is_moving = false
	
	return velocity

func _handle_noclip_movement(delta: float) -> Vector3:
	var input_dir = Vector3.ZERO
	
	if Input.is_action_pressed("w"):
		input_dir -= player.transform.basis.z
	if Input.is_action_pressed("s"):
		input_dir += player.transform.basis.z
	if Input.is_action_pressed("a"):
		input_dir -= player.transform.basis.x
	if Input.is_action_pressed("d"):
		input_dir += player.transform.basis.x
	if Input.is_action_pressed("ui_accept"):
		input_dir.y += 1
	if Input.is_action_pressed("crouch"):
		input_dir.y -= 1
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		player.global_position += input_dir * noclip_speed * delta
	
	return Vector3.ZERO

func start_crouch() -> void:
	if is_crouched or !enable_crouch:
		return
	
	is_crouched = true
	is_crouching = true
	
	var target_camera_y = original_camera_y + crouch_camera_offset
	var target_collision_height = original_collision_height * crouch_height_multiplier
	
	DebugLogger.debug(module_name, "Starting crouch")
	
	# Kill existing tweens
	if crouch_tween and crouch_tween.is_valid():
		crouch_tween.kill()
	if collision_tween and collision_tween.is_valid():
		collision_tween.kill()
	
	# Tween camera
	crouch_tween = player.create_tween()
	crouch_tween.set_ease(Tween.EASE_OUT)
	crouch_tween.set_trans(Tween.TRANS_CUBIC)
	crouch_tween.tween_property(camera, "position:y", target_camera_y, crouch_transition_duration)
	crouch_tween.tween_callback(_on_crouch_complete)
	
	# Tween collision
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		collision_tween = player.create_tween()
		collision_tween.set_ease(Tween.EASE_OUT)
		collision_tween.set_trans(Tween.TRANS_CUBIC)
		collision_tween.tween_method(_update_collision_height, capsule.height, target_collision_height, crouch_transition_duration)
	
	current_speed = target_crouch_speed

func stop_crouch() -> void:
	if !is_crouched:
		return
	
	is_crouched = false
	is_crouching = true
	
	DebugLogger.debug(module_name, "Stopping crouch")
	
	# Kill existing tweens
	if crouch_tween and crouch_tween.is_valid():
		crouch_tween.kill()
	if collision_tween and collision_tween.is_valid():
		collision_tween.kill()
	
	# Tween camera
	crouch_tween = player.create_tween()
	crouch_tween.set_ease(Tween.EASE_OUT)
	crouch_tween.set_trans(Tween.TRANS_CUBIC)
	crouch_tween.tween_property(camera, "position:y", original_camera_y, crouch_transition_duration)
	crouch_tween.tween_callback(_on_crouch_complete)
	
	# Tween collision
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		collision_tween = player.create_tween()
		collision_tween.set_ease(Tween.EASE_OUT)
		collision_tween.set_trans(Tween.TRANS_CUBIC)
		collision_tween.tween_method(_update_collision_height, capsule.height, original_collision_height, crouch_transition_duration)
	
	current_speed = target_walk_speed

func _update_collision_height(height: float) -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = height

func _on_crouch_complete() -> void:
	is_crouching = false
	DebugLogger.debug(module_name, "Crouch transition complete")

func slow_player(apply: bool, slow_factor: float = 0.3, fade_in_time: float = 2.0, fade_out_time: float = 10.0) -> void:
	if apply == is_slowed:
		return
	
	is_slowed = apply
	movement_slow_factor = slow_factor
	
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	
	movement_tween = player.create_tween()
	movement_tween.set_parallel(true)
	
	if apply:
		var new_walk = normal_walk_speed * slow_factor
		var new_crouch = normal_crouch_speed * slow_factor
		
		movement_tween.tween_property(self, "target_walk_speed", new_walk, fade_in_time)
		movement_tween.tween_property(self, "target_crouch_speed", new_crouch, fade_in_time)
		
		if is_crouched:
			movement_tween.tween_property(self, "current_speed", new_crouch, fade_in_time)
		else:
			movement_tween.tween_property(self, "current_speed", new_walk, fade_in_time)
		
		DebugLogger.debug(module_name, "Applying movement slow over %.1fs - factor: %.2f" % [fade_in_time, slow_factor])
	else:
		movement_tween.tween_property(self, "target_walk_speed", normal_walk_speed, fade_out_time)
		movement_tween.tween_property(self, "target_crouch_speed", normal_crouch_speed, fade_out_time)
		
		if is_crouched:
			movement_tween.tween_property(self, "current_speed", normal_crouch_speed, fade_out_time)
		else:
			movement_tween.tween_property(self, "current_speed", normal_walk_speed, fade_out_time)
		
		DebugLogger.debug(module_name, "Removing movement slow over %.1fs" % fade_out_time)

func toggle_noclip() -> void:
	noclip_enabled = !noclip_enabled
	
	if collision_shape:
		collision_shape.disabled = noclip_enabled
	
	player.velocity = Vector3.ZERO
	
	DebugLogger.info(module_name, "Noclip " + ("enabled" if noclip_enabled else "disabled"))

func get_bob_base_height() -> float:
	return original_camera_y + (crouch_camera_offset if is_crouched else 0.0)
