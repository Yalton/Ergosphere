extends Control
class_name PauseMenu

# Signals
signal resume_requested
signal menu_requested

# Main configuration
@export_file("*.tscn") var main_menu_path: String
@export var enable_debug: bool = false
@export var module_name: String = "PauseMenu"

# Audio bus indices
const MASTER_BUS = 0
const MUSIC_BUS = 1
const SFX_BUS = 2

# Reference to UI elements in all menus
# Pause Menu elements
@onready var pause_menu = $PauseMenu
@onready var resume_button = $PauseMenu/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/ResumeButton
@onready var options_button = $PauseMenu/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/OptionsButton
@onready var controls_button = $PauseMenu/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/ControlsButton
@onready var main_menu_button = $PauseMenu/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/MainMenuButton

# Options Menu elements
@onready var options_menu = $Options
@onready var master_volume_slider = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/MasterVolumeSlider
@onready var music_volume_slider = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/MusicVolumeSlider
@onready var sfx_volume_slider = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/SFXVolumeSlider
@onready var high_quality_checkbox = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/HBoxContainer/HighQualityCheckBox
@onready var options_back_button = $Options/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/BackButton

# Controls Menu elements
@onready var controls_menu = $Controls
@onready var controls_back_button = $Controls/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/BackButton

# State tracking
var is_paused: bool = false
var active_menu: Control = null

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
		
	# Set the process mode to ensure it works during pauses
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Make all UI elements processable during pause
	_set_all_children_process_mode(self, Node.PROCESS_MODE_ALWAYS)
	
	# Connect pause menu signals
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	main_menu_button.pressed.connect(_on_menu_pressed)
	
	# Connect options menu signals
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	high_quality_checkbox.toggled.connect(_on_quality_toggled)
	options_back_button.pressed.connect(_on_options_back_pressed)
	
	# Connect controls menu signals
	controls_back_button.pressed.connect(_on_controls_back_pressed)
	
	# Initially hide all menus
	pause_menu.hide()
	options_menu.hide()
	controls_menu.hide()
	visible = false
	
	# Load current settings
	load_settings()
	
	DebugLogger.info(module_name, "PauseMenu system initialized")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if is_paused:
		unpause()
	else:
		pause()

# Recursively set process mode for all UI children
func _set_all_children_process_mode(node: Node, mode: int) -> void:
	for child in node.get_children():
		child.process_mode = mode
		_set_all_children_process_mode(child, mode)

func pause() -> void:
	if is_paused:
		return
		
	# Release the mouse for menu interaction
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Pause the game
	get_tree().paused = true
	
	# Show pause menu (hide others)
	active_menu = pause_menu
	pause_menu.show()
	options_menu.hide()
	controls_menu.hide()
	visible = true
	
	# Update pause state
	is_paused = true
	
	DebugLogger.debug(module_name, "Game paused")

func unpause() -> void:
	if !is_paused:
		return
		
	# Unpause the game
	get_tree().paused = false
	
	# Hide all menus
	pause_menu.hide()
	options_menu.hide()
	controls_menu.hide()
	visible = false
	active_menu = null
	
	# Recapture the mouse for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Update pause state
	is_paused = false
	
	DebugLogger.debug(module_name, "Game unpaused")

# Pause Menu Button Handlers
func _on_resume_pressed() -> void:
	unpause()
	resume_requested.emit()

func _on_options_pressed() -> void:
	DebugLogger.debug(module_name, "Showing options menu")
	
	# Switch from pause menu to options menu
	pause_menu.hide()
	options_menu.show()
	controls_menu.hide()
	active_menu = options_menu
	
	# Refresh settings
	load_settings()
	
	# Give focus to the back button for better UI navigation
	options_back_button.grab_focus()

func _on_controls_pressed() -> void:
	DebugLogger.debug(module_name, "Showing controls menu")
	
	# Switch from pause menu to controls menu
	pause_menu.hide()
	options_menu.hide()
	controls_menu.show()
	active_menu = controls_menu
	
	# Give focus to the back button for better UI navigation
	controls_back_button.grab_focus()

func _on_menu_pressed() -> void:
	DebugLogger.debug(module_name, "Returning to main menu")
	
	# Unpause first
	unpause()
	
	# Signal that we want to go to main menu
	menu_requested.emit()
	
	# If main_menu_path is set, change to that scene
	if main_menu_path != "":
		get_tree().change_scene_to_file(main_menu_path)

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
	SettingsManager.apply_quality_settings(button_pressed)
	
	# Save changes
	save_settings()

func _on_options_back_pressed() -> void:
	DebugLogger.debug(module_name, "Returning from options to pause menu")
	
	# Save settings
	save_settings()
	
	# Switch back to pause menu
	options_menu.hide()
	controls_menu.hide()
	pause_menu.show()
	active_menu = pause_menu

# Controls Menu Button Handlers
func _on_controls_back_pressed() -> void:
	DebugLogger.debug(module_name, "Returning from controls to pause menu")
	
	# Switch back to pause menu
	controls_menu.hide()
	options_menu.hide()
	pause_menu.show()
	active_menu = pause_menu
