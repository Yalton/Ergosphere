# FirstPersonController.gd
class_name Player
extends CharacterBody3D

@export var ui_controller: FPCUIController
@export var interaction_component: PlayerInteractionComponent

# Movement parameters
@export var walk_speed: float = 5.0
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0

# View bobbing parameters
@export var enable_view_bobbing: bool = true
@export var bob_amount: float = 0.08
@export var bob_speed: float = 10.0

# Footstep parameters
@export var enable_footsteps: bool = true
@export var footstep_detector: FootstepSurfaceDetector
@export var footstep_speed_min: float = 0.1  # Min speed to play footsteps

# Mouse look sensitivity
@export var mouse_sensitivity: float = 0.002
@export var vertical_angle_limit: float = 1.0  # About 60 degrees up/down


# Debug options
@export var enable_debug: bool = true
var module_name: String = "Player"

# Force focusing movement
@export var force_movement_focus: bool = true

@export var PLAYER_PUSH_FORCE : float = 1.3

# Flashlight settings
@export_group("Flashlight")
## The spotlight node that acts as the flashlight
@export var flashlight_spot: SpotLight3D
## Sound played when turning flashlight on/off
@export var flashlight_click_sound: AudioStream


# Node references
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D

# Physics
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# View bob variables
var bob_cycle: float = 0.0
var bob_base_height: float = 0.0
var is_moving: bool = false
var last_bob_position: float = 0.0
var played_left_foot: bool = false
var played_right_foot: bool = false

var is_interacting_with_ui: bool = false
var input_disabled: bool = false

# Camera tweening variables
var camera_tween: Tween = null
var original_camera_position: Vector3
var original_camera_rotation: Vector3
var is_camera_transitioning: bool = false

# Flashlight state
var flashlight_on: bool = false
var flashlight_audio: AudioStreamPlayer3D

func _ready() -> void:
	# Register with debug logger if it exists
	DebugLogger.register_module(module_name, enable_debug)
		
	# Capture mouse cursor and hide it
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Store the initial camera position for view bobbing
	if camera:
		bob_base_height = camera.position.y
		last_bob_position = bob_base_height
		
	# Setup flashlight audio
	flashlight_audio = AudioStreamPlayer3D.new()
	flashlight_audio.name = "FlashlightAudio"
	flashlight_audio.bus = "SFX"
	add_child(flashlight_audio)
	
	# Initialize flashlight state
	if flashlight_spot:
		flashlight_spot.visible = false
		flashlight_on = false
		
	# Debug input map state
	if enable_debug:
		DebugLogger.debug(module_name, "Checking input actions:")
		DebugLogger.debug(module_name, "Action 'w' exists: " + str(InputMap.has_action("w")))
		DebugLogger.debug(module_name, "Action 'a' exists: " + str(InputMap.has_action("a")))
		DebugLogger.debug(module_name, "Action 's' exists: " + str(InputMap.has_action("s")))
		DebugLogger.debug(module_name, "Action 'd' exists: " + str(InputMap.has_action("d")))
	
	# Make sure we get focus to properly receive input
	set_process_input(true)
	set_physics_process(true)
	
	# Force the controller to be in the main process group
	process_mode = PROCESS_MODE_INHERIT
	
	# Request focus if enabled
	if force_movement_focus:
		# Wait a frame to ensure everything is set up
		await get_tree().process_frame
		# Force input focus and mouse capture
		grab_movement_focus()
	
	DebugLogger.info(module_name, "FirstPersonController initialized")

func _input(event: InputEvent) -> void:
	# Handle flashlight toggle
	if event.is_action_pressed("f"):
		toggle_flashlight()
		get_viewport().set_input_as_handled()
		return
	
	# Mouse look (camera rotation)
	if event is InputEventMouseMotion and !is_interacting_with_ui:
		# Rotate head (left and right)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotate camera (up and down)
		var current_tilt = head.rotation.x
		var new_tilt = current_tilt + (-event.relative.y * mouse_sensitivity)
		
		# Clamp vertical rotation
		head.rotation.x = clamp(new_tilt, -vertical_angle_limit, vertical_angle_limit)

func toggle_flashlight() -> void:
	if not flashlight_spot:
		DebugLogger.warning(module_name, "No flashlight SpotLight3D assigned")
		return
	
	flashlight_on = !flashlight_on
	flashlight_spot.visible = flashlight_on
	
	# Play click sound
	if flashlight_click_sound and flashlight_audio:
		flashlight_audio.stream = flashlight_click_sound
		flashlight_audio.play()
	
	DebugLogger.debug(module_name, "Flashlight " + ("on" if flashlight_on else "off"))

func _physics_process(delta: float) -> void:
	if is_interacting_with_ui:
		return
	# Get movement input
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_action_strength("d") - Input.get_action_strength("a")
	input_dir.y = -(Input.get_action_strength("s") - Input.get_action_strength("w"))  # Inverted Y axis
	input_dir = input_dir.normalized()
	

	
	# Create 3D direction vector based on camera orientation
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	
	var direction = (forward * input_dir.y + right * input_dir.x)
	
	# Handle acceleration and deceleration
	if direction:
		velocity.x = lerp(velocity.x, direction.x * walk_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * walk_speed, acceleration * delta)
		is_moving = true
	else:
		velocity.x = lerp(velocity.x, 0.0, deceleration * delta)
		velocity.z = lerp(velocity.z, 0.0, deceleration * delta)
		is_moving = false
	
	# Apply movement
	move_and_slide()

	for col_idx in get_slide_collision_count():
		var col := get_slide_collision(col_idx)
		if col.get_collider() is RigidBody3D:
			col.get_collider().apply_central_impulse(-col.get_normal() * PLAYER_PUSH_FORCE)
			
	# Update view bobbing (and footsteps, since they're now integrated)
	if enable_view_bobbing and camera:
		update_view_bobbing(delta)

# Add this function to receive messages from other scripts
func receive_message(text: String) -> void:
	if ui_controller:
		ui_controller.show_message("Placeholder", text)
	else:
		DebugLogger.warning(module_name, "No UI controller found to display message: " + text)

# Public method to grab focus and enable movement
func grab_movement_focus() -> void:
	# Force capturing the mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Force this node to get input focus
	if !get_viewport().gui_get_focus_owner():
		# Only force focus if no UI element has it
		set_process_input(true)
		# Note: CharacterBody3D doesn't have grab_focus, so we just ensure input processing is on
	
	DebugLogger.debug(module_name, "FPS Controller grabbed movement focus")

# Function to check if something is in front of the player
func get_look_target() -> Dictionary:
	if raycast and raycast.is_colliding():
		var collider = raycast.get_collider()
		var collision_point = raycast.get_collision_point()
		
		return {
			"collider": collider,
			"point": collision_point
		}
	
	return {}

