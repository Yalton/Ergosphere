# cutscene_controller.gd
extends Node

## Array of dialogue lines to be typed out
@export var dialogue_lines: Array[String] = []

## Time between each letter being typed
@export var letter_typing_time: float = 0.05

## Delay after each line is completed
@export var line_completion_delay: float = 2.0

## Delay before transitioning to next scene after final line
@export var final_transition_delay: float = 3.0

## Path to the next scene to load after cutscene
@export_file("*.tscn") var next_scene_path: String

## Sound to play when typing each letter
@export var typing_sound: AudioStream

## Sound to play when advancing to next line
@export var line_advance_sound: AudioStream

## How often to play typing sound (every Nth character)
@export var typing_sound_frequency: int = 3

## Minimum pitch variation for typing sound
@export var typing_pitch_min: float = 0.8

## Maximum pitch variation for typing sound
@export var typing_pitch_max: float = 1.2

## Pitch for line advance sound
@export var line_advance_pitch: float = 1.0

## Animation player for line animations
@export var animation_player: AnimationPlayer

## Label to display the dialogue text
@export var dialogue_label: RichTextLabel

## Panel or container for the dialogue UI
@export var dialogue_container: Control

## Whether this is an intro cutscene (calls GameManager.start_first_day)
@export var is_intro_cutscene: bool = false

## Whether to use loading screen transition (for long scene changes)
@export var use_loading_transition: bool = false

## Enable debug logging for this module
@export var enable_debug: bool = true
var module_name: String = "CutsceneController"

# Internal state
var current_line_index: int = 0
var current_char_index: int = 0
var is_typing: bool = false
var is_line_complete: bool = false
var typing_timer: Timer
var skip_current_line: bool = false
var is_cutscene_active: bool = false
var letters_typed_count: int = 0

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Create typing timer
	typing_timer = Timer.new()
	typing_timer.wait_time = letter_typing_time
	typing_timer.one_shot = true
	typing_timer.timeout.connect(_type_next_character)
	add_child(typing_timer)
	
	# Initially hide dialogue
	if dialogue_container:
		dialogue_container.hide()
	
	# Enable BBCode on the RichTextLabel
	if dialogue_label:
		dialogue_label.bbcode_enabled = true
	
	# Start cutscene after a short delay
	await get_tree().create_timer(0.5).timeout
	show_cutscene()

func _input(event: InputEvent) -> void:
	if not is_cutscene_active:
		return
	
	# Check for E key to skip entire cutscene
	if event.is_action_pressed("interact"):
		DebugLogger.info(module_name, "Skip cutscene triggered by E key")
		skip_cutscene()
		return
	
	# Handle left click for line progression
	if event.is_action_pressed("action_primary"):
		if is_typing:
			# Currently typing - complete the current line
			skip_current_line = true
			DebugLogger.debug(module_name, "Skipping current line typing")
		elif is_line_complete:
			# Line is complete - advance to next line with sound
			if line_advance_sound:
				Audio.play_sound(line_advance_sound, true, line_advance_pitch)
			DebugLogger.debug(module_name, "Advancing to next line")
			_advance_to_next_line()

func show_cutscene() -> void:
	is_cutscene_active = true
	if dialogue_container:
		dialogue_container.show()
		
		# Play show animation if available
		if animation_player and animation_player.has_animation("show"):
			animation_player.play("show")
			await animation_player.animation_finished
	
	start_typing()

func start_typing() -> void:
	if dialogue_lines.is_empty():
		DebugLogger.warning(module_name, "No dialogue lines configured")
		_finish_cutscene()
		return
	
	current_line_index = 0
	_start_line()

func _start_line() -> void:
	if current_line_index >= dialogue_lines.size():
		_finish_cutscene()
		return
	
	current_char_index = 0
	is_typing = true
	is_line_complete = false
	skip_current_line = false
	letters_typed_count = 0
	
	if dialogue_label:
		dialogue_label.text = ""
		dialogue_label.visible_characters = 0
	
	# Start typing
	typing_timer.start()
	
	DebugLogger.debug(module_name, "Starting line " + str(current_line_index))

func _type_next_character() -> void:
	if skip_current_line:
		_complete_current_line()
		return
	
	var current_line = dialogue_lines[current_line_index]
	
	if current_char_index < current_line.length():
		# Add next character with green outline
		if dialogue_label:
			var text_to_show = current_line.substr(0, current_char_index + 1)
			dialogue_label.text = "[outline_size=2][outline_color=#00ff00][color=white]" + text_to_show + "[/color][/outline_color][/outline_size]"
			dialogue_label.visible_characters = -1  # Show all formatted characters
		
		# Only play typing sound every Nth letter (ignoring spaces)
		var current_char = current_line[current_char_index]
		if current_char != " ":
			letters_typed_count += 1
			if typing_sound and letters_typed_count % typing_sound_frequency == 0:
				var pitch = randf_range(typing_pitch_min, typing_pitch_max)
				Audio.play_sound(typing_sound, true, pitch)
		
		current_char_index += 1
		typing_timer.start()
	else:
		_complete_current_line()

func _complete_current_line() -> void:
	is_typing = false
	is_line_complete = true
	
	# Show full line with green outline
	if dialogue_label and current_line_index < dialogue_lines.size():
		dialogue_label.text = "[outline_size=2][outline_color=#00ff00][color=white]" + dialogue_lines[current_line_index] + "[/color][/outline_color][/outline_size]"
		dialogue_label.visible_characters = -1
	
	# Play line complete animation if available
	if animation_player and animation_player.has_animation("line_complete"):
		animation_player.play("line_complete")
	
	DebugLogger.debug(module_name, "Line " + str(current_line_index) + " complete, waiting for player input")

func _advance_to_next_line() -> void:
	current_line_index += 1
	
	if current_line_index < dialogue_lines.size():
		_start_line()
	else:
		# All lines shown, finish cutscene
		_finish_cutscene()

func _finish_cutscene() -> void:
	is_cutscene_active = false
	is_typing = false
	is_line_complete = false
	
	DebugLogger.info(module_name, "Cutscene finished, transitioning to next scene")
	
	# Only call GameManager.start_first_day() if this is the intro cutscene
	if is_intro_cutscene:
		GameManager.start_first_day()
	
	# Transition to next scene
	if TransitionManager:
		# Hide dialogue with animation if available
		if animation_player and animation_player.has_animation("hide"):
			animation_player.play("hide")
			await animation_player.animation_finished
		
		# Use loading transition if specified and available
		if not next_scene_path.is_empty():
			if use_loading_transition:
				await TransitionManager.transition_to_scene_with_loading(next_scene_path)
			else:
				await TransitionManager.fade_to_black()
				get_tree().change_scene_to_file(next_scene_path)
				await TransitionManager.fade_from_black()
		else:
			DebugLogger.error(module_name, "No next scene path configured!")
	else:
		# Fallback without transition manager
		DebugLogger.warning(module_name, "TransitionManager not found, using direct scene change")
		
		# Hide dialogue with animation if available
		if animation_player and animation_player.has_animation("hide"):
			animation_player.play("hide")
			await animation_player.animation_finished
		
		# Load next scene directly
		if not next_scene_path.is_empty():
			get_tree().change_scene_to_file(next_scene_path)
		else:
			DebugLogger.error(module_name, "No next scene path configured!")

func skip_cutscene() -> void:
	## Public method to skip entire cutscene
	_finish_cutscene()
