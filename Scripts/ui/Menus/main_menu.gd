# MainMenu.gd
extends Control

# Export the path to your game scene
@export var play_game_audio: AudioStream
@export_file("*.tscn") var game_scene_path: String

@export var enable_debug: bool = false
var module_name: String = "MainMenu"

@export_category("Buttons")
@export var play_game_button: Button 
@export var options_button: Button
@export var controls_button: Button
@export var quit_button: Button

# Menu references
@onready var main_menu = $MainMenu
@onready var options_ui_control: OptionsUIControl = $Options
@onready var controls_menu = $Controls

# Controls Menu elements
@onready var controls_back_button = $Controls/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/BackButton

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Make sure the mouse is visible when entering the main menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Connect main menu button signals
	play_game_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Connect options UI control back button
	if options_ui_control:
		options_ui_control.back_pressed.connect(_on_options_back_pressed)
		DebugLogger.debug(module_name, "Connected to OptionsUIControl")
	else:
		DebugLogger.error(module_name, "OptionsUIControl not found!")
	
	# Connect controls menu signals
	controls_back_button.pressed.connect(_on_controls_back_pressed)
	
	# Hide sub-menus initially
	if options_ui_control:
		options_ui_control.hide()
	if controls_menu:
		controls_menu.hide()
	
	DebugLogger.info(module_name, "MainMenu initialized")

# Main Menu Button Handlers
func _on_play_pressed() -> void:
	DebugLogger.debug(module_name, "Play button pressed, starting transition")
	if play_game_audio: 
		Audio.play_sound(play_game_audio)
	
	# Use the global transition manager to handle scene transition
	if TransitionManager:
		TransitionManager.transition_to_scene(game_scene_path)
	else:
		# Fallback to direct scene change if transition manager is not available
		DebugLogger.warning(module_name, "GlobalTransitionManager not found, using direct scene change")
		get_tree().change_scene_to_file(game_scene_path)
		queue_free()

func _on_options_pressed() -> void:
	DebugLogger.debug(module_name, "Options button pressed - showing options menu")
	
	# Hide main menu, show options
	main_menu.hide()
	if options_ui_control:
		options_ui_control.show()
		options_ui_control.refresh_settings()
		DebugLogger.debug(module_name, "Options menu shown and settings refreshed")
	controls_menu.hide()

func _on_controls_pressed() -> void:
	DebugLogger.debug(module_name, "Controls button pressed - showing controls menu")
	
	# Hide main menu, show controls
	main_menu.hide()
	if options_ui_control:
		options_ui_control.hide()
	controls_menu.show()
	
	# Give focus to back button
	controls_back_button.grab_focus()
		
func _on_quit_pressed() -> void:
	DebugLogger.debug(module_name, "Quit button pressed - exiting game")
	get_tree().quit()

# Options back handler
func _on_options_back_pressed() -> void:
	DebugLogger.debug(module_name, "Returning from options to main menu")
	
	# Switch back to main menu
	if options_ui_control:
		options_ui_control.hide()
	controls_menu.hide()
	main_menu.show()

# Controls Menu Button Handler
func _on_controls_back_pressed() -> void:
	DebugLogger.debug(module_name, "Returning from controls to main menu")
	
	# Switch back to main menu
	controls_menu.hide()
	if options_ui_control:
		options_ui_control.hide()
	main_menu.show()
