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

## Enable debug logging for this module
@export var enable_debug: bool = true
var module_name: String = "IntroCutscene"

# Internal state
var current_line_index: int = 0
var current_char_index: int = 0
var is_typing: bool = false
var is_line_complete: bool = false
var typing_timer: Timer
var skip_current_line: bool = false
var line_delay_timer: Timer = null
var is_waiting_for_next_line: bool = false
var is_cutscene_active: bool = false

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
	
	# Start cutscene after a short delay
	await get_tree().create_timer(0.5).timeout
	show_intro()

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
		elif is_waiting_for_next_line:
			# Waiting between lines - skip the delay and start next line immediately
			_skip_line_delay()
			DebugLogger.debug(module_name, "Skipping line delay")

func show_intro() -> void:
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
	is_waiting_for_next_line = false
	skip_current_line = false
	
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
		# Add next character
		if dialogue_label:
			dialogue_label.text = current_line.substr(0, current_char_index + 1)
			dialogue_label.visible_characters = current_char_index + 1
		
		# Play typing sound with pitch variation
		if typing_sound and Audio:
			var pitch = randf_range(typing_pitch_min, typing_pitch_max)
			Audio.play_sound(typing_sound, false, pitch)
		
		current_char_index += 1
		typing_timer.start()
	else:
		_complete_current_line()

func _complete_current_line() -> void:
	is_typing = false
	is_line_complete = true
	
	# Show full line
	if dialogue_label and current_line_index < dialogue_lines.size():
		dialogue_label.text = dialogue_lines[current_line_index]
		dialogue_label.visible_characters = -1
	
	# Play line complete animation if available
	if animation_player and animation_player.has_animation("line_complete"):
		animation_player.play("line_complete")
	
	current_line_index += 1
	
	# Wait before next line
	if current_line_index < dialogue_lines.size():
		is_waiting_for_next_line = true
		line_delay_timer = CommonUtils.create_one_shot_timer(self, line_completion_delay, _start_line)
	else:
		# Last line complete, wait before transitioning
		is_waiting_for_next_line = true
		line_delay_timer = CommonUtils.create_one_shot_timer(self, final_transition_delay, _finish_cutscene)

func _skip_line_delay() -> void:
	# Cancel the current delay timer if it exists
	if line_delay_timer and is_instance_valid(line_delay_timer):
		line_delay_timer.queue_free()
		line_delay_timer = null
	
	is_waiting_for_next_line = false
	
	# Immediately proceed to next action
	if current_line_index < dialogue_lines.size():
		_start_line()
	else:
		_finish_cutscene()

func _finish_cutscene() -> void:
	is_cutscene_active = false
	is_typing = false
	is_waiting_for_next_line = false
	
	# Clean up any remaining timers
	if line_delay_timer and is_instance_valid(line_delay_timer):
		line_delay_timer.queue_free()
		line_delay_timer = null
	
	DebugLogger.info(module_name, "Cutscene finished, transitioning to game")
	
	GameManager.start_first_day()
	
	# Use TransitionManager if available
	if TransitionManager:
		# Hide dialogue with animation if available
		if animation_player and animation_player.has_animation("hide"):
			animation_player.play("hide")
			await animation_player.animation_finished
		
		# Transition to game scene with fade
		if not game_scene_path.is_empty():
			await TransitionManager.transition_to_scene(game_scene_path)
		else:
			DebugLogger.error(module_name, "No game scene path configured!")
	else:
		# Fallback without transition manager
		DebugLogger.warning(module_name, "TransitionManager not found, using direct scene change")
		
		# Hide dialogue with animation if available
		if animation_player and animation_player.has_animation("hide"):
			animation_player.play("hide")
			await animation_player.animation_finished
		
		# Load game scene directly
		if not game_scene_path.is_empty():
			get_tree().change_scene_to_file(game_scene_path)
		else:
			DebugLogger.error(module_name, "No game scene path configured!")

func skip_cutscene() -> void:
	## Public method to skip entire cutscene
	_finish_cutscene()
