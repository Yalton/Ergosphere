# DataTetrisControl.gd
extends DiageticUIContent

## Signal emitted when required lines are cleared and data is "transmitted"
signal transmission_completed

## Grid Settings
@export_group("Grid")
## Grid width in blocks
@export var grid_width: int = 10
## Grid height in blocks
@export var grid_height: int = 20
## Size of each block in pixels
@export var block_size: int = 30

## Game Settings
@export_group("Game Settings")
## Number of lines to clear to complete transmission
@export var lines_required: int = 5
## Initial fall speed (seconds between drops)
@export var initial_fall_speed: float = 1.0
## Speed increase per line cleared
@export var speed_increase: float = 0.1
## Minimum fall speed (fastest)
@export var min_fall_speed: float = 0.1

## UI References
@export_group("UI")
## Start screen container
@export var start_screen: Control
## Game screen container
@export var game_screen: Control
## Start button on the start screen
@export var start_button: Button
## Container that holds the grid display
@export var grid_container: Control
## Label showing current status
@export var status_label: Label
## Label showing lines cleared
@export var lines_label: Label
## Label showing data packets sent
@export var data_label: Label
## Progress bar for transmission
@export var progress_bar: ProgressBar
## RichTextLabel for hex data feed
@export var hex_feed: RichTextLabel

## Visual Settings
@export_group("Visual")
## Colors for different data block types
@export var block_colors: Array[Color] = [
	Color(0.2, 0.8, 0.8),  # Cyan - System Data
	Color(0.8, 0.8, 0.2),  # Yellow - Research Data
	Color(0.8, 0.2, 0.8),  # Magenta - Telemetry
	Color(0.2, 0.8, 0.2),  # Green - Logs
	Color(0.8, 0.4, 0.2),  # Orange - Environmental
	Color(0.2, 0.4, 0.8),  # Blue - Personnel
	Color(0.8, 0.2, 0.2)   # Red - Critical
]
## Background color for empty cells
@export var empty_color: Color = Color(0.1, 0.1, 0.1)
## Grid line color
@export var grid_line_color: Color = Color(0.2, 0.2, 0.2)

# Tetromino shapes (standard 7 pieces)
var SHAPES = [
	[ # I-piece
		[0,0,0,0],
		[1,1,1,1],
		[0,0,0,0],
		[0,0,0,0]
	],
	[ # O-piece
		[1,1],
		[1,1]
	],
	[ # T-piece
		[0,1,0],
		[1,1,1],
		[0,0,0]
	],
	[ # S-piece
		[0,1,1],
		[1,1,0],
		[0,0,0]
	],
	[ # Z-piece
		[1,1,0],
		[0,1,1],
		[0,0,0]
	],
	[ # J-piece
		[1,0,0],
		[1,1,1],
		[0,0,0]
	],
	[ # L-piece
		[0,0,1],
		[1,1,1],
		[0,0,0]
	]
]

var grid: Array = []
var current_piece: Dictionary = {}
var next_piece_type: int = -1
var lines_cleared: int = 0
var current_fall_speed: float = 1.0
var fall_timer: float = 0.0
var game_active: bool = false
var game_over: bool = false
var game_paused: bool = false
var grid_cells: Array = []  # Visual representation
var module_name: String = "DataTetrisControl"
var hex_data_blocks: Array[String] = []  # Store hex blocks for display

func _ready() -> void:
	DebugLogger.register_module(module_name, true)
	
	# Initialize grid
	_initialize_grid()
	_create_visual_grid()
	
	# Setup UI
	_update_ui()
	
	# Setup start screen
	if start_screen and game_screen:
		game_screen.hide()
		start_screen.show()
		
		# Connect start button if available
		if start_button:
			start_button.pressed.connect(_on_start_pressed)
	else:
		# If no start screen, start game directly
		start_game()
	
	DebugLogger.debug(module_name, "Data Tetris initialized")

func _on_start_pressed() -> void:
	DebugLogger.debug(module_name, "Start button pressed")
	
	# Play neutral sound for game start
	play_neutral_sound()
	
	# Switch screens
	if start_screen:
		start_screen.hide()
	if game_screen:
		game_screen.show()
	
	# Start the game
	start_game()