# Handle view bobbing effect and footsteps
func update_view_bobbing(delta: float) -> void:
	if is_moving and not is_zero_approx(velocity.length()):
		# Increase the bob cycle based on movement speed and bob speed
		bob_cycle += delta * bob_speed * min(1.0, velocity.length() / walk_speed)
		
		# Calculate vertical bob with sine wave
		var vertical_bob = sin(bob_cycle) * bob_amount
		
		# Apply bobbing to camera position
		camera.position.y = bob_base_height + vertical_bob
		
		# Optional: Add some horizontal bobbing for more realistic effect
		camera.position.x = sin(bob_cycle * 0.5) * bob_amount * 0.5
		
		# Check for footstep timing based on head bob
		if enable_footsteps and footstep_detector and velocity.length() > footstep_speed_min:
			# Track the camera's vertical position
			var current_bob_pos = camera.position.y
			
			# We want to play footstep when camera is at its lowest point (when sine wave crosses 0 going down)
			# The sine wave crosses 0 going down at PI, 3PI, 5PI, etc.
			
			# For right foot (at PI, 5PI, 9PI, etc.)
			if not played_right_foot and last_bob_position > current_bob_pos and is_near_zero(vertical_bob):
				footstep_detector.play_footstep()
				played_right_foot = true
				played_left_foot = false
				if enable_debug:
					DebugLogger.debug(module_name, "Right footstep at bob cycle: " + str(bob_cycle))
			
			# For left foot (at 3PI, 7PI, 11PI, etc.)
			elif not played_left_foot and last_bob_position > current_bob_pos and is_near_zero(vertical_bob):
				if played_right_foot: # Make sure right foot has played first
					footstep_detector.play_footstep()
					played_left_foot = true
					played_right_foot = false
					if enable_debug:
						DebugLogger.debug(module_name, "Left footstep at bob cycle: " + str(bob_cycle))
			
			# Update last position for next frame
			last_bob_position = current_bob_pos
	else:
		# Gradually return to center when not moving
		bob_cycle = 0.0
		camera.position.y = lerp(camera.position.y, bob_base_height, delta * 5.0)
		camera.position.x = lerp(camera.position.x, 0.0, delta * 5.0)
		
		# Reset footstep flags when not moving
		played_left_foot = false
		played_right_foot = false
		last_bob_position = bob_base_height

# Helper function to check if a value is close to zero
func is_near_zero(value: float, threshold: float = 0.01) -> bool:
	return abs(value) < threshold

func start_ui_interaction() -> void:
	is_interacting_with_ui = true
	# Additional code to disable movement and show mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
func end_ui_interaction() -> void:
	is_interacting_with_ui = false
	# Additional code to re-enable movement and hide mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


######################################
# Camera code
######################################



func move_camera_to_position(target_position: Vector3, target_rotation: Vector3, duration: float = 1.5) -> void:
	if is_camera_transitioning:
		DebugLogger.warning(module_name, "Camera is already transitioning")
		return
	
	DebugLogger.debug(module_name, "Moving camera to position")
	
	# Store original transform
	original_camera_position = camera.global_position
	original_camera_rotation = camera.global_rotation
	
	# Disable player controls
	is_camera_transitioning = true
	is_interacting_with_ui = true  # This already disables movement in your code
	
	# Kill existing tween if any
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	
	# Create new tween
	camera_tween = create_tween()
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Tween position and rotation simultaneously
	camera_tween.set_parallel(true)
	camera_tween.tween_property(camera, "global_position", target_position, duration)
	camera_tween.tween_property(camera, "global_rotation", target_rotation, duration)
	
	# Connect to completion
	camera_tween.finished.connect(_on_camera_move_complete)

func restore_camera_position(duration: float = 1.0) -> void:
	if not is_camera_transitioning:
		DebugLogger.warning(module_name, "Camera is not transitioning")
		return
	
	DebugLogger.debug(module_name, "Restoring camera position")
	
	# Kill existing tween if any
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	
	# Create restoration tween
	camera_tween = create_tween()
	camera_tween.set_ease(Tween.EASE_IN_OUT)
	camera_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Tween back to original position
	camera_tween.set_parallel(true)
	camera_tween.tween_property(camera, "global_position", original_camera_position, duration)
	camera_tween.tween_property(camera, "global_rotation", original_camera_rotation, duration)
	
	# Connect to completion
	camera_tween.finished.connect(_on_camera_restore_complete)

func _on_camera_move_complete() -> void:
	DebugLogger.debug(module_name, "Camera move complete")
	# Camera is in position but still transitioning (waiting for restore)

func _on_camera_restore_complete() -> void:
	DebugLogger.debug(module_name, "Camera restore complete")
	# Re-enable player controls
	is_camera_transitioning = false
	is_interacting_with_ui = false
	
	# Clean up tween
	if camera_tween:
		camera_tween = null
