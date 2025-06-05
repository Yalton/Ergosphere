class_name DiegeticUIBase
extends AwareGameObject

signal object_state_updated(interaction_text: String)
signal interaction_started
signal interaction_ended

@export_group("Interaction Settings")
@export var interact_sound: AudioStream
@export var usable_interaction_text: String = "Use UI"
@export var allows_repeated_interaction: bool = true
@export var interaction_cooldown_time: float = 0.5  # Cooldown after interaction ends
@export var has_been_used_hint: String
@export var unusable_interaction_text: String = "UI Locked"

## If true, UI will reset to initial state when day resets
@export var reset_on_new_day: bool = true

@export_group("UI Control")
@export var sub_viewport: SubViewport
@export var display: MeshInstance3D

@onready var area_3d: Area3D = $Area3D

var has_been_used: bool = false
var interaction_text: String
var player_interaction_component: PlayerInteractionComponent
var cooldown: float
var is_player_interacting: bool = false
var is_in_cooldown: bool = false  # Track if we're in post-interaction cooldown
var is_disabled: bool = false  # New: Track if UI is disabled
var original_material: Material  # Store original material

# Mouse handling variables
var pending_mouse_event: InputEvent = null
var last_mouse_hit: Vector3 = Vector3.ZERO

func _ready() -> void:
	
	super._ready()
	module_name = "DiegeticUI"
	DebugLogger.register_module(module_name, enable_debug)
	
	cooldown = 0
	interaction_text = usable_interaction_text
	object_state_updated.emit(interaction_text)
	
	if sub_viewport:
		sub_viewport.set_process_input(true)
		DebugLogger.debug(module_name, "SubViewport found and input processing enabled")
	else:
		DebugLogger.error(module_name, "No SubViewport assigned!")
	
	if not area_3d:
		DebugLogger.error(module_name, "No Area3D found as child!")
	
	# Store original material if display exists
	if display and display.get_surface_override_material_count() > 0:
		original_material = display.get_surface_override_material(0)
	elif display and display.mesh:
		original_material = display.material_override
	
	# Connect to GameManager's day_reset signal
	if reset_on_new_day and GameManager:
		GameManager.day_reset.connect(_on_day_reset)
		DebugLogger.debug(module_name, "Connected to day_reset signal")
	
	DebugLogger.debug(module_name, "Diegetic UI initialized with text: " + interaction_text)

func _physics_process(delta: float) -> void:
	if cooldown > 0:
		cooldown -= delta
		if cooldown <= 0:
			is_in_cooldown = false
			DebugLogger.debug(module_name, "Cooldown expired, UI can be interacted with again")
	
	# Process pending mouse event during physics process
	if pending_mouse_event and is_player_interacting:
		process_mouse_raycast(pending_mouse_event)
		pending_mouse_event = null

func interact(_player_interaction_component: PlayerInteractionComponent) -> void:
	# Check if UI is disabled
	if is_disabled:
		DebugLogger.debug(module_name, "UI is disabled, ignoring interaction")
		return
		
	# Check if we're in cooldown
	if is_in_cooldown:
		DebugLogger.debug(module_name, "UI is in cooldown, ignoring interaction")
		return
	
	if is_player_interacting:
		DebugLogger.debug(module_name, "Already interacting, ending interaction")
		end_interaction()
		return
	
	if cooldown > 0:
		DebugLogger.debug(module_name, "Interaction on cooldown: " + str(cooldown))
		return
	
	player_interaction_component = _player_interaction_component
	if !allows_repeated_interaction and has_been_used:
		DebugLogger.debug(module_name, "Already used and no repeat allowed")
		player_interaction_component.send_hint("warn", has_been_used_hint)
		return
	
	DebugLogger.debug(module_name, "Starting interaction")
	start_interaction()

