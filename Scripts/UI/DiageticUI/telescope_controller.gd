# TelescopeController.gd
extends DiageticUIContent

# Signal emitted when telescope position changes
signal telescope_position_changed(x_normalized: float, y_normalized: float)
signal telescope_alligned()

## The image/element to move around
@export var telescope_image: Control

## Shows X position
@export var x_position_label: Label
## Shows Y position  
@export var y_position_label: Label
## "Telescope Misaligned" etc
@export var status_label: Label
## Calibration progress
@export var progress_bar: ProgressBar

## How close to center counts as "aligned"
@export var center_tolerance: float = 20.0
## Time to calibrate
@export var calibration_time: float = 3.0
## Movement tween duration in seconds
@export var movement_duration: float = 0.5
## Enable debug logging
@export var enable_debug: bool = true

var module_name: String = "TelescopeController"

# Movement bounds (will be calculated based on screen size)
var movement_bounds: Rect2
var image_half_size: Vector2

# Calibration state
var is_calibrating: bool = false
var is_aligned: bool = false
var calibration_timer: float = 0.0

# Movement tween
var movement_tween: Tween

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if not telescope_image:
		DebugLogger.error(module_name, "No telescope image assigned!")
		return
	
	# Wait a frame to ensure sizes are calculated
	await get_tree().process_frame
	
	# Store half size of the image for centering calculations
	image_half_size = telescope_image.size * 0.5
	
	# Calculate movement bounds based on screen size
	_calculate_movement_bounds()
	
	# Initialize UI
	if progress_bar:
		progress_bar.value = 0.0
		progress_bar.max_value = 100.0
	
	if status_label:
		status_label.text = "Telescope Misaligned"
	
	# Set initial random position
	_set_random_initial_position()
	
	DebugLogger.debug(module_name, "Telescope controller initialized")
	DebugLogger.debug(module_name, "Image size: " + str(telescope_image.size))

func _process(delta: float) -> void:
	# Handle calibration timer
	if is_calibrating and not is_aligned:
		calibration_timer += delta
		
		# Update progress bar
		if progress_bar:
			var progress = (calibration_timer / calibration_time) * 100.0
			progress_bar.value = progress
		
		# Check if calibration is complete
		if calibration_timer >= calibration_time:
			_complete_calibration()

func _input(event: InputEvent) -> void:
	if not telescope_image or is_aligned:
		return
		
	# Handle mouse clicks
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_move_telescope_to_position(event.position)

func _calculate_movement_bounds() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	DebugLogger.debug(module_name, "Screen size: " + str(screen_size))
	
	# The actual movement area is smaller than the screen
	# Based on your values for 1920x1080:
	# Width: 1664 pixels out of 1920 = 86.67%
	# Height: 824.4 pixels out of 1080 = 76.33%
	var width_ratio = 0.8667
	var height_ratio = 0.7633
	
	# Calculate actual movement area
	var movement_width = screen_size.x * width_ratio
	var movement_height = screen_size.y * height_ratio
	
	# The movement bounds represent where the CENTER of the image can go
	# So we need to account for the image's half-size
	var x_offset = (screen_size.x - movement_width) * 0.5
	var y_offset = (screen_size.y - movement_height) * 0.5
	
	movement_bounds = Rect2(x_offset, y_offset, movement_width, movement_height)
	
	DebugLogger.debug(module_name, "Movement bounds: " + str(movement_bounds))

func _move_telescope_to_position(target_pos: Vector2) -> void:
	# Stop any existing tween
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	
	# Play neutral sound for movement
	play_neutral_sound()
	
	# Clamp the target position to movement bounds
	# Account for image center vs top-left position
	var clamped_center = Vector2(
		clamp(target_pos.x, movement_bounds.position.x, movement_bounds.position.x + movement_bounds.size.x),
		clamp(target_pos.y, movement_bounds.position.y, movement_bounds.position.y + movement_bounds.size.y)
	)
	
	# Convert center position to top-left position for the image
	var target_top_left = clamped_center - image_half_size
	
	# Create tween for smooth movement
	movement_tween = create_tween()
	movement_tween.set_ease(Tween.EASE_IN_OUT)
	movement_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Use a method tweener to update position info during movement
	movement_tween.tween_method(_tween_position, telescope_image.position, target_top_left, movement_duration)
	
	DebugLogger.debug(module_name, "Moving telescope to: " + str(target_top_left))

func _tween_position(new_position: Vector2) -> void:
	telescope_image.position = new_position
	_update_position_info()

func _update_position_info() -> void:
	if not telescope_image:
		return
	
	# Get current center position
	var current_center = telescope_image.position + image_half_size
	
	# Calculate normalized position (0.0 to 1.0)
	var x_normalized = (current_center.x - movement_bounds.position.x) / movement_bounds.size.x
	var y_normalized = (current_center.y - movement_bounds.position.y) / movement_bounds.size.y
	
	# Clamp to valid range
	x_normalized = clamp(x_normalized, 0.0, 1.0)
	y_normalized = clamp(y_normalized, 0.0, 1.0)
	
	# Update position labels with normalized values
	if x_position_label:
		x_position_label.text = "X: %d" % int(x_normalized * 100)
	
	if y_position_label:
		y_position_label.text = "Y: %d" % int(y_normalized * 100)
	
	# Check if we're near center (only if not already aligned)
	if not is_aligned:
		_check_alignment(x_normalized, y_normalized)
	
	# Emit position changed signal
	telescope_position_changed.emit(x_normalized, y_normalized)