func _initialize_grid() -> void:
	grid.clear()
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			row.append(0)
		grid.append(row)
	
	DebugLogger.debug(module_name, "Grid initialized: %dx%d" % [grid_width, grid_height])

func _create_visual_grid() -> void:
	if not grid_container:
		DebugLogger.error(module_name, "Grid container not assigned!")
		return
	
	# Clear existing cells
	for child in grid_container.get_children():
		child.queue_free()
	
	grid_cells.clear()
	
	# Calculate block size based on available space
	await get_tree().process_frame  # Wait for container to update
	var container_size = grid_container.get_rect().size
	if container_size.x > 0 and container_size.y > 0:
		# Calculate block size to fit the container
		var block_width = int(container_size.x / grid_width)
		var block_height = int(container_size.y / grid_height)
		# Use the smaller dimension to maintain square blocks
		block_size = min(block_width, block_height)
		DebugLogger.debug(module_name, "Dynamic block size: %d (container: %s)" % [block_size, container_size])
	
	# If it's a GridContainer, set columns
	if grid_container is GridContainer:
		grid_container.columns = grid_width
		# Create grid of ColorRects for GridContainer
		for y in range(grid_height):
			var row = []
			for x in range(grid_width):
				var cell = ColorRect.new()
				cell.custom_minimum_size = Vector2(block_size, block_size)
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
				cell.color = empty_color
				grid_container.add_child(cell)
				row.append(cell)
			grid_cells.append(row)
	else:
		# Use absolute positioning for regular Control
		for y in range(grid_height):
			var row = []
			for x in range(grid_width):
				var cell = ColorRect.new()
				cell.size = Vector2(block_size, block_size)
				cell.position = Vector2(x * block_size, y * block_size)
				cell.color = empty_color
				grid_container.add_child(cell)
				row.append(cell)
			grid_cells.append(row)
		
		# Set container size for regular Control
		grid_container.custom_minimum_size = Vector2(grid_width * block_size, grid_height * block_size)
	
	DebugLogger.debug(module_name, "Visual grid created")

func start_game() -> void:
	if game_active:
		return
	
	DebugLogger.info(module_name, "Starting Data Tetris game")
	
	# Reset game state
	_initialize_grid()
	lines_cleared = 0
	current_fall_speed = initial_fall_speed
	fall_timer = 0.0
	game_over = false
	game_active = true
	game_paused = false
	hex_data_blocks.clear()
	
	# Clear hex feed
	if hex_feed:
		hex_feed.clear()
	
	# Spawn first piece
	_spawn_new_piece()
	
	# Update UI
	_update_ui()
	
	if status_label:
		status_label.text = "COMPRESSING DATA BLOCKS..."

func pause_game() -> void:
	game_paused = true
	DebugLogger.debug(module_name, "Game paused")

func resume_game() -> void:
	game_paused = false
	DebugLogger.debug(module_name, "Game resumed")

func _process(delta: float) -> void:
	if not game_active or game_over or game_paused:
		return
	
	# Handle falling
	fall_timer += delta
	if fall_timer >= current_fall_speed:
		fall_timer = 0.0
		_move_piece_down()

func _input(event: InputEvent) -> void:
	if not game_active or game_over or game_paused:
		return
	
	# Handle WASD controls - using the actual input map actions
	if event.is_action_pressed("a"):  # Move left
		_move_piece_left()
	elif event.is_action_pressed("d"):  # Move right
		_move_piece_right()
	elif event.is_action_pressed("w"):  # Rotate
		_rotate_piece()
	elif event.is_action_pressed("s"):  # Hard drop - instant drop to bottom
		_hard_drop()

