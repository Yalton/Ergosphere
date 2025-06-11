extends Control
class_name PatternMemoryGame

signal calibration_complete
signal pattern_failed

## Number of colored squares in the game grid (minimum 4, maximum 9)
@export_range(4, 9) var square_count: int = 4

## How many sequences the player must complete successfully
@export_range(3, 10) var sequences_to_win: int = 5

## Color options for the squares when lit up
@export var active_colors: Array[Color] = [
	Color.RED,
	Color.GREEN, 
	Color.BLUE,
	Color.YELLOW
]

## Base color for all squares when not active
@export var inactive_color: Color = Color(0.2, 0.2, 0.2)

## Time each square stays lit during pattern display (seconds)
@export var display_time: float = 0.6

## Time between squares lighting up in pattern (seconds)
@export var pattern_delay: float = 0.3

## Message shown before the calibration starts
@export_multiline var intro_message: String = "SYSTEM REQUIRES CALIBRATION\nINITIATING PATTERN SEQUENCE..."

## Message shown during gameplay
@export var gameplay_message: String = "FOLLOW THE PATTERN"

## Message shown after successful calibration
@export_multiline var success_message: String = "CALIBRATION COMPLETE\nSYSTEM ONLINE"

var debug_logger: DebugLogger
var squares: Array[ColorRect] = []
var current_pattern: Array[int] = []
var player_input: Array[int] = []
var showing_pattern: bool = false
var current_round: int = 0
var game_active: bool = false

# UI Elements
var message_label: RichTextLabel
var grid_container: GridContainer
var game_container: Control

func _ready():
	debug_logger = DebugLogger.get_instance()
	debug_logger.register_module("PatternMemoryGame")
	
	setup_ui()

func setup_ui():
	# Main container
	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)
	
	# Message display
	message_label = RichTextLabel.new()
	message_label.custom_minimum_size.y = 60
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	vbox.add_child(message_label)
	
	# Game container
	game_container = Control.new()
	game_container.custom_minimum_size = Vector2(320, 320)
	game_container.visible = false
	vbox.add_child(game_container)
	
	# Grid for squares
	grid_container = GridContainer.new()
	var grid_size = ceil(sqrt(square_count))
	grid_container.columns = int(grid_size)
	grid_container.add_theme_constant_override("h_separation", 10)
	grid_container.add_theme_constant_override("v_separation", 10)
	grid_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	game_container.add_child(grid_container)
	
	# Create squares
	for i in range(square_count):
		var square = ColorRect.new()
		square.custom_minimum_size = Vector2(60, 60)
		square.color = inactive_color
		square.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var index = i
		square.gui_input.connect(_on_square_input.bind(index))
		
		squares.append(square)
		grid_container.add_child(square)

func start_game():
	debug_logger.log("PatternMemoryGame", "Starting new game")
	game_active = true
	current_round = 0
	current_pattern.clear()
	player_input.clear()
	
	# Show intro
	message_label.text = "[center][color=lime]" + intro_message + "[/color][/center]"
	game_container.visible = false
	
	await get_tree().create_timer(2.0).timeout
	
	message_label.text = "[center][color=yellow]" + gameplay_message + "[/color][/center]"
	game_container.visible = true
	
	await get_tree().create_timer(0.5).timeout
	next_round()

func stop_game():
	game_active = false
	game_container.visible = false
	message_label.text = ""

func next_round():
	if not game_active:
		return
		
	current_round += 1
	debug_logger.log("PatternMemoryGame", "Starting round " + str(current_round))
	
	if current_round > sequences_to_win:
		complete_calibration()
		return
	
	# Add new element to pattern
	current_pattern.append(randi() % square_count)
	player_input.clear()
	
	show_pattern()

func show_pattern():
	showing_pattern = true
	debug_logger.log("PatternMemoryGame", "Showing pattern: " + str(current_pattern))
	
	for i in range(current_pattern.size()):
		if not game_active:
			return
		await get_tree().create_timer(pattern_delay).timeout
		light_up_square(current_pattern[i])
		await get_tree().create_timer(display_time).timeout
		reset_square(current_pattern[i])
	
	showing_pattern = false
	debug_logger.log("PatternMemoryGame", "Pattern complete, awaiting input")

func light_up_square(index: int):
	if index < squares.size():
		var color_index = index % active_colors.size()
		squares[index].color = active_colors[color_index]

func reset_square(index: int):
	if index < squares.size():
		squares[index].color = inactive_color

func _on_square_input(event: InputEvent, index: int):
	if showing_pattern or not game_active:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		debug_logger.log("PatternMemoryGame", "Player clicked square " + str(index))
		
		# Visual feedback
		light_up_square(index)
		await get_tree().create_timer(0.3).timeout
		reset_square(index)
		
		# Check input
		player_input.append(index)
		
		if not check_player_input():
			# Wrong input - reset
			debug_logger.log("PatternMemoryGame", "Wrong input! Resetting pattern")
			pattern_failed.emit()
			player_input.clear()
			await get_tree().create_timer(1.0).timeout
			show_pattern()
		elif player_input.size() == current_pattern.size():
			# Completed pattern successfully
			debug_logger.log("PatternMemoryGame", "Pattern completed successfully!")
			await get_tree().create_timer(1.0).timeout
			next_round()

func check_player_input() -> bool:
	for i in range(player_input.size()):
		if player_input[i] != current_pattern[i]:
			return false
	return true

func complete_calibration():
	debug_logger.log("PatternMemoryGame", "Calibration complete!")
	showing_pattern = true  # Prevent further input
	
	# Victory animation - light all squares
	for i in range(squares.size()):
		light_up_square(i)
		await get_tree().create_timer(0.1).timeout
	
	await get_tree().create_timer(0.5).timeout
	
	game_container.visible = false
	message_label.text = "[center][color=green]" + success_message + "[/color][/center]"
	
	await get_tree().create_timer(2.0).timeout
	
	calibration_complete.emit()
	game_active = false

func reset_game():
	debug_logger.log("PatternMemoryGame", "Resetting game")
	for square in squares:
		square.color = inactive_color
	stop_game()