func _check_alignment(x_norm: float, y_norm: float) -> void:
	# Check if we're close to center (0.5, 0.5 in normalized coords)
	var x_distance = abs(x_norm - 0.5) * 100  # Convert to percentage
	var y_distance = abs(y_norm - 0.5) * 100
	
	var distance_from_center = sqrt(x_distance * x_distance + y_distance * y_distance)
	
	if distance_from_center <= center_tolerance:
		# We're at the center
		if not is_calibrating:
			_start_calibration()
	else:
		# We moved away from center
		if is_calibrating:
			_cancel_calibration()

func _start_calibration() -> void:
	is_calibrating = true
	calibration_timer = 0.0
	
	if status_label:
		status_label.text = "Telescope Calibrating"
	
	if progress_bar:
		progress_bar.value = 0.0
	
	# Play positive sound for entering calibration zone
	play_positive_sound()
	
	DebugLogger.info(module_name, "Started telescope calibration")

func _cancel_calibration() -> void:
	is_calibrating = false
	calibration_timer = 0.0
	
	if status_label:
		status_label.text = "Telescope Misaligned"
	
	if progress_bar:
		progress_bar.value = 0.0
	
	# Play negative sound for leaving calibration zone
	play_negative_sound()
	
	DebugLogger.info(module_name, "Calibration cancelled - telescope moved")

func _complete_calibration() -> void:
	is_calibrating = false
	is_aligned = true
	
	if status_label:
		status_label.text = "Telescope Aligned"
	
	if progress_bar:
		progress_bar.value = 100.0
	
	# Stop any movement
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	
	# Play victory sound for successful alignment
	play_victory_sound()
	
	DebugLogger.info(module_name, "Telescope calibration complete!")
	telescope_alligned.emit()

## Call this if screen size changes
func _on_screen_resized() -> void:
	_calculate_movement_bounds()
	DebugLogger.debug(module_name, "Screen resized, recalculated bounds")

## Helper function to set telescope to specific normalized position
func set_telescope_position(x_normalized: float, y_normalized: float) -> void:
	if not is_aligned:
		# Calculate target center position from normalized values
		var target_center = Vector2(
			movement_bounds.position.x + (x_normalized * movement_bounds.size.x),
			movement_bounds.position.y + (y_normalized * movement_bounds.size.y)
		)
		
		# Convert to top-left position
		var target_pos = target_center - image_half_size
		telescope_image.position = target_pos
		_update_position_info()

## Reset the telescope alignment (for testing or restarting)
func reset_alignment() -> void:
	is_aligned = false
	is_calibrating = false
	calibration_timer = 0.0
	
	if status_label:
		status_label.text = "Telescope Misaligned"
	
	if progress_bar:
		progress_bar.value = 0.0
	
	# Play neutral sound for reset
	play_neutral_sound()
	
	DebugLogger.info(module_name, "Telescope alignment reset")

## Set initial random position avoiding center
func _set_random_initial_position() -> void:
	# Pick random position avoiding the center area
	var x_norm: float
	var y_norm: float
	
	# Pick either lower third or upper third for X, avoiding middle third
	if randf() < 0.5:
		x_norm = randf_range(0.0, 0.33)
	else:
		x_norm = randf_range(0.67, 1.0)
	
	# Pick either lower third or upper third for Y, avoiding middle third
	if randf() < 0.5:
		y_norm = randf_range(0.0, 0.33)
	else:
		y_norm = randf_range(0.67, 1.0)
	
	set_telescope_position(x_norm, y_norm)

## Test functions to verify positioning
func test_corners() -> void:
	DebugLogger.info(module_name, "Testing corner positions...")
	
	# Test top-left (should be at 0, 0)
	set_telescope_position(0.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	DebugLogger.info(module_name, "Top-left position: " + str(telescope_image.position))
	
	# Test top-right (should be at ~1664, 0 for 1920x1080)
	set_telescope_position(1.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	DebugLogger.info(module_name, "Top-right position: " + str(telescope_image.position))
	
	# Test bottom-left (should be at 0, ~824.4 for 1920x1080)
	set_telescope_position(0.0, 1.0)
	await get_tree().create_timer(1.0).timeout
	DebugLogger.info(module_name, "Bottom-left position: " + str(telescope_image.position))
	
	# Test bottom-right (should be at ~1664, ~824.4 for 1920x1080)
	set_telescope_position(1.0, 1.0)
	await get_tree().create_timer(1.0).timeout
	DebugLogger.info(module_name, "Bottom-right position: " + str(telescope_image.position))
	
	# Test center (should be at ~832, ~412 for 1920x1080)
	set_telescope_position(0.5, 0.5)
	await get_tree().create_timer(1.0).timeout
	DebugLogger.info(module_name, "Center position: " + str(telescope_image.position))

## Get current alignment status
func is_telescope_aligned() -> bool:
	return is_aligned

## Override reset method to reset telescope to initial state
func reset_ui() -> void:
	DebugLogger.debug(module_name, "Resetting telescope UI to initial state")
	reset_alignment()
	_set_random_initial_position()
