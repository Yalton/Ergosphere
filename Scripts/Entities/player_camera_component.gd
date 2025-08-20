# PlayerCameraComponent.gd
class_name PlayerCameraComponent
extends Node

## Enable view bobbing while walking
@export var enable_view_bobbing: bool = true
## Amount of vertical bobbing
@export var bob_amount: float = 0.08
## Speed of the bobbing motion
@export var bob_speed: float = 10.0
## Mouse look sensitivity
@export var mouse_sensitivity: float = 0.002
## Vertical angle limit in radians (about 60 degrees)
@export var vertical_angle_limit: float = 1.0

# State
var is_camera_transitioning: bool = false
var bob_cycle: float = 0.0
var bob_base_height: float = 0.0
var last_bob_position: float = 0.0
var played_left_foot: bool = false
var played_right_foot: bool = false

# Camera transition
var camera_tween: Tween
var original_camera_position: Vector3
var original_camera_rotation: Vector3

# References
var player: CharacterBody3D
var head: Node3D
var camera: Camera3D
var footstep_detector: FootstepSurfaceDetector
var movement_component: PlayerMovementComponent
var module_name: String = "PlayerCameraComponent"

## Minimum speed to play footsteps
@export var footstep_speed_min: float = 0.1
## Enable footstep sounds
@export var enable_footsteps: bool = true

signal camera_transition_started()
signal camera_transition_complete()

func _ready() -> void:
	DebugLogger.register_module(module_name, false)

func setup(player_ref: CharacterBody3D, head_ref: Node3D, camera_ref: Camera3D, footstep_ref: FootstepSurfaceDetector, movement_ref: PlayerMovementComponent) -> void:
	player = player_ref
	head = head_ref
	camera = camera_ref
	footstep_detector = footstep_ref
	movement_component = movement_ref
	
	if camera:
		bob_base_height = camera.position.y
		last_bob_position = bob_base_height

func process_mouse_look(event: InputEvent, can_control: bool) -> void:
	if not can_control or not event is InputEventMouseMotion:
		return
	
	var mouse_event = event as InputEventMouseMotion
	
	# Rotate player body (left/right)
	player.rotate_y(-mouse_event.relative.x * mouse_sensitivity)
	
	# Rotate head (up/down)
	var current_tilt = head.rotation.x
	var new_tilt = current_tilt + (-mouse_event.relative.y * mouse_sensitivity)
	head.rotation.x = clamp(new_tilt, -vertical_angle_limit, vertical_angle_limit)

func update_view_bobbing(delta: float, velocity: Vector3, current_speed: float) -> void:
	if not enable_view_bobbing or not camera:
		return
	
	# Update bob base height from movement component
	if movement_component:
		bob_base_height = movement_component.get_bob_base_height()
	
	if movement_component.is_moving and not is_zero_approx(velocity.length()):
		# Increase bob cycle
		bob_cycle += delta * bob_speed * min(1.0, velocity.length() / current_speed)
		
		# Calculate vertical bob
		var vertical_bob = sin(bob_cycle) * bob_amount
		
		# Apply bobbing only if not crouching
		if not movement_component.is_crouching:
			camera.position.y = bob_base_height + vertical_bob
		
		# Horizontal bobbing
		camera.position.x = sin(bob_cycle * 0.5) * bob_amount * 0.5
		
		# Handle footsteps
		if enable_footsteps and footstep_detector and velocity.length() > footstep_speed_min:
			_check_footstep_timing(vertical_bob)
	else:
		# Return to center when not moving
		bob_cycle = 0.0
		if not movement_component.is_crouching:
			camera.position.y = lerp(camera.position.y, bob_base_height, delta * 5.0)
		camera.position.x = lerp(camera.position.x, 0.0, delta * 5.0)
		
		played_left_foot = false
		played_right_foot = false
		last_bob_position = bob_base_height

func _check_footstep_timing(vertical_bob: float) -> void:
	var current_bob_pos = camera.position.y
	
	if not played_right_foot and last_bob_position > current_bob_pos and _is_near_zero(vertical_bob):
		footstep_detector.play_footstep()
		played_right_foot = true
		played_left_foot = false
	elif not played_left_foot and last_bob_position > current_bob_pos and _is_near_zero(vertical_bob):
		if played_right_foot:
			footstep_detector.play_footstep()
			played_left_foot = true
			played_right_foot = false
	
	last_bob_position = current_bob_pos

func _is_near_zero(value: float, threshold: float = 0.01) -> bool:
	return abs(value) < threshold

func move_camera_to_position(target_position: Vector3, target_rotation: Vector3, duration: float = 1.5) -> void:
	if is_camera_transitioning:
		DebugLogger.warning(module_name, "Camera is already transitioning")
		return
	
	DebugLogger.debug(module_name, "Moving camera to position")
	
	original_camera_position = camera.global_position
	original_camera_rotation = camera.global_rotation
	
	is_camera_transitioning = true
	camera_transition_started.emit()
	
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	
	camera_tween = player.create_tween()
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)
	camera_tween.set_parallel(true)
	camera_tween.tween_property(camera, "global_position", target_position, duration)
	camera_tween.tween_property(camera, "global_rotation", target_rotation, duration)
	camera_tween.finished.connect(_on_camera_move_complete)

func restore_camera_position(duration: float = 1.0) -> void:
	if not is_camera_transitioning:
		DebugLogger.warning(module_name, "Camera is not transitioning")
		return
	
	DebugLogger.debug(module_name, "Restoring camera position")
	
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	
	camera_tween = player.create_tween()
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)
	camera_tween.set_parallel(true)
	camera_tween.tween_property(camera, "global_position", original_camera_position, duration)
	camera_tween.tween_property(camera, "global_rotation", original_camera_rotation, duration)
	camera_tween.finished.connect(_on_camera_restore_complete)

func _on_camera_move_complete() -> void:
	DebugLogger.debug(module_name, "Camera move complete")

func _on_camera_restore_complete() -> void:
	DebugLogger.debug(module_name, "Camera restore complete")
	is_camera_transitioning = false
	camera_transition_complete.emit()
	
	if camera_tween:
		camera_tween = null
