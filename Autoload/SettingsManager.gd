# SettingsManager.gd
extends Node

# Add debug export variable
@export var enable_debug: bool = false
var module_name: String = "SettingsManager"

# Audio bus indices
const MASTER_BUS = 0
const MUSIC_BUS = 1
const SFX_BUS = 2

# Default settings
const DEFAULT_HIGH_QUALITY = true
const DEFAULT_MASTER_VOLUME = 100.0 # 80%
const DEFAULT_MUSIC_VOLUME = 100.0 # 70%
const DEFAULT_SFX_VOLUME = 100.0 # 90%

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
        
        # Load and apply quality setting
        var high_quality = config.get_value("graphics", "high_quality", DEFAULT_HIGH_QUALITY)
        apply_quality_settings(high_quality)
        
        if DebugLogger.is_module_enabled(module_name):
            DebugLogger.debug(module_name, "Settings loaded - Master Vol: " + str(master_volume) +
                              "%, Music Vol: " + str(music_volume) +
                              "%, SFX Vol: " + str(sfx_volume) +
                              "%, High Quality: " + str(high_quality))
    else:
        DebugLogger.warning(module_name, "No settings file found, using defaults")
        # Set default values
        AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(DEFAULT_MASTER_VOLUME / 100))
        AudioServer.set_bus_volume_db(MUSIC_BUS, linear_to_db(DEFAULT_MUSIC_VOLUME / 100))
        AudioServer.set_bus_volume_db(SFX_BUS, linear_to_db(DEFAULT_SFX_VOLUME / 100))
        apply_quality_settings(DEFAULT_HIGH_QUALITY)
        
        # Save default settings
        save_default_settings()

# Save default settings to create initial config file
func save_default_settings() -> void:
    var config = ConfigFile.new()
    
    config.set_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
    config.set_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
    config.set_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
    config.set_value("graphics", "high_quality", DEFAULT_HIGH_QUALITY)
    
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