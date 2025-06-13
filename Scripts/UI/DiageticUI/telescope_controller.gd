# TelescopeController.gd
extends DiageticUIContent

# Signal emitted when telescope position changes
signal telescope_position_changed(x_normalized: float, y_normalized: float)
signal telescope_alligned()
@export var x_slider: HSlider
@export var y_slider: VSlider
@export var telescope_image: Control  # The image/element to move around

# UI Elements
@export var x_position_label: Label  # Shows X position
@export var y_position_label: Label  # Shows Y position
@export var status_label: Label  # "Telescope Misaligned" etc
@export var progress_bar: ProgressBar  # Calibration progress

# Calibration settings
@export var center_tolerance: float = 20.0  # How close to center counts as "aligned"
@export var calibration_time: float = 3.0  # Time to calibrate

@export var enable_debug: bool = true
var module_name: String = "TelescopeController"

# Movement bounds (will be calculated based on screen size)
var movement_bounds: Rect2
var image_half_size: Vector2

# Calibration state
var is_calibrating: bool = false
var is_aligned: bool = false
var calibration_timer: float = 0.0

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	if not x_slider:
		DebugLogger.error(module_name, "No X slider assigned!")
		return
	
	if not y_slider:
		DebugLogger.error(module_name, "No Y slider assigned!")
		return
	
	if not telescope_image:
		DebugLogger.error(module_name, "No telescope image assigned!")
		return
	
	# Connect slider signals
	x_slider.value_changed.connect(_on_x_slider_changed)
	y_slider.value_changed.connect(_on_y_slider_changed)
	
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
	
	# Set initial position
	_update_telescope_position()
	
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

func _on_x_slider_changed(_value: float) -> void:
	if not is_aligned:  # Only allow movement if not aligned
		_update_telescope_position()

func _on_y_slider_changed(_value: float) -> void:
	if not is_aligned:  # Only allow movement if not aligned
		_update_telescope_position()

func _update_telescope_position() -> void:
	if not telescope_image or not x_slider or not y_slider:
		return
	
	# Get normalized values (0.0 to 1.0) from sliders
	var x_normalized = (x_slider.value - x_slider.min_value) / (x_slider.max_value - x_slider.min_value)
	var y_normalized = (y_slider.value - y_slider.min_value) / (y_slider.max_value - y_slider.min_value)
	
	# Invert Y if slider up should mean image up
	# (depends on your slider setup - adjust if needed)
	y_normalized = 1.0 - y_normalized
	
	# Calculate the CENTER position of where the image should be
	var center_x = movement_bounds.position.x + (x_normalized * movement_bounds.size.x)
	var center_y = movement_bounds.position.y + (y_normalized * movement_bounds.size.y)
	
	# Adjust for the image's anchor point (top-left corner)
	# The position property sets the top-left corner, not the center
	var target_x = center_x - image_half_size.x
	var target_y = center_y - image_half_size.y
	
	# Set the position
	telescope_image.position = Vector2(target_x, target_y)
	
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
	
	# Debug output
	DebugLogger.debug(module_name, "Slider values - X: %.2f, Y: %.2f (normalized)" % [x_normalized, y_normalized])
	DebugLogger.debug(module_name, "Center position: (%.1f, %.1f)" % [center_x, center_y])
	DebugLogger.debug(module_name, "Top-left position: (%.1f, %.1f)" % [target_x, target_y])

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
	
	DebugLogger.info(module_name, "Started telescope calibration")

func _cancel_calibration() -> void:
	is_calibrating = false
	calibration_timer = 0.0
	
	if status_label:
		status_label.text = "Telescope Misaligned"
	
	if progress_bar:
		progress_bar.value = 0.0
	
	DebugLogger.info(module_name, "Calibration cancelled - telescope moved")

func _complete_calibration() -> void:
	is_calibrating = false
	is_aligned = true
	
	if status_label:
		status_label.text = "Telescope Aligned"
	
	if progress_bar:
		progress_bar.value = 100.0
	
	# Disable sliders
	if x_slider:
		x_slider.editable = false
		x_slider.modulate.a = 0.5  # Make it look disabled
	
	if y_slider:
		y_slider.editable = false
		y_slider.modulate.a = 0.5  # Make it look disabled
	
	DebugLogger.info(module_name, "Telescope calibration complete!")
	telescope_alligned.emit()

# Call this if screen size changes
func _on_screen_resized() -> void:
	_calculate_movement_bounds()
	_update_telescope_position()
	DebugLogger.debug(module_name, "Screen resized, recalculated bounds")

# Helper function to set telescope to specific normalized position
func set_telescope_position(x_normalized: float, y_normalized: float) -> void:
	if x_slider and y_slider and not is_aligned:
		x_slider.value = x_slider.min_value + (x_normalized * (x_slider.max_value - x_slider.min_value))
		# Invert Y for the slider since we invert it in the position calculation
		var inverted_y = 1.0 - y_normalized
		y_slider.value = y_slider.min_value + (inverted_y * (y_slider.max_value - y_slider.min_value))

# Reset the telescope alignment (for testing or restarting)
func reset_alignment() -> void:
	is_aligned = false
	is_calibrating = false
	calibration_timer = 0.0
	
	if status_label:
		status_label.text = "Telescope Misaligned"
	
	if progress_bar:
		progress_bar.value = 0.0
	
	# Re-enable sliders
	if x_slider:
		x_slider.editable = true
		x_slider.modulate.a = 1.0
	
	if y_slider:
		y_slider.editable = true
		y_slider.modulate.a = 1.0
	
	DebugLogger.info(module_name, "Telescope alignment reset")

# Test functions to verify positioning
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

# Get current alignment status
func is_telescope_aligned() -> bool:
	return is_aligned

## Override reset method to reset telescope to initial state
func reset_ui() -> void:
	DebugLogger.debug(module_name, "Resetting telescope UI to initial state")
	reset_alignment()
	
	# Reset sliders to random positions avoiding center
	if x_slider:
		var center = (x_slider.min_value + x_slider.max_value) * 0.5
		var range_size = x_slider.max_value - x_slider.min_value
		# Pick either lower third or upper third, avoiding middle third
		if randf() < 0.5:
			# Lower third (0.0 to 0.33)
			x_slider.value = x_slider.min_value + randf_range(0.0, 0.33) * range_size
		else:
			# Upper third (0.67 to 1.0)
			x_slider.value = x_slider.min_value + randf_range(0.67, 1.0) * range_size
	
	if y_slider:
		var center = (y_slider.min_value + y_slider.max_value) * 0.5
		var range_size = y_slider.max_value - y_slider.min_value
		# Pick either lower third or upper third, avoiding middle third
		if randf() < 0.5:
			# Lower third (0.0 to 0.33)
			y_slider.value = y_slider.min_value + randf_range(0.0, 0.33) * range_size
		else:
			# Upper third (0.67 to 1.0)
			y_slider.value = y_slider.min_value + randf_range(0.67, 1.0) * range_size
	
	_update_telescope_position()
