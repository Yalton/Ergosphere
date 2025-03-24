# OptionsMenu.gd
extends Control

signal back_requested(caller_name: String)
signal settings_changed

# Add debug export variable
@export var enable_debug: bool = false
var module_name: String = "OptionsMenu"

# Audio buses
const MASTER_BUS = 0
const MUSIC_BUS = 1
const SFX_BUS = 2

# Caller identification
var caller_name: String = ""
var caller_menu: Control = null

# Node references
@onready var master_volume_slider: HSlider = $HBoxContainer/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/HSlider
@onready var music_volume_slider: HSlider = $HBoxContainer/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/HSlider2
@onready var sfx_volume_slider: HSlider = $HBoxContainer/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/GridContainer/HSlider3
@onready var high_quality_checkbox: CheckBox = $HBoxContainer/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/HBoxContainer/CheckBox
@onready var back_button: Button = $HBoxContainer/VBoxContainer/PanelContainer/HBoxContainer/VBoxContainer/BackButton


func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set process mode to always to ensure it works during pause
	process_mode = PROCESS_MODE_ALWAYS
	
	# Connect signals
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	high_quality_checkbox.toggled.connect(_on_quality_toggled)
	back_button.pressed.connect(_on_back_pressed)
	
	# Load current settings
	load_settings()
	
	# Initially hidden
	hide()

func show_options(from_menu: Control) -> void:
	caller_menu = from_menu
	caller_menu.hide()
	
	# Refresh settings whenever options menu is shown
	load_settings()
	
	show()
	
	# Give focus to the back button for better UI navigation
	back_button.grab_focus()

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
		DebugLogger.error(module_name, "Attempted to save to: " + OS.get_user_data_dir() + "/settings.cfg")
	else:
		DebugLogger.info(module_name, "Settings saved successfully to: " + OS.get_user_data_dir() + "/settings.cfg")

func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(value / 100))
	# Save changes immediately so they persist even if back isn't pressed
	save_settings()

func _on_music_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(value / 100))
	save_settings()

func _on_sfx_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(value / 100))
	save_settings()

func _on_quality_toggled(button_pressed: bool) -> void:
	# Apply quality settings
	DebugLogger.debug(module_name, "High quality set to: " + str(button_pressed))
	
	# Use the global singleton directly
	if SettingsManager:
		SettingsManager.apply_quality_settings(button_pressed)
	
	# This would be where you adjust shader quality, particle effects, etc.
	# Example: get_tree().call_group("quality_affected", "set_quality", button_pressed)
	
	# Save changes
	save_settings()

func _on_back_pressed() -> void:
	save_settings()
	hide()
	
	# Show the caller menu if it exists
	if caller_menu:
		caller_menu.show()
