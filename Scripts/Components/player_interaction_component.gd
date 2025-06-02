extends Node3D
class_name PlayerInteractionComponent

signal rotate_carried_object(rotation: Vector3)

@export var ui_controller: FPCUIController
@export var interaction_action: String = "interact"  # Input action name
@export var throw_power: float = 10.0  # Power for throwing carried objects
@export var carryable_position: Node3D  # Reference to the position where carried objects should be placed
@export var enable_debug: bool = true  # Enable debug by default

var module_name: String = "PlayerInteraction"

@onready var ray_cast = $"../Head/Camera3D/RayCast3D"  # Path to your raycast
@onready var interaction_raycast = ray_cast  # Alias for compatibility
@onready var equipped_wieldable_item = null  # For diegetic UI compatibility

var current_interactable = null
var carried_object = null
var is_wielding: bool = false  # Property for compatibility with CarryableComponent
var current_diegetic_ui = null
var is_interacting_with_ui: bool = false

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	if not ui_controller:
		DebugLogger.error(module_name, "PlayerInteraction requires a UI Controller reference")
	
	if not carryable_position:
		DebugLogger.warning(module_name, "No carryable_position assigned. Carrying objects will not work correctly.")

func _process(_delta: float) -> void:
	# Skip interaction updates if we're interacting with UI
	if !is_interacting_with_ui:
		update_interaction()
	
	if Input.is_action_just_pressed(interaction_action) and current_interactable and !is_interacting_with_ui:
		DebugLogger.debug(module_name, "Interaction pressed, interacting with current object")
		interact_with_current()
	
	# Check for throw action if carrying an object
	if carried_object != null and Input.is_action_just_pressed("action_primary"):
		carried_object.throw(throw_power)
		
	# Handle rotation of carried objects
	if carried_object != null:
		var rotation_input = Vector3.ZERO
		
		# Object rotation controls (standard arrow keys)
		if Input.is_action_pressed("ui_up"):
			rotation_input.x -= 0.05  # Rotate around X axis (pitch)
		if Input.is_action_pressed("ui_down"):
			rotation_input.x += 0.05
		if Input.is_action_pressed("ui_left"):
			rotation_input.y -= 0.05  # Rotate around Y axis (yaw)
		if Input.is_action_pressed("ui_right"):
			rotation_input.y += 0.05
			
		# If there's rotation input, emit the signal
		if rotation_input != Vector3.ZERO:
			rotate_carried_object.emit(rotation_input)

func update_interaction() -> void:
	if ray_cast.is_colliding():
		var collider = ray_cast.get_collider()
		if collider: 
			if collider.is_in_group("interactable"):
				# Try to get interaction component
				var interaction = find_interaction_component(collider)
				
				# If we found a valid interaction and it's different from our current one
				if interaction and current_interactable != interaction:
					current_interactable = interaction
					ui_controller.show_interaction(interaction.interaction_text)
					DebugLogger.debug(module_name, "Found interactable: " + interaction.interaction_text)
				return
	
	# Nothing found, clear interaction
	if current_interactable:
		ui_controller.hide_interaction()
		current_interactable = null
		DebugLogger.debug(module_name, "No interactable in view, clearing prompt")

func interact_with_current() -> void:
	if current_interactable:
		DebugLogger.debug(module_name, "Interacting with: " + current_interactable.name)
		
		# Get the parent interactable object (usually Door or similar)
		var parent_interactable = current_interactable.get_parent()
		if parent_interactable and parent_interactable.has_method("interact"):
			DebugLogger.debug(module_name, "Calling interact on parent: " + parent_interactable.name)
			parent_interactable.interact(self)
		elif current_interactable.has_method("interact"):
			DebugLogger.debug(module_name, "Calling interact on component")
			current_interactable.interact(self)

func find_interaction_component(node) -> Node:
	# First check if the node itself has interaction text
	if node.has_method("get_interaction_text") or node.get("interaction_text") != null:
		return node
	
	# Check for a dedicated interaction component
	for child in node.get_children():
		if child.has_method("get_interaction_text") or child.get("interaction_text") != null:
			return child
	
	return null

# Helper method to send messages from gameplay
func send_message(text: String) -> void:
	if ui_controller:
		ui_controller.show_message(text)

# Helper method used for showing hints to the player
func send_hint(_hint_icon, hint_text: String) -> void:
	if ui_controller:
		ui_controller.show_hint(hint_text)
	

# Functions for CarryableComponent compatibility
func start_carrying(_carried_object) -> void:
	carried_object = _carried_object
	# Update interaction text if needed
	ui_controller.show_interaction("Drop " + carried_object.get_parent().name)

func stop_carrying() -> void:
	carried_object = null
	update_interaction()

# Function to get the carry position or raycast collision point
func get_interaction_raycast_tip(distance_offset: float = 0.0) -> Vector3:
	# Check if carryable position is set
	if not carryable_position:
		DebugLogger.error(module_name, "No carryable_position defined for PlayerInteractionComponent")
		return global_position
		
	# Use the carryable position as the target position
	var target_pos = carryable_position.global_position
	
	# Apply any custom offset if needed
	if distance_offset != 0.0:
		var camera = get_viewport().get_camera_3d()
		target_pos = target_pos - camera.global_transform.basis.z * distance_offset
	
	# If there's an obstacle between the camera and the position, use that instead
	if ray_cast.is_colliding():
		var collision_point = ray_cast.get_collision_point()
		var camera = get_viewport().get_camera_3d()
		
		# Only use the collision point if it's closer than our target position
		if camera.global_position.distance_to(collision_point) < camera.global_position.distance_to(target_pos):
			return collision_point
	
	return target_pos

# Function to get a normalized vector in the direction the player is looking
func Get_Look_Direction() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	return -camera.global_transform.basis.z.normalized()

# DIEGETIC UI INTEGRATION FUNCTIONS
# Called when a player starts interacting with UI
func diegetic_ui_interaction_started(ui_node) -> void:
	DebugLogger.debug(module_name, "Starting diegetic UI interaction with: " + ui_node.name)
	current_diegetic_ui = ui_node
	is_interacting_with_ui = true
	
	# Hide the interaction prompt when interacting
	ui_controller.hide_interaction()
	
	# Tell the player to release the mouse
	var player = get_parent()
	player.start_ui_interaction()
	
	# Release the mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DebugLogger.debug(module_name, "Mouse mode set to VISIBLE")

# Called when a player stops interacting with UI
func diegetic_ui_interaction_ended() -> void:
	DebugLogger.debug(module_name, "Ending diegetic UI interaction")
	is_interacting_with_ui = false
	current_diegetic_ui = null
	
	# Tell the player to re-capture the mouse
	var player = get_parent()
	player.end_ui_interaction()
	
	# Re-capture the mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	DebugLogger.debug(module_name, "Mouse mode set to CAPTURED")
	
	# Force update interaction state after ending interaction
	update_interaction()
