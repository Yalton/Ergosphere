# MainMenu.gd
extends Control

# Export the path to your game scene
@export var play_game_audio: AudioStream
@export_file("*.tscn") var game_scene_path: String

@export var enable_debug: bool = false
var module_name: String = "MainMenu"

# Audio bus indices
const MASTER_BUS = 0
const MUSIC_BUS = 1
const SFX_BUS = 2

@export_category("Buttons")
@export var play_game_button: Button 
@export var options_button: Button
@export var controls_button: Button
@export var quit_button: Button

# Menu references
@onready var main_menu = $MainMenu
@onready var options_menu = $Options
@onready var controls_menu = $Controls

# Options Menu elements
@onready var master_volume_slider = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/MasterVolumeSlider
@onready var music_volume_slider = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/MusicVolumeSlider
@onready var sfx_volume_slider = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/SFXVolumeSlider
@onready var high_quality_checkbox = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/HBoxContainer/HighQualityCheckBox
@onready var options_back_button = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/BackButton

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
	
	# Connect options menu signals
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	high_quality_checkbox.toggled.connect(_on_quality_toggled)
	options_back_button.pressed.connect(_on_options_back_pressed)
	
	# Connect controls menu signals
	controls_back_button.pressed.connect(_on_controls_back_pressed)
	
	# Hide sub-menus initially
	if options_menu:
		options_menu.hide()
	if controls_menu:
		controls_menu.hide()
	
	# Load settings
	load_settings()
	
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
	DebugLogger.debug(module_name, "Options button pressed")
	
	# Hide main menu, show options
	main_menu.hide()
	options_menu.show()
	controls_menu.hide()
	
	# Refresh settings
	load_settings()
	
	# Give focus to back button
	options_back_button.grab_focus()

func _on_controls_pressed() -> void:
	DebugLogger.debug(module_name, "Controls button pressed")
	
	# Hide main menu, show controls
	main_menu.hide()
	options_menu.hide()
	controls_menu.show()
	
	# Give focus to back button
	controls_back_button.grab_focus()
		
func _on_quit_pressed() -> void:
	DebugLogger.debug(module_name, "Quit button pressed")
	get_tree().quit()

# Options Menu Functions
func load_settings() -> void:
	# Load volume settings from AudioServer
	master_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(MASTER_BUS)) * 100
	music_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(MUSIC_BUS)) * 100
	sfx_volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(SFX_BUS)) * 100
	
	# Load quality setting from user settings
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		high_quality_checkbox.button_pressed = config.get_value("graphics", "high_quality", true)
	else:
		high_quality_checkbox.button_pressed = true # Default to high quality

func save_settings() -> void:
	var config = ConfigFile.new()
	
	# First try to load existing settings to keep any we're not changing
	var err = config.load("user://settings.cfg")
	
	# Set our values (this will overwrite existing or create new ones)
	config.set_value("graphics", "high_quality", high_quality_checkbox.button_pressed)
	config.set_value("audio", "master_volume", master_volume_slider.value)
	config.set_value("audio", "music_volume", music_volume_slider.value)
	config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	
	# Save with error handling
	err = config.save("user://settings.cfg")
	if err != OK:
		DebugLogger.error(module_name, "Error saving settings: " + str(err))
	else:
		DebugLogger.info(module_name, "Settings saved successfully")

# Options Menu Button Handlers
func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(value / 100))
	save_settings()

func _on_music_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(value / 100))
	save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(value / 100))
	save_settings()

func _on_quality_toggled(button_pressed: bool) -> void:
	DebugLogger.debug(module_name, "High quality set to: " + str(button_pressed))
	
	# Use the global singleton to apply settings
	if SettingsManager:
		SettingsManager.apply_quality_settings(button_pressed)
	
	# Save changes
	save_settings()

func _on_options_back_pressed() -> void:
	DebugLogger.debug(module_name, "Returning from options to main menu")
	
	# Save settings
	save_settings()
	
	# Switch back to main menu
	options_menu.hide()
	controls_menu.hide()
	main_menu.show()

# Controls Menu Button Handlers
func _on_controls_back_pressed() -> void:
	DebugLogger.debug(module_name, "Returning from controls to main menu")
	
	# Switch back to main menu
	controls_menu.hide()
	options_menu.hide()
	main_menu.show()