func start_interaction() -> void:
	if interact_sound:
		Audio.play_sound_3d(interact_sound).global_position = global_position
	
	if !allows_repeated_interaction:
		has_been_used = true
		interaction_text = unusable_interaction_text
		object_state_updated.emit(interaction_text)
		DebugLogger.debug(module_name, "Interaction used, updated text: " + interaction_text)
	
	is_player_interacting = true
	player_interaction_component.diegetic_ui_interaction_started(self)
	interaction_started.emit()
	set_process_input(true)
	
	DebugLogger.debug(module_name, "UI interaction started")

func _unhandled_input(event: InputEvent) -> void:
	if !is_player_interacting:
		return
	
	# Check for exit commands (menu or interact button again)
	if event.is_action_pressed("menu") or event.is_action_pressed("interact"):
		DebugLogger.debug(module_name, "Menu/Interact key pressed, ending interaction")
		end_interaction()
		get_viewport().set_input_as_handled()
		return
	
	# Forward non-mouse events directly
	if !(event is InputEventMouseButton or event is InputEventMouseMotion):
		sub_viewport.push_input(event)

# This uses area_3d and is called by the 3D world when the mouse is over the UI
func _input(event: InputEvent) -> void:
	if !is_player_interacting:
		return
		
	# Mouse input is only processed when the mouse is in visible mode
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		return

	# Only process mouse events
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Store the event to be processed during physics process
		pending_mouse_event = event.duplicate()
		get_viewport().set_input_as_handled()

# Process mouse raycast during physics process
func process_mouse_raycast(event: InputEvent) -> void:
	# Find where the mouse ray intersects with our UI
	var mouse_pos3D = find_mouse_physics_safe(event.global_position)
	
	if mouse_pos3D != Vector3.ZERO:
		last_mouse_hit = mouse_pos3D
		handle_mouse(event, mouse_pos3D)

# Handle mouse events for the UI
func handle_mouse(event: InputEvent, mouse_pos3D: Vector3) -> void:
	# Convert to local space relative to the Area3D
	mouse_pos3D = area_3d.global_transform.affine_inverse() * mouse_pos3D
	
	# Get the display mesh size
	var mesh_size = Vector2.ONE
	if display and display.mesh:
		if display.mesh is QuadMesh:
			mesh_size = display.mesh.size
		elif display.mesh is PlaneMesh:
			mesh_size = display.mesh.size
	
	# Convert 3D position to 2D coordinates
	var mouse_pos2D = Vector2(mouse_pos3D.x, -mouse_pos3D.y)
	
	# Normalize coordinates relative to mesh size
	mouse_pos2D.x += mesh_size.x / 2
	mouse_pos2D.y += mesh_size.y / 2
	
	# Convert to 0-1 range
	mouse_pos2D.x = mouse_pos2D.x / mesh_size.x
	mouse_pos2D.y = mouse_pos2D.y / mesh_size.y
	
	# Scale to viewport size
	mouse_pos2D.x = mouse_pos2D.x * sub_viewport.size.x
	mouse_pos2D.y = mouse_pos2D.y * sub_viewport.size.y
	
	# Duplicate the event with new coordinates
	var new_event = event.duplicate()
	new_event.position = mouse_pos2D
	new_event.global_position = mouse_pos2D
	
	DebugLogger.debug(module_name, "Converted mouse pos: " + str(event.position) + " -> " + str(mouse_pos2D))
	
	# Handle relative motion for mouse movement
	if event is InputEventMouseMotion:
		new_event.relative = Vector2(event.relative.x, event.relative.y) * (sub_viewport.size.x / get_viewport().size.x)
	
	# Send the event to the viewport
	sub_viewport.push_input(new_event)