func _spawn_new_piece() -> void:
	# Pick random shape
	var shape_type = randi() % SHAPES.size()
	var shape = SHAPES[shape_type]
	
	# Create piece dictionary
	current_piece = {
		"shape": shape,
		"x": grid_width / 2 - shape[0].size() / 2,
		"y": 0,
		"type": shape_type
	}
	
	# Check if piece can spawn - this is our lose condition check
	if not _can_place_piece(current_piece.x, current_piece.y, current_piece.shape):
		_game_over()
		return
	
	# Place piece on grid
	_place_piece_on_grid()
	_update_visual_grid()
	
	DebugLogger.debug(module_name, "Spawned new piece type %d" % shape_type)

func _move_piece_left() -> void:
	_clear_piece_from_grid()
	
	if _can_place_piece(current_piece.x - 1, current_piece.y, current_piece.shape):
		current_piece.x -= 1
		# No move sound - keeping it minimal
	
	_place_piece_on_grid()
	_update_visual_grid()

func _move_piece_right() -> void:
	_clear_piece_from_grid()
	
	if _can_place_piece(current_piece.x + 1, current_piece.y, current_piece.shape):
		current_piece.x += 1
		# No move sound - keeping it minimal
	
	_place_piece_on_grid()
	_update_visual_grid()

func _rotate_piece() -> void:
	_clear_piece_from_grid()
	
	var rotated = _rotate_matrix(current_piece.shape)
	
	if _can_place_piece(current_piece.x, current_piece.y, rotated):
		current_piece.shape = rotated
		play_neutral_sound()  # Use parent class audio
	
	_place_piece_on_grid()
	_update_visual_grid()

func _hard_drop() -> void:
	# Move piece down by one cell immediately
	_clear_piece_from_grid()
	
	if _can_place_piece(current_piece.x, current_piece.y + 1, current_piece.shape):
		current_piece.y += 1
		_place_piece_on_grid()
		_update_visual_grid()
	else:
		# Piece has landed
		_place_piece_on_grid()
		_update_visual_grid()
		
		# Small drop sound using neutral
		play_neutral_sound()
		
		# Check for completed lines
		_check_lines()
		
		# Spawn next piece
		_spawn_new_piece()

func _move_piece_down() -> void:
	_clear_piece_from_grid()
	
	if _can_place_piece(current_piece.x, current_piece.y + 1, current_piece.shape):
		current_piece.y += 1
	else:
		# Piece has landed
		_place_piece_on_grid()
		
		# Small drop sound using neutral
		play_neutral_sound()
		
		# Check for completed lines
		_check_lines()
		
		# Spawn next piece
		_spawn_new_piece()
		return
	
	_place_piece_on_grid()
	_update_visual_grid()

func _can_place_piece(x: int, y: int, shape: Array) -> bool:
	for row in range(shape.size()):
		for col in range(shape[row].size()):
			if shape[row][col] == 1:
				var grid_x = x + col
				var grid_y = y + row
				
				# Check bounds
				if grid_x < 0 or grid_x >= grid_width:
					return false
				if grid_y < 0 or grid_y >= grid_height:
					return false
				
				# Check collision - fixed to properly check for any non-zero value
				if grid[grid_y][grid_x] != 0:
					return false
	
	return true

func _clear_piece_from_grid() -> void:
	for row in range(current_piece.shape.size()):
		for col in range(current_piece.shape[row].size()):
			if current_piece.shape[row][col] == 1:
				var grid_x = current_piece.x + col
				var grid_y = current_piece.y + row
				if grid_y >= 0 and grid_y < grid_height and grid_x >= 0 and grid_x < grid_width:
					grid[grid_y][grid_x] = 0

func _place_piece_on_grid() -> void:
	for row in range(current_piece.shape.size()):
		for col in range(current_piece.shape[row].size()):
			if current_piece.shape[row][col] == 1:
				var grid_x = current_piece.x + col
				var grid_y = current_piece.y + row
				if grid_y >= 0 and grid_y < grid_height and grid_x >= 0 and grid_x < grid_width:
					grid[grid_y][grid_x] = current_piece.type + 1

func _rotate_matrix(matrix: Array) -> Array:
	var n = matrix.size()
	var rotated = []
	
	for i in range(n):
		var row = []
		for j in range(n):
			row.append(matrix[n - 1 - j][i])
		rotated.append(row)
	
	return rotated

