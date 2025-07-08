extends DiageticUIContent
class_name PatternMemoryGame

signal calibration_complete
signal pattern_failed

## How many sequences the player must complete successfully
@export_range(3, 10) var sequences_to_win: int = 5

## Color options for the squares when lit up
@export var active_colors: Array[Color] = [
	Color(0.8, 0.3, 0.3),  # Muted red
	Color(0.3, 0.7, 0.3),  # Muted green
	Color(0.3, 0.4, 0.8),  # Muted blue
	Color(0.8, 0.8, 0.3),  # Muted yellow
	Color(0.7, 0.3, 0.7),  # Muted purple
	Color(0.3, 0.7, 0.7)   # Muted cyan
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

## Enable debug logging for this module
@export var enable_debug: bool = false

var squares: Array[ColorRect] = []
var current_pattern: Array[int] = []
var player_input: Array[int] = []
var showing_pattern: bool = false
var current_round: int = 0
var game_active: bool = false
var module_name: String = "PatternMemoryGame"
var accepting_input: bool = false
var expected_input_index: int = 0

# UI Elements - Assign these in the scene
@export var message_label: RichTextLabel
@export var progress_bar: ProgressBar
@export var intro_ui: Control
@export var start_button: Button
@export var game_ui: Control

func _ready():
	DebugLogger.register_module(module_name, enable_debug)
	DebugLogger.debug(module_name, "_ready() called")
	setup_squares()
	setup_intro()
	
	# Show intro instead of auto-starting
	show_intro()

func setup_squares():
	DebugLogger.debug(module_name, "Finding existing ColorRect squares")
	
	# Find all ColorRect nodes in the scene
	squares = find_colorrects_recursive(self)
	
	DebugLogger.debug(module_name, "Found " + str(squares.size()) + " squares")
	
	# Connect input events to squares
	for i in range(squares.size()):
		var square = squares[i]
		square.color = inactive_color
		square.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var index = i
		square.gui_input.connect(_on_square_input.bind(index))
		DebugLogger.debug(module_name, "Connected square " + str(i))

func find_colorrects_recursive(node: Node) -> Array[ColorRect]:
	var found_rects: Array[ColorRect] = []
	
	if node is ColorRect:
		found_rects.append(node)
	
	for child in node.get_children():
		found_rects.append_array(find_colorrects_recursive(child))
	
	return found_rects

func setup_intro():
	DebugLogger.debug(module_name, "Setting up intro screen")
	
	if not start_button:
		DebugLogger.error(module_name, "start_button not assigned!")
		return
	
	start_button.pressed.connect(_on_start_button_pressed)
	DebugLogger.debug(module_name, "Start button connected")

func show_intro():
	DebugLogger.debug(module_name, "Showing intro screen")
	
	if intro_ui:
		intro_ui.visible = true
	if game_ui:
		game_ui.visible = false

func _on_start_button_pressed():
	DebugLogger.debug(module_name, "Start button pressed")
	
	if intro_ui:
		intro_ui.visible = false
	if game_ui:
		game_ui.visible = true
	
	start_game()

func start_game():
	DebugLogger.debug(module_name, "Starting new game")
	
	if not message_label:
		DebugLogger.error(module_name, "message_label not assigned!")
		return
	
	if not progress_bar:
		DebugLogger.error(module_name, "progress_bar not assigned!")
		return
	
	if squares.size() == 0:
		DebugLogger.error(module_name, "No squares found!")
		return
	
	game_active = true
	current_round = 0
	current_pattern.clear()
	player_input.clear()
	accepting_input = false
	
	# Setup progress bar
	progress_bar.max_value = sequences_to_win
	progress_bar.value = 0
	
	# Show intro
	message_label.text = "[center][color=lime]" + intro_message + "[/color][/center]"
	DebugLogger.debug(module_name, "Showing intro message")
	
	await get_tree().create_timer(2.0).timeout
	
	message_label.text = "[center][color=yellow]" + gameplay_message + "[/color][/center]"
	DebugLogger.debug(module_name, "Showing gameplay message")
	
	await get_tree().create_timer(0.5).timeout
	next_round()

func stop_game():
	game_active = false
	accepting_input = false
	message_label.text = ""

func next_round():
	if not game_active:
		return
		
	current_round += 1
	DebugLogger.debug(module_name, "Starting round " + str(current_round))
	
	if current_round > sequences_to_win:
		complete_calibration()
		return
	
	# Add new element to pattern
	current_pattern.append(randi() % squares.size())
	player_input.clear()
	expected_input_index = 0
	accepting_input = false
	
	show_pattern()

func show_pattern():
	showing_pattern = true
	accepting_input = false
	DebugLogger.debug(module_name, "Showing pattern: " + str(current_pattern))
	
	for i in range(current_pattern.size()):
		if not game_active:
			return
		await get_tree().create_timer(pattern_delay).timeout
		light_up_square(current_pattern[i], true)
		await get_tree().create_timer(display_time).timeout
		reset_square(current_pattern[i])
	
	showing_pattern = false
	accepting_input = true
	expected_input_index = 0
	DebugLogger.debug(module_name, "Pattern complete, awaiting input")

func light_up_square(index: int, is_pattern_display: bool = false):
	if index < squares.size():
		var color_index = index % active_colors.size()
		squares[index].color = active_colors[color_index]
		
		# Play sound with pitch based on square index
		play_square_sound(index)
		
		DebugLogger.debug(module_name, "Lighting up square " + str(index) + " with color " + str(active_colors[color_index]))
	else:
		DebugLogger.error(module_name, "Invalid square index: " + str(index))

func reset_square(index: int):
	if index < squares.size():
		squares[index].color = inactive_color

func play_square_sound(index: int):
	# Calculate pitch based on square index
	# 8 squares total: first 4 go down in pitch, last 4 go up
	var pitch: float = 1.0
	if index < 4:
		# Pitch down by semitones (each semitone is roughly 2^(1/12) = 1.0595)
		pitch = pow(2.0, -(4 - index) / 6.0)
	else:
		# Pitch up by semitones
		pitch = pow(2.0, (index - 3) / 6.0)
	
	play_neutral_sound()
	if Audio:
		# Apply pitch to the last played sound
		var players = Audio.get_children()
		for player in players:
			if player is AudioStreamPlayer and player.playing:
				player.pitch_scale = pitch
				break

func _on_square_input(event: InputEvent, index: int):
	if not game_active:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Only process clicks when we're accepting input
		if not accepting_input:
			DebugLogger.debug(module_name, "Click ignored - not accepting input")
			return
		
		DebugLogger.debug(module_name, "Player clicked square " + str(index))
		
		# Check if this is the expected square
		if index == current_pattern[expected_input_index]:
			# Correct input
			light_up_square(index)
			player_input.append(index)
			expected_input_index += 1
			
			await get_tree().create_timer(0.3).timeout
			reset_square(index)
			
			# Check if pattern is complete
			if player_input.size() == current_pattern.size():
				# Pattern completed successfully
				DebugLogger.debug(module_name, "Pattern completed successfully!")
				accepting_input = false
				await handle_pattern_success()
		else:
			# Wrong input
			DebugLogger.debug(module_name, "Wrong input! Expected square " + str(current_pattern[expected_input_index]) + " but got " + str(index))
			accepting_input = false
			await handle_pattern_failure()

func handle_pattern_success():
	# Flash all squares green
	for square in squares:
		square.color = Color(0, 1, 0, 1)  # Bright green
	
	play_positive_sound()
	
	await get_tree().create_timer(0.5).timeout
	
	# Reset squares
	for square in squares:
		square.color = inactive_color
	
	progress_bar.value = current_round
	await get_tree().create_timer(0.5).timeout
	next_round()

func handle_pattern_failure():
	# Flash all squares red
	for square in squares:
		square.color = Color(1, 0, 0, 1)  # Bright red
	
	play_negative_sound()
	pattern_failed.emit()
	
	await get_tree().create_timer(0.5).timeout
	
	# Reset squares
	for square in squares:
		square.color = inactive_color
	
	# Reset for retry
	player_input.clear()
	expected_input_index = 0
	
	await get_tree().create_timer(1.0).timeout
	
	# Show the pattern again
	show_pattern()

func check_player_input() -> bool:
	for i in range(player_input.size()):
		if player_input[i] != current_pattern[i]:
			return false
	return true

func complete_calibration():
	DebugLogger.debug(module_name, "Calibration complete!")
	accepting_input = false
	showing_pattern = true  # Prevent further input
	
	# Victory animation - light all squares
	for i in range(squares.size()):
		light_up_square(i)
		await get_tree().create_timer(0.1).timeout
	
	play_victory_sound()
	
	await get_tree().create_timer(0.5).timeout
	
	message_label.text = "[center][color=green]" + success_message + "[/color][/center]"
	
	await get_tree().create_timer(2.0).timeout
	
	calibration_complete.emit()
	game_active = false

func reset_game():
	DebugLogger.debug(module_name, "Resetting game")
	for square in squares:
		square.color = inactive_color
	stop_game()
