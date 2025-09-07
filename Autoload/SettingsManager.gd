# SettingsManager.gd
extends Node

# Add debug export variable
@export var enable_debug: bool = false
var module_name: String = "SettingsManager"

# Audio bus indices
const MASTER_BUS = 0
const MUSIC_BUS = 1
const SFX_BUS = 2
const HERMES_BUS: int = 4  # Or whatever index your HermesAudio bus is

# Default settings
const DEFAULT_HIGH_QUALITY = true
const DEFAULT_MASTER_VOLUME = 100.0
const DEFAULT_MUSIC_VOLUME = 100.0
const DEFAULT_SFX_VOLUME = 100.0
const DEFAULT_HERMES_MUTED = false  # Default to not muted

# Video defaults
const DEFAULT_VSYNC = true
const DEFAULT_QUALITY_LIGHTING = true
const DEFAULT_FULLSCREEN_MODE = 0 # Windowed
const DEFAULT_RESOLUTION = Vector2i(1920, 1080)

var is_hermes_muted: bool = false

# Available resolutions
var resolutions: Array = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

func _ready() -> void:
	# Register with debug logger
	DebugLogger.register_module(module_name, enable_debug)
	
	# Ensure audio buses exist
	_ensure_audio_buses()
	
	# Load settings on game startup
	load_settings()
	
	DebugLogger.info(module_name, "Settings Manager initialized")

# Create audio buses if they don't exist
func _ensure_audio_buses() -> void:
	# Check if Music bus exists, create if not
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var music_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(music_bus_idx, "Music")
		# Make sure it outputs to Master
		AudioServer.set_bus_send(music_bus_idx, "Master")
	
	# Check if SFX bus exists, create if not
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var sfx_bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		# Make sure it outputs to Master
		AudioServer.set_bus_send(sfx_bus_idx, "Master")

# Load settings from config file
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		DebugLogger.info(module_name, "Loading settings from config file")
		
		# Load volume settings
		var master_volume = config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
		var music_volume = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
		var sfx_volume = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
		
		# Apply volume settings to audio buses
		AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(master_volume / 100))
		AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(music_volume / 100))
		AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(sfx_volume / 100))
		
		# Load and apply Hermes mute setting
		var hermes_muted = config.get_value("audio", "hermes_muted", DEFAULT_HERMES_MUTED)
		is_hermes_muted = hermes_muted
		AudioServer.set_bus_mute(HERMES_BUS, hermes_muted)
		DebugLogger.debug(module_name, "Hermes mute loaded and applied: " + str(hermes_muted))
		
		# Load and apply quality setting
		var high_quality = config.get_value("graphics", "high_quality", DEFAULT_HIGH_QUALITY)
		apply_quality_settings(high_quality)
		
		# Load and apply video settings
		var vsync = config.get_value("video", "vsync", DEFAULT_VSYNC)
		set_vsync(vsync)
		
		var quality_lighting = config.get_value("video", "quality_lighting", DEFAULT_QUALITY_LIGHTING)
		set_quality_lighting(quality_lighting)
		
		var fullscreen_mode = config.get_value("video", "fullscreen_mode", DEFAULT_FULLSCREEN_MODE)
		set_fullscreen_mode(fullscreen_mode)
		
		var resolution = config.get_value("video", "resolution", DEFAULT_RESOLUTION)
		set_resolution(resolution)
		
		if DebugLogger.is_module_enabled(module_name):
			DebugLogger.debug(module_name, "Settings loaded - Master Vol: " + str(master_volume) +
							  "%, Music Vol: " + str(music_volume) +
							  "%, SFX Vol: " + str(sfx_volume) +
							  "%, High Quality: " + str(high_quality) +
							  ", Hermes Muted: " + str(hermes_muted))
	else:
		DebugLogger.warning(module_name, "No settings file found, using defaults")
		# Set default values
		AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(DEFAULT_MASTER_VOLUME / 100))
		AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(DEFAULT_MUSIC_VOLUME / 100))
		AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(DEFAULT_SFX_VOLUME / 100))
		AudioServer.set_bus_mute(HERMES_BUS, DEFAULT_HERMES_MUTED)
		is_hermes_muted = DEFAULT_HERMES_MUTED
		apply_quality_settings(DEFAULT_HIGH_QUALITY)
		set_vsync(DEFAULT_VSYNC)
		set_quality_lighting(DEFAULT_QUALITY_LIGHTING)
		set_fullscreen_mode(DEFAULT_FULLSCREEN_MODE)
		
		# Save default settings
		save_default_settings()

# Save default settings to create initial config file
func save_default_settings() -> void:
	var config = ConfigFile.new()
	
	config.set_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
	config.set_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
	config.set_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	config.set_value("audio", "hermes_muted", DEFAULT_HERMES_MUTED)
	config.set_value("graphics", "high_quality", DEFAULT_HIGH_QUALITY)
	config.set_value("video", "vsync", DEFAULT_VSYNC)
	config.set_value("video", "quality_lighting", DEFAULT_QUALITY_LIGHTING)
	config.set_value("video", "fullscreen_mode", DEFAULT_FULLSCREEN_MODE)
	config.set_value("video", "resolution", DEFAULT_RESOLUTION)
	
	var err = config.save("user://settings.cfg")
	if err == OK:
		DebugLogger.info(module_name, "Default settings saved successfully")
	else:
		DebugLogger.error(module_name, "Error saving default settings: " + str(err))

# Apply quality settings to game elements
func apply_quality_settings(high_quality: bool) -> void:
	# Apply quality settings to any nodes that need it
	# This would be expanded based on your game's needs
	DebugLogger.debug(module_name, "Applying quality settings: High Quality = " + str(high_quality))
	
	# You can use a group to affect multiple nodes
	get_tree().call_group("quality_affected", "set_quality", high_quality)
	
	# Or you can set engine settings directly
	# Example:
	# RenderingServer.set_default_clear_color(Color(0.3, 0.3, 0.3, 1.0) if high_quality else Color(0.2, 0.2, 0.2, 1.0))

# Video Settings Functions
func set_vsync(enabled: bool) -> void:
	DebugLogger.debug(module_name, "Setting VSync to: " + str(enabled))
	
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func set_quality_lighting(enabled: bool) -> void:
	DebugLogger.debug(module_name, "Setting quality lighting to: " + str(enabled))
	
	# Find the WorldEnvironment node in the scene
	var world_env = get_tree().get_first_node_in_group("world_environment")
	if not world_env:
		world_env = _find_world_environment(get_tree().root)
	
	if world_env and world_env.environment:
		world_env.environment.sdfgi_enabled = enabled
		
		# Additional quality settings
		if enabled:
			world_env.environment.ssao_enabled = true
			world_env.environment.ssil_enabled = true
			world_env.environment.glow_enabled = true
		else:
			world_env.environment.ssao_enabled = false
			world_env.environment.ssil_enabled = false
			world_env.environment.glow_enabled = false
			
		DebugLogger.debug(module_name, "SDFGI and quality effects " + ("enabled" if enabled else "disabled"))
	else:
		DebugLogger.warning(module_name, "WorldEnvironment not found!")

func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	
	for child in node.get_children():
		var result = _find_world_environment(child)
		if result:
			return result
	
	return null

func set_fullscreen_mode(mode: int) -> void:
	DebugLogger.debug(module_name, "Setting fullscreen mode to: " + str(mode))
	
	match mode:
		0: # Windowed
			get_window().mode = Window.MODE_WINDOWED
		1: # Borderless Fullscreen
			get_window().mode = Window.MODE_FULLSCREEN
			get_window().borderless = true
		2: # Fullscreen
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			get_window().borderless = false

func set_resolution(resolution: Vector2i) -> void:
	DebugLogger.debug(module_name, "Setting resolution to: " + str(resolution))
	
	# Only change resolution in windowed mode
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().size = resolution
		
		# Center the window
		var screen_size = DisplayServer.screen_get_size()
		var window_position = (screen_size - resolution) / 2
		get_window().position = window_position

# Get current settings values
func get_vsync() -> bool:
	return DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED

func get_quality_lighting() -> bool:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		return config.get_value("video", "quality_lighting", DEFAULT_QUALITY_LIGHTING)
	return DEFAULT_QUALITY_LIGHTING

func get_fullscreen_mode() -> int:
	var mode = get_window().mode
	if mode == Window.MODE_WINDOWED:
		return 0
	elif mode == Window.MODE_FULLSCREEN:
		return 1
	else: # EXCLUSIVE_FULLSCREEN
		return 2

func get_current_resolution() -> Vector2i:
	return get_window().size

# Helper to get resolution index
func get_resolution_index(resolution: Vector2i) -> int:
	for i in range(resolutions.size()):
		if resolutions[i] == resolution:
			return i
	return 3 # Default to 1920x1080

## Check if Hermes voice is muted
func get_hermes_muted() -> bool:
	return is_hermes_muted

## Set Hermes mute state by controlling the bus volume
func set_hermes_muted(muted: bool) -> void:
	is_hermes_muted = muted
	# Mute/unmute the HermesAudio bus
	AudioServer.set_bus_mute(HERMES_BUS, muted)
	
	# Save the setting
	var config = ConfigFile.new()
	config.load("user://settings.cfg")  # Load existing settings
	config.set_value("audio", "hermes_muted", muted)
	config.save("user://settings.cfg")
	DebugLogger.debug(module_name, "Hermes mute set to: " + str(muted))

## Apply Hermes mute setting on startup
func apply_hermes_mute_setting() -> void:
	var muted = get_hermes_muted()
	AudioServer.set_bus_mute(HERMES_BUS, muted)
	DebugLogger.debug(module_name, "Applied Hermes mute setting: " + str(muted))