func _check_lines() -> void:
	var lines_to_clear = []
	
	# Find complete lines
	for y in range(grid_height):
		var complete = true
		for x in range(grid_width):
			if grid[y][x] == 0:
				complete = false
				break
		
		if complete:
			lines_to_clear.append(y)
	
	if lines_to_clear.is_empty():
		return
	
	# Clear lines
	for line in lines_to_clear:
		grid.remove_at(line)
		# Add empty line at top
		var new_row = []
		for x in range(grid_width):
			new_row.append(0)
		grid.insert(0, new_row)
	
	# Update stats
	lines_cleared += lines_to_clear.size()
	
	# Generate hex data for each line cleared
	for i in range(lines_to_clear.size()):
		_add_hex_data_block()
	
	# Play positive sound for line clear
	play_positive_sound()
	
	# Increase speed
	current_fall_speed = max(min_fall_speed, initial_fall_speed - (lines_cleared * speed_increase))
	
	# Update UI
	_update_ui()
	_update_visual_grid()
	
	DebugLogger.info(module_name, "Cleared %d lines, total: %d" % [lines_to_clear.size(), lines_cleared])
	
	# Check win condition
	if lines_cleared >= lines_required:
		_transmission_complete()

func _add_hex_data_block() -> void:
	if not hex_feed:
		return
	
	# Generate random hex block
	var hex_block = _generate_random_hex_block()
	hex_data_blocks.append(hex_block)
	
	# Add to feed with formatting
	hex_feed.append_text("[color=#00ff00]DATA PACKET %03d:[/color] " % hex_data_blocks.size())
	hex_feed.append_text("[color=#808080]%s[/color]\n" % hex_block)
	
	# Auto-scroll to bottom
	hex_feed.scroll_to_line(hex_feed.get_line_count() - 1)

func _generate_random_hex_block() -> String:
	var hex_chars = "0123456789ABCDEF"
	var block_size = 32  # Number of hex characters
	var result = ""
	
	for i in range(block_size):
		if i > 0 and i % 2 == 0:
			result += " "  # Add space every 2 characters
		result += hex_chars[randi() % hex_chars.length()]
	
	return result

func _update_visual_grid() -> void:
	if grid_cells.is_empty():
		return
	
	for y in range(grid_height):
		for x in range(grid_width):
			var value = grid[y][x]
			if value == 0:
				grid_cells[y][x].color = empty_color
			else:
				var color_index = (value - 1) % block_colors.size()
				grid_cells[y][x].color = block_colors[color_index]

func _update_ui() -> void:
	if lines_label:
		lines_label.text = "Lines Cleared: %d/%d" % [lines_cleared, lines_required]
	
	if data_label:
		var percent = (float(lines_cleared) / float(lines_required)) * 100.0
		data_label.text = "Data Compressed: %.0f%%" % percent
	
	if progress_bar:
		progress_bar.value = float(lines_cleared) / float(lines_required) * 100.0

func _game_over() -> void:
	game_over = true
	game_active = false
	
	DebugLogger.info(module_name, "Game Over - blocks reached top!")
	
	# Play negative sound for game over
	play_negative_sound()
	
	if status_label:
		status_label.text = "DATA CORRUPTION - RETRYING..."
	
	# Auto-restart after delay
	await get_tree().create_timer(2.0).timeout
	
	# Return to start screen if available, otherwise restart directly
	if start_screen and game_screen:
		game_screen.hide()
		start_screen.show()
	else:
		start_game()

func _transmission_complete() -> void:
	game_active = false
	
	DebugLogger.info(module_name, "Transmission complete!")
	
	# Play victory sound for success
	play_victory_sound()
	
	if status_label:
		status_label.text = "DATA COMPRESSED - TRANSMITTING TO EARTH..."
	
	# Emit completion signal
	await get_tree().create_timer(2.0).timeout
	transmission_completed.emit()
	
	# Return to start screen after completion
	if start_screen and game_screen:
		await get_tree().create_timer(1.0).timeout
		game_screen.hide()
		start_screen.show()
