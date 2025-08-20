# Player.gd
class_name Player
extends CharacterBody3D

## UI controller for player interface
@export var ui_controller: PlayerUI
## Component for handling interactions
@export var interaction_component: PlayerInteractionComponent

## Enable debug logging
@export var enable_debug: bool = true
## Force focus on movement input
@export var force_movement_focus: bool = true

# Component references
@onready var insanity_component: InsanityComponent = $InsanityComponent
@onready var vfx_component: Node = $PlayerVFXComponent
@onready var flashlight_component: PlayerFlashlightComponent = $PlayerFlashlightComponent
@onready var movement_component: PlayerMovementComponent = $PlayerMovementComponent
@onready var camera_component: PlayerCameraComponent = $PlayerCameraComponent

# Node references
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# Footstep detector (optional)
@export var footstep_detector: FootstepSurfaceDetector

# Physics
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# State
var is_interacting_with_ui: bool = false
var input_disabled: bool = false
var can_control: bool = true

# Module name for debug
var module_name: String = "Player"

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Validate components
	if not vfx_component:
		DebugLogger.warning(module_name, "No PlayerVFXComponent found as child node")
	
	if not flashlight_component:
		DebugLogger.warning(module_name, "No PlayerFlashlightComponent found - creating one")
		flashlight_component = PlayerFlashlightComponent.new()
		flashlight_component.name = "PlayerFlashlightComponent"
		add_child(flashlight_component)
	
	if not movement_component:
		DebugLogger.warning(module_name, "No PlayerMovementComponent found - creating one")
		movement_component = PlayerMovementComponent.new()
		movement_component.name = "PlayerMovementComponent"
		add_child(movement_component)
	
	if not camera_component:
		DebugLogger.warning(module_name, "No PlayerCameraComponent found - creating one")
		camera_component = PlayerCameraComponent.new()
		camera_component.name = "PlayerCameraComponent"
		add_child(camera_component)
	
	# Setup components
	flashlight_component.set_ui_controller(ui_controller)
	movement_component.setup(self, camera, collision_shape)
	camera_component.setup(self, head, camera, footstep_detector, movement_component)
	
	# Connect camera transition signals
	camera_component.camera_transition_started.connect(_on_camera_transition_started)
	camera_component.camera_transition_complete.connect(_on_camera_transition_complete)
	
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Connect to dev console signals
	if ui_controller and ui_controller.dev_console_ui:
		ui_controller.dev_console_ui.console_opened.connect(_on_dev_console_opened)
		ui_controller.dev_console_ui.console_closed.connect(_on_dev_console_closed)
	
	# Setup input processing
	set_process_input(true)
	set_physics_process(true)
	process_mode = PROCESS_MODE_INHERIT
	
	# Request focus if enabled
	if force_movement_focus:
		await get_tree().process_frame
		grab_movement_focus()
	
	DebugLogger.info(module_name, "Player initialized")

func _on_dev_console_opened() -> void:
	is_interacting_with_ui = true
	DebugLogger.debug(module_name, "Dev console opened - player input disabled")

func _on_dev_console_closed() -> void:
	is_interacting_with_ui = false
	DebugLogger.debug(module_name, "Dev console closed - player input enabled")

func _on_camera_transition_started() -> void:
	can_control = false

func _on_camera_transition_complete() -> void:
	can_control = true

func _input(event: InputEvent) -> void:
	# Skip input if interacting with UI
	if is_interacting_with_ui:
		return
	
	# Handle flashlight toggle
	if event.is_action_pressed("f"):
		flashlight_component.toggle()
		return
	
	# Handle crouch input
	if movement_component.enable_crouch and !movement_component.is_crouching:
		if event.is_action_pressed("crouch") and !movement_component.is_crouched:
			movement_component.start_crouch()
		elif event.is_action_released("crouch") and movement_component.is_crouched:
			movement_component.stop_crouch()
	
	# Handle mouse look
	camera_component.process_mouse_look(event, can_control)

