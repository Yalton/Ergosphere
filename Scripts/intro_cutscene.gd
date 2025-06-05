# intro_cutscene.gd
extends Node

## Array of dialogue lines to be typed out
@export var dialogue_lines: Array[String] = []

## Time between each letter being typed
@export var letter_typing_time: float = 0.05

## Delay after each line is completed
@export var line_completion_delay: float = 2.0

## Delay before transitioning to game scene after final line
@export var final_transition_delay: float = 3.0

## Path to the game scene to load after cutscene
@export_file("*.tscn") var game_scene_path: String

## Sound to play when typing each letter
@export var typing_sound: AudioStream

## Minimum pitch variation for typing sound
@export var typing_pitch_min: float = 0.8

## Maximum pitch variation for typing sound
@export var typing_pitch_max: float = 1.2

## Animation player for line animations
@export var animation_player: AnimationPlayer

## Label to display the dialogue text
@export var dialogue_label: RichTextLabel

## Panel or container for the dialogue UI
@export var dialogue_container: Control

@export var enable_debug: bool = true
var module_name: String = "IntroCutscene"

# Internal state
var current_line_index: int = 0
var current_char_index: int = 0
var is_typing: bool = false
var is_line_complete: bool = false
var typing_timer: Timer
var line_delay_timer: Timer
var skip_current_line: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create timers
	typing_timer = Timer.new()
	typing_timer.one_shot = true
	typing_timer.timeout.connect(_type_next_character)
	add_child(typing_timer)
	
	line_delay_timer = Timer.new()
	line_delay_timer.one_shot = true
	line_delay_timer.timeout.connect(_start_next_line)
	add_child(line_delay_timer)
	
	# Initially hide dialogue
	if dialogue_container:
		dialogue_container.hide()
	
	# Start cutscene after a short delay
	await get_tree().create_timer(0.5).timeout
	_start_cutscene()

func _start_cutscene() -> void:
	DebugLogger.info(module_name, "Starting intro cutscene")
	
	# Show dialogue container
	if dialogue_container:
		dialogue_container.show()
	
	# Start first line
	current_line_index = 0
	current_char_index = 0
	_start_typing_line()

func _input(event: InputEvent) -> void:
	# Skip entire cutscene on Esc or E
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		DebugLogger.debug(module_name, "Skipping entire cutscene")
		_skip_to_game()
		return
	
	# Handle left click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_typing and not skip_current_line:
			# Instantly complete current line
			skip_current_line = true
			DebugLogger.debug(module_name, "Skipping current line typing")
		elif is_line_complete and not line_delay_timer.time_left > 0:
			# Skip to next line if we're waiting
			_start_next_line()

func _start_typing_line() -> void:
	if current_line_index >= dialogue_lines.size():
		_on_cutscene_complete()
		return
	
	DebugLogger.debug(module_name, "Starting line " + str(current_line_index))
	
	# Reset state
	is_typing = true
	is_line_complete = false
	skip_current_line = false
	current_char_index = 0
	
	# Clear the label
	if dialogue_label:
		dialogue_label.text = ""
	
	# Play corresponding animation
	if animation_player and animation_player.has_animation(str(current_line_index)):
		animation_player.play(str(current_line_index))
		DebugLogger.debug(module_name, "Playing animation: " + str(current_line_index))
	
	# Start typing
	_type_next_character()

func _type_next_character() -> void:
	if not is_typing:
		return
	
	var current_line = dialogue_lines[current_line_index]
	
	# Check if we should skip to end
	if skip_current_line:
		current_char_index = current_line.length()
	
	# Type character
	if current_char_index < current_line.length():
		# Add next character
		current_char_index += 1
		if dialogue_label:
			dialogue_label.text = "[outline_size=2][outline_color=00ff00]" + current_line.substr(0, current_char_index) + "[/outline_color][/outline_size]"
		
		# Play typing sound with pitch variation
		if typing_sound and not skip_current_line:
			var pitch = randf_range(typing_pitch_min, typing_pitch_max)
			Audio.play_sound(typing_sound, true, pitch, -10.0, "SFX")
		
		# Schedule next character
		if not skip_current_line:
			typing_timer.start(letter_typing_time)
		else:
			# If skipping, type next character immediately
			_type_next_character()
	else:
		# Line complete
		_on_line_complete()

func _on_line_complete() -> void:
	is_typing = false
	is_line_complete = true
	
	DebugLogger.debug(module_name, "Line " + str(current_line_index) + " complete")
	
	# Wait before next line
	line_delay_timer.start(line_completion_delay)

func _start_next_line() -> void:
	current_line_index += 1
	_start_typing_line()

func _on_cutscene_complete() -> void:
	DebugLogger.info(module_name, "Cutscene complete, waiting for final transition")
	
	# Wait before transitioning
	await get_tree().create_timer(final_transition_delay).timeout
	_transition_to_game()

func _skip_to_game() -> void:
	# Stop all timers
	typing_timer.stop()
	line_delay_timer.stop()
	
	# Stop any playing animation
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	
	_transition_to_game()

func _transition_to_game() -> void:
	DebugLogger.info(module_name, "Transitioning to game scene")
	
	# Use the global transition manager
	if TransitionManager:
		TransitionManager.transition_to_scene(game_scene_path)
	else:
		# Fallback if no transition manager
		get_tree().change_scene_to_file(game_scene_path)
