# SnakeGame.gd
extends DiageticUIContent
class_name SnakeGame

signal game_completed(final_length: int)

## Grid size for the game area
@export var grid_size: Vector2i = Vector2i(20, 15)

## Size of each grid cell in pixels
@export var cell_size: int = 20

## Game speed (seconds between moves)
@export var move_interval: float = 0.3

## Target length to win the game
@export var target_length: int = 10

## Colors
@export var snake_color: Color = Color.GREEN
@export var food_color: Color = Color.RED
@export var wall_color: Color = Color.GRAY
@export var background_color: Color = Color.BLACK

## UI Elements
@export var start_screen: Control
@export var game_screen: Control
@export var game_grid: GridContainer
@export var progress_bar: ProgressBar
@export var length_label: Label
@export var start_button: Button
@export var game_over_label: Label

## Enable debug logging
@export var enable_debug: bool = true
var module_name: String = "SnakeGame"

# Game state
var snake_positions: Array[Vector2i] = []
var food_position: Vector2i
var direction: Vector2i = Vector2i.RIGHT
var next_direction: Vector2i = Vector2i.RIGHT
var game_active: bool = false
var move_timer: Timer

# Visual elements
var cell_rects: Array[ColorRect] = []

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create move timer
	move_timer = Timer.new()
	move_timer.wait_time = move_interval
	move_timer.timeout.connect(_move_snake)
	add_child(move_timer)
	
	# Connect start button
	if start_button:
		start_button.pressed.connect(_start_game)
	
	# Initialize screens
	_show_start_screen()
	
	# Get grid cells
	_get_grid_cells()
	_reset_game()
	
	DebugLogger.debug(module_name, "Snake game initialized")

func _get_grid_cells() -> void:
	if not game_grid:
		DebugLogger.error(module_name, "No game grid assigned!")
		return
	
	# Set grid columns
	game_grid.columns = grid_size.x
	
	# Clear existing cells
	for rect in cell_rects:
		rect.queue_free()
	cell_rects.clear()
	
	# Create grid cells with expand
	for i in range(grid_size.x * grid_size.y):
		var cell = ColorRect.new()
		cell.color = background_color
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		game_grid.add_child(cell)
		cell_rects.append(cell)
	
	DebugLogger.debug(module_name, "Created " + str(cell_rects.size()) + " expandable grid cells")

func _reset_game() -> void:
	# Reset snake to center
	snake_positions.clear()
	var start_pos = Vector2i(grid_size.x / 2, grid_size.y / 2)
	snake_positions.append(start_pos)
	
	# Reset direction
	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT
	
	# Spawn food
	_spawn_food()
	
	# Update UI
	_update_progress()
	_update_visuals()
	
	# Hide game over label
	if game_over_label:
		game_over_label.visible = false

func _start_game() -> void:
	if game_active:
		return
	
	DebugLogger.debug(module_name, "Starting snake game")
	
	# Play neutral sound for game start
	play_neutral_sound()
	
	# Switch to game screen
	_show_game_screen()
	
	game_active = true
	move_timer.start()

func _show_start_screen() -> void:
	if start_screen:
		start_screen.visible = true
	if game_screen:
		game_screen.visible = false
	
	DebugLogger.debug(module_name, "Showing start screen")

func _show_game_screen() -> void:
	if start_screen:
		start_screen.visible = false
	if game_screen:
		game_screen.visible = true
	
	DebugLogger.debug(module_name, "Showing game screen")

func _input(event: InputEvent) -> void:
	if not game_active:
		return
	
	if event is InputEventKey and event.pressed:
		var direction_changed = false
		match event.keycode:
			KEY_W, KEY_UP:
				if direction != Vector2i.DOWN:
					next_direction = Vector2i.UP
					direction_changed = true
			KEY_S, KEY_DOWN:
				if direction != Vector2i.UP:
					next_direction = Vector2i.DOWN
					direction_changed = true
			KEY_A, KEY_LEFT:
				if direction != Vector2i.RIGHT:
					next_direction = Vector2i.LEFT
					direction_changed = true
			KEY_D, KEY_RIGHT:
				if direction != Vector2i.LEFT:
					next_direction = Vector2i.RIGHT
					direction_changed = true
		
		# Play neutral sound for direction change
		if direction_changed:
			play_neutral_sound()

func _move_snake() -> void:
	if not game_active:
		return
	
	# Update direction
	direction = next_direction
	
	# Calculate new head position
	var head = snake_positions[0]
	var new_head = head + direction
	
	# Check wall collision
	if new_head.x < 0 or new_head.x >= grid_size.x or new_head.y < 0 or new_head.y >= grid_size.y:
		_game_over()
		return
	
	# Check self collision
	if new_head in snake_positions:
		_game_over()
		return
	
	# Add new head
	snake_positions.insert(0, new_head)
	
	# Check food collision
	if new_head == food_position:
		_eat_food()
	else:
		# Remove tail if no food eaten
		snake_positions.pop_back()
	
	# Update visuals
	_update_visuals()
	_update_progress()
	
	# Check win condition
	if snake_positions.size() >= target_length:
		_game_complete()

func _spawn_food() -> void:
	var attempts = 0
	while attempts < 100:  # Prevent infinite loop
		# Spawn food away from edges - only in inner area
		food_position = Vector2i(
			1 + randi() % (grid_size.x - 2),  # 1 to grid_size.x-2
			1 + randi() % (grid_size.y - 2)   # 1 to grid_size.y-2
		)
		if food_position not in snake_positions:
			break
		attempts += 1
	
	DebugLogger.debug(module_name, "Food spawned at: " + str(food_position))

func _eat_food() -> void:
	DebugLogger.debug(module_name, "Food eaten! Snake length: " + str(snake_positions.size()))
	
	# Play positive sound for eating food
	play_positive_sound()
	
	_spawn_food()

func _update_visuals() -> void:
	# Clear all cells
	for rect in cell_rects:
		rect.color = background_color
	
	# Draw snake
	for pos in snake_positions:
		var index = pos.y * grid_size.x + pos.x
		if index >= 0 and index < cell_rects.size():
			cell_rects[index].color = snake_color
	
	# Draw food
	var food_index = food_position.y * grid_size.x + food_position.x
	if food_index >= 0 and food_index < cell_rects.size():
		cell_rects[food_index].color = food_color

func _update_progress() -> void:
	var current_length = snake_positions.size()
	
	if progress_bar:
		progress_bar.max_value = target_length
		progress_bar.value = current_length
	
	if length_label:
		length_label.text = str(current_length) + "/" + str(target_length)

func _game_over() -> void:
	DebugLogger.debug(module_name, "Game over! Final length: " + str(snake_positions.size()))
	
	game_active = false
	move_timer.stop()
	
	# Play negative sound for game over
	play_negative_sound()
	
	if game_over_label:
		game_over_label.text = "Game Over! Length: " + str(snake_positions.size())
		game_over_label.visible = true
	
	# Return to start screen after delay
	await get_tree().create_timer(3.0).timeout
	_reset_game()
	_show_start_screen()

func _game_complete() -> void:
	DebugLogger.info(module_name, "Game completed! Target length reached: " + str(snake_positions.size()))
	
	game_active = false
	move_timer.stop()
	
	# Play victory sound for game completion
	play_victory_sound()
	
	if game_over_label:
		game_over_label.text = "Success! Game Complete!"
		game_over_label.visible = true
	
	# Emit completion signal
	game_completed.emit(snake_positions.size())
	
	# Return to start screen after delay
	await get_tree().create_timer(3.0).timeout
	_reset_game()
	_show_start_screen()

## Public method to stop the game
func stop_game() -> void:
	game_active = false
	move_timer.stop()
	_reset_game()
	
	if start_button:
		start_button.disabled = false
		start_button.text = "Start Game"

## Public method to set target length
func set_target_length(length: int) -> void:
	target_length = length
	_update_progress()
	DebugLogger.debug(module_name, "Target length set to: " + str(target_length))