func _physics_process(delta: float) -> void:
	# Process flashlight battery
	flashlight_component.process_battery(delta)
	
	# Skip movement if interacting with UI
	if is_interacting_with_ui or !can_control:
		return
	
	# Apply gravity
	if not is_on_floor() and not movement_component.noclip_enabled:
		velocity.y -= gravity * delta
	
	# Process movement
	var new_velocity = movement_component.process_movement(delta, input_disabled, can_control)
	if movement_component.noclip_enabled:
		# Noclip handles position directly
		return
	else:
		# Apply normal movement velocity
		velocity.x = new_velocity.x
		velocity.z = new_velocity.z
	
	# Move and handle collisions
	move_and_slide()
	
	# Push rigid bodies
	for col_idx in get_slide_collision_count():
		var col := get_slide_collision(col_idx)
		if col.get_collider() is RigidBody3D:
			col.get_collider().apply_central_impulse(-col.get_normal() * movement_component.push_force)
	
	# Update view bobbing
	camera_component.update_view_bobbing(delta, velocity, movement_component.current_speed)

func grab_movement_focus() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process_input(true)
	DebugLogger.debug(module_name, "Player grabbed movement focus")

func get_look_target() -> Dictionary:
	if raycast and raycast.is_colliding():
		return {
			"collider": raycast.get_collider(),
			"point": raycast.get_collision_point()
		}
	return {}

func start_ui_interaction() -> void:
	is_interacting_with_ui = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func end_ui_interaction() -> void:
	is_interacting_with_ui = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func receive_message(text: String) -> void:
	if ui_controller:
		ui_controller.show_message("Placeholder", text)
	else:
		DebugLogger.warning(module_name, "No UI controller found to display message: " + text)

# Camera control wrappers
func move_camera_to_position(target_position: Vector3, target_rotation: Vector3, duration: float = 1.5) -> void:
	camera_component.move_camera_to_position(target_position, target_rotation, duration)

func restore_camera_position(duration: float = 1.0) -> void:
	camera_component.restore_camera_position(duration)

# Movement control wrappers
func slow_player(apply: bool, slow_factor: float = 0.3, fade_in_time: float = 2.0, fade_out_time: float = 10.0) -> void:
	movement_component.slow_player(apply, slow_factor, fade_in_time, fade_out_time)

func apply_hawking_movement(apply: bool) -> void:
	"""Legacy function - redirects to slow_player"""
	DebugLogger.debug(module_name, "apply_hawking_movement called - redirecting to slow_player")
	slow_player(apply, 0.3, 2.0, 10.0)

func toggle_noclip() -> void:
	movement_component.toggle_noclip()

# Insanity system integration
func sleep() -> void:
	insanity_component.reset_insanity()

func eat() -> void:
	insanity_component.reduce_insanity_by_eating()

# VFX Helper Functions
func trigger_player_vfx(effect_id: String, startup: float = 0.5, duration: float = 2.0, winddown: float = 0.5) -> void:
	if not vfx_component:
		DebugLogger.warning(module_name, "No VFX component attached to player")
		return
	
	vfx_component.invoke_effect(effect_id, startup, duration, winddown)
	DebugLogger.debug(module_name, "Triggered player effect: " + effect_id)

func stop_player_vfx(effect_id: String = "") -> void:
	if not vfx_component:
		DebugLogger.warning(module_name, "No VFX component attached to player")
		return
	
	if effect_id.is_empty():
		vfx_component.stop_all_effects()
		DebugLogger.debug(module_name, "Stopped all player effects")
	else:
		vfx_component.stop_effect(effect_id)
		DebugLogger.debug(module_name, "Stopped player effect: " + effect_id)

func is_player_vfx_active(effect_id: String) -> bool:
	if not vfx_component:
		return false
	
	return vfx_component.is_effect_active(effect_id)
