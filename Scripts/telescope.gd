# PhysicalTelescope.gd
extends Node3D

# Rotation bounds in degrees
@export_group("Rotation Bounds")
@export var x_rotation_min: float = -45.0  # Right
@export var x_rotation_max: float = 45.0   # Left
@export var y_rotation_min: float = -30.0  # Up
@export var y_rotation_max: float = 30.0   # Down

# Mesh references
@export_group("Telescope Parts")
@export var base_mesh: Node3D  # The base that rotates left/right (Y axis)
@export var scope_mesh: Node3D  # The scope that rotates up/down (X axis)

# Rotation speed
@export var rotation_speed: float = 2.0  # How fast to lerp to target rotation

# Connection
@export var diegetic_telescope_ui: Node  # Assign the TelescopeDiegeticUI node

# Debug
@export var enable_debug: bool = true
var module_name: String = "PhysicalTelescope"

# Target rotations
var target_base_rotation: float = 0.0
var target_scope_rotation: float = 0.0

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if not base_mesh:
		DebugLogger.error(module_name, "No base mesh assigned!")
		return
		
	if not scope_mesh:
		DebugLogger.error(module_name, "No scope mesh assigned!")
		return
	
	# Connect to diegetic UI if assigned
	if diegetic_telescope_ui:
		_connect_to_diegetic_ui()
	else:
		DebugLogger.warning(module_name, "No diegetic telescope UI assigned!")
	
	DebugLogger.debug(module_name, "Physical telescope initialized")
	DebugLogger.debug(module_name, "X bounds: %.1f to %.1f degrees" % [x_rotation_min, x_rotation_max])
	DebugLogger.debug(module_name, "Y bounds: %.1f to %.1f degrees" % [y_rotation_min, y_rotation_max])

func _physics_process(delta: float) -> void:
	# Smoothly rotate to target positions
	if base_mesh:
		var current_z = base_mesh.rotation_degrees.z
		base_mesh.rotation_degrees.z = lerp(current_z, target_base_rotation, rotation_speed * delta)
	
	if scope_mesh:
		var current_x = scope_mesh.rotation_degrees.x
		scope_mesh.rotation_degrees.x = lerp(current_x, target_scope_rotation, rotation_speed * delta)

func _connect_to_diegetic_ui() -> void:
	"""Connect to the assigned diegetic UI"""
	if diegetic_telescope_ui.has_signal("telescope_adjusted"):
		diegetic_telescope_ui.telescope_adjusted.connect(_on_telescope_adjusted)
		DebugLogger.debug(module_name, "Connected to diegetic telescope UI")
	else:
		DebugLogger.error(module_name, "Diegetic UI doesn't have telescope_adjusted signal!")

func _on_telescope_adjusted(x_normalized: float, y_normalized: float) -> void:
	"""Handle telescope position updates from the UI"""
	DebugLogger.debug(module_name, "Received position update - X: %.2f, Y: %.2f" % [x_normalized, y_normalized])
	
	# Convert normalized values (0-1) to rotation degrees
	# X controls base Y rotation (left/right)
	# Note: You might need to invert these depending on your setup
	target_base_rotation = lerp(x_rotation_min, x_rotation_max, x_normalized)
	
	# Y controls scope X rotation (up/down)
	# Invert Y since UI Y=0 is top, but rotation Y=0 might be center
	target_scope_rotation = lerp(y_rotation_max, y_rotation_min, y_normalized)
	
	DebugLogger.debug(module_name, "Target rotations - Base Y: %.1f°, Scope X: %.1f°" % [target_base_rotation, target_scope_rotation])

func set_telescope_position(x_normalized: float, y_normalized: float) -> void:
	"""Directly set telescope position (useful for testing)"""
	_on_telescope_adjusted(x_normalized, y_normalized)

func get_current_rotations() -> Dictionary:
	"""Get current rotation values"""
	return {
		"base_y": base_mesh.rotation_degrees.y if base_mesh else 0.0,
		"scope_x": scope_mesh.rotation_degrees.x if scope_mesh else 0.0,
		"target_base_y": target_base_rotation,
		"target_scope_x": target_scope_rotation
	}

# Test functions
func test_extremes() -> void:
	"""Test all extreme positions"""
	DebugLogger.info(module_name, "Testing telescope extremes...")
	
	# Test each corner
	set_telescope_position(0.0, 0.0)  # Right-Up
	await get_tree().create_timer(2.0).timeout
	
	set_telescope_position(1.0, 0.0)  # Left-Up
	await get_tree().create_timer(2.0).timeout
	
	set_telescope_position(0.0, 1.0)  # Right-Down
	await get_tree().create_timer(2.0).timeout
	
	set_telescope_position(1.0, 1.0)  # Left-Down
	await get_tree().create_timer(2.0).timeout
	
	set_telescope_position(0.5, 0.5)  # Center
	DebugLogger.info(module_name, "Test complete")
