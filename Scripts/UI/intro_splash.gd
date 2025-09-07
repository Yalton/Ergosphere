# intro_splash.gd
extends Control

## Enable debug logging for this module
@export var enable_debug: bool = false
var module_name: String = "IntroSplash"

## Path to main menu scene
@export_file("*.tscn") var main_menu_path: String = "res://scenes/main_menu.tscn"

## Duration for the fade from black effect
@export var fade_in_duration: float = 0.15

## Reference to the AnimationPlayer node
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Internal state
var can_skip: bool = false
var is_transitioning: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Connect animation finished signal
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
		DebugLogger.debug(module_name, "Connected to AnimationPlayer")
	else:
		DebugLogger.error(module_name, "AnimationPlayer not found!")
	
	# Start the intro sequence
	_start_intro_sequence()

func _start_intro_sequence() -> void:
	DebugLogger.info(module_name, "Starting intro sequence")

	var tween = create_tween()
	TransitionManager.show()
	TransitionManager.color_rect.color = Color(0, 0, 0, 1)
	tween.tween_property(TransitionManager.color_rect, "color", 
		Color(0, 0, 0, 0), fade_in_duration)
	await tween.finished
	TransitionManager.hide()
	
	# Allow skipping after fade completes
	can_skip = true
	

func _input(event: InputEvent) -> void:
	# Check for skip inputs
	if not can_skip or is_transitioning:
		return
	
	var should_skip = false
	
	# Check for left click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			should_skip = true
			DebugLogger.debug(module_name, "Skip triggered by left click")
	
	# Check for keyboard inputs (E or Space)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE:
			should_skip = true
			DebugLogger.debug(module_name, "Skip triggered by key: %s" % 
				("E" if event.keycode == KEY_E else "Space"))
	
	if should_skip:
		_skip_to_main_menu()

func _on_animation_finished(anim_name: String) -> void:
	DebugLogger.info(module_name, "Animation finished: %s" % anim_name)
	_transition_to_main_menu()

func _skip_to_main_menu() -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	can_skip = false
	
	DebugLogger.info(module_name, "Skipping to main menu")
	
	# Stop the animation if it's playing
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	
	_transition_to_main_menu()

func _transition_to_main_menu() -> void:
	if is_transitioning and animation_player.is_playing():
		return  # Already transitioning
	
	is_transitioning = true
	DebugLogger.info(module_name, "Transitioning to main menu")
	
	# Use TransitionManager if available
	if TransitionManager:
		await TransitionManager.fade_to_black()
		get_tree().change_scene_to_file(main_menu_path)
	else:
		# Direct scene change as fallback
		get_tree().change_scene_to_file(main_menu_path)