# Find where the mouse ray intersects with our UI - safe to call during physics process
func find_mouse_physics_safe(pos: Vector2) -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if !camera:
		DebugLogger.error(module_name, "No camera found in viewport!")
		return Vector3.ZERO
	
	# This should only be called during physics process
	var space_state = get_world_3d().direct_space_state
	if !space_state:
		DebugLogger.error(module_name, "No direct space state available!")
		return Vector3.ZERO
		
	var ray_params = PhysicsRayQueryParameters3D.new()
	
	ray_params.from = camera.project_ray_origin(pos)
	ray_params.to = ray_params.from + camera.project_ray_normal(pos) * 100
	ray_params.collide_with_bodies = false
	ray_params.collide_with_areas = true
	
	var result = space_state.intersect_ray(ray_params)
	
	if result.size() > 0 and result.collider == area_3d:
		DebugLogger.debug(module_name, "Mouse hit at position: " + str(result.position))
		return result.position
	
	return Vector3.ZERO

func end_interaction() -> void:
	set_process_input(false)
	is_player_interacting = false
	pending_mouse_event = null
	last_mouse_hit = Vector3.ZERO
	
	# Start the cooldown to prevent immediate re-interaction
	cooldown = interaction_cooldown_time
	is_in_cooldown = true
	DebugLogger.debug(module_name, "Starting cooldown for " + str(interaction_cooldown_time) + " seconds")
	
	if player_interaction_component:
		player_interaction_component.diegetic_ui_interaction_ended()
	
	interaction_ended.emit()
	DebugLogger.debug(module_name, "UI interaction ended")

func on_damage_received() -> void:
	if is_player_interacting:
		end_interaction()
	DebugLogger.debug(module_name, "Damage received, ending interaction")

func force_end_interaction() -> void:
	if is_player_interacting:
		end_interaction()
	DebugLogger.debug(module_name, "Forced end of interaction")

func set_state() -> void:
	if has_been_used:
		interaction_text = unusable_interaction_text
	else:
		interaction_text = usable_interaction_text
	object_state_updated.emit(interaction_text)

# Helper method to check if UI can be interacted with
func can_interact() -> bool:
	return not is_disabled and not is_in_cooldown and cooldown <= 0 and not is_player_interacting

# NEW: Disable/enable the UI
func set_ui_enabled(enabled: bool) -> void:
	is_disabled = not enabled
	
	if is_disabled:
		black_out_display()
		# End any current interaction
		if is_player_interacting:
			end_interaction()
		interaction_text = unusable_interaction_text
	else:
		restore_display()
		interaction_text = usable_interaction_text
	
	object_state_updated.emit(interaction_text)
	DebugLogger.debug(module_name, "UI enabled state changed to: " + str(enabled))

# NEW: Black out the display
func black_out_display() -> void:
	if not display:
		DebugLogger.warning(module_name, "No display mesh assigned")
		return
	
	# Create a black material
	var black_material = StandardMaterial3D.new()
	black_material.albedo_color = Color.BLACK
	black_material.emission_enabled = false
	
	# Apply to the display
	display.material_override = black_material
	
	DebugLogger.debug(module_name, "Display blacked out")

# NEW: Restore the display to normal
func restore_display() -> void:
	if not display:
		DebugLogger.warning(module_name, "No display mesh assigned")
		return
	
	# Restore original material or create white material
	if original_material:
		display.material_override = original_material
	else:
		var white_material = StandardMaterial3D.new()
		white_material.albedo_color = Color.WHITE
		display.material_override = white_material
	
	DebugLogger.debug(module_name, "Display restored")

# Handle day reset
func _on_day_reset() -> void:
	if not reset_on_new_day:
		return
		
	DebugLogger.info(module_name, "Day reset signal received - resetting UI state")
	
	# End any current interaction
	if is_player_interacting:
		force_end_interaction()
	
	# Reset use state
	has_been_used = false
	
	# Reset cooldowns
	cooldown = 0
	is_in_cooldown = false
	
	# Re-enable UI if it was disabled
	if is_disabled:
		set_ui_enabled(true)
	
	# Reset interaction text
	interaction_text = usable_interaction_text
	object_state_updated.emit(interaction_text)
	
	# Call virtual method for child classes to implement specific reset behavior
	_on_day_reset_custom()
	
	DebugLogger.debug(module_name, "UI state reset completed")

# Virtual method for child classes to override for custom reset behavior
func _on_day_reset_custom() -> void:
	pass
