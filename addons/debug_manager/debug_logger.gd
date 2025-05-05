# DebugLogger.gd
extends Node

# Use this to quickly enable/disable all debug output globally
@export var debug_enabled: bool = true

# Flag to disable writing files when shipping the game
@export var disable_file_writing: bool = false

# Path for module configuration resources
const MODULE_CONFIG_PATH = "user://debug_modules/"

# Dictionary to store registered modules and their enabled status
var registered_modules: Dictionary = {}
var module_configs: Dictionary = {}

# Log levels
enum LogLevel {
	INFO,
	WARNING,
	ERROR,
	DEBUG
}

func _ready() -> void:
	# Create module config directory if it doesn't exist and file writing is enabled
	if not disable_file_writing:
		var dir = DirAccess.open("user://")
		if not dir.dir_exists(MODULE_CONFIG_PATH):
			dir.make_dir(MODULE_CONFIG_PATH)
		
	# Print initial header
	print("=== Debug Logger Started ===")
	print("Global debug enabled: " + str(debug_enabled))
	print("File writing disabled: " + str(disable_file_writing))
	print("==========================")

# Register a module for debugging
func register_module(module_name: String, default_enabled: bool = true) -> void:
	# If already registered, just return
	if registered_modules.has(module_name):
		return
	
	var is_enabled = _load_module_config(module_name, default_enabled)
	registered_modules[module_name] = is_enabled
	
	# Only print the registration message if debugging is enabled for this module
	if debug_enabled && is_enabled:
		log_message(module_name, "Module registered for debugging", LogLevel.INFO)

# Load module config from resource file
func _load_module_config(module_name: String, default_enabled: bool) -> bool:
	# If file writing is disabled, just use default value
	if disable_file_writing:
		return default_enabled
		
	var config_path = MODULE_CONFIG_PATH + module_name + ".tres"
	
	# Check if config exists
	if FileAccess.file_exists(config_path):
		# Load existing config
		var config = ResourceLoader.load(config_path)
		if config and config is ModuleDebugConfig:
			module_configs[module_name] = config
			return config.enabled
	
	# Create new config with default setting
	var new_config = ModuleDebugConfig.new()
	new_config.module_name = module_name
	new_config.enabled = default_enabled
	
	# Save the resource if file writing is enabled
	if not disable_file_writing:
		var err = ResourceSaver.save(new_config, config_path)
		if err != OK:
			push_error("Failed to save module config for: " + module_name)
	
	module_configs[module_name] = new_config
	return default_enabled

# Save module config to resource file
func _save_module_config(module_name: String, enabled: bool) -> void:
	# Skip if file writing is disabled
	if disable_file_writing:
		return
		
	var config_path = MODULE_CONFIG_PATH + module_name + ".tres"
	
	# Update or create config
	var config = module_configs.get(module_name)
	if not config:
		config = ModuleDebugConfig.new()
		config.module_name = module_name
		module_configs[module_name] = config
	
	config.enabled = enabled
	
	# Save to file
	var err = ResourceSaver.save(config, config_path)
	if err != OK:
		push_error("Failed to save module config for: " + module_name)

# Delete all module config files - useful for shipping
func delete_all_config_files() -> int:
	var files_deleted = 0
	
	# Open the directory
	var dir = DirAccess.open(MODULE_CONFIG_PATH)
	if dir:
		# List all files
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		# Delete all .tres files
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = MODULE_CONFIG_PATH + file_name
				var err = dir.remove(full_path)
				if err == OK:
					files_deleted += 1
				
			# Get next file
			file_name = dir.get_next()
	
	return files_deleted

# Unregister a module
func unregister_module(module_name: String) -> void:
	if registered_modules.has(module_name):
		registered_modules.erase(module_name)

# Enable or disable a specific module
func set_module_enabled(module_name: String, enabled: bool) -> void:
	if registered_modules.has(module_name):
		registered_modules[module_name] = enabled
		
		# Save the updated setting
		_save_module_config(module_name, enabled)
		
		if debug_enabled:
			log_message(module_name, "Debug " + ("enabled" if enabled else "disabled"), LogLevel.INFO)

# Enable or disable all modules
func set_all_modules_enabled(enabled: bool) -> void:
	for module in registered_modules.keys():
		set_module_enabled(module, enabled)

# Check if a module is registered and enabled
func is_module_enabled(module_name: String) -> bool:
	return debug_enabled && registered_modules.has(module_name) && registered_modules[module_name]

# Main logging function - renamed to avoid conflict with built-in log()
func log_message(module_name: String, message: String, level: int = LogLevel.DEBUG) -> void:
	if !is_module_enabled(module_name):
		return
		
	var level_text = get_level_text(level)
	
	# Format: [Module][Level] Message
	var formatted_message = "[%s][%s] %s" % [module_name, level_text, message]
	
	# Print to console
	print(formatted_message)

# Log specifically for debug level
func debug(module_name: String, message: String) -> void:
	log_message(module_name, message, LogLevel.DEBUG)

# Log specifically for info level
func info(module_name: String, message: String) -> void:
	log_message(module_name, message, LogLevel.INFO)

# Log specifically for warning level
func warning(module_name: String, message: String) -> void:
	log_message(module_name, message, LogLevel.WARNING)

# Log specifically for error level
func error(module_name: String, message: String) -> void:
	log_message(module_name, message, LogLevel.ERROR)

# Helper function to get text representation of log level
func get_level_text(level: int) -> String:
	match level:
		LogLevel.INFO:
			return "INFO"
		LogLevel.WARNING:
			return "WARN"
		LogLevel.ERROR:
			return "ERROR"
		LogLevel.DEBUG:
			return "DEBUG"
		_:
			return "UNKNOWN"

# Print out all registered modules and their status
func list_modules() -> void:
	if !debug_enabled:
		return
		
	print("\n=== Debug Modules ===")
	print("Debug system: " + ("ENABLED" if debug_enabled else "DISABLED"))
	print("File writing: " + ("DISABLED" if disable_file_writing else "ENABLED"))
	
	var sorted_modules = registered_modules.keys()
	sorted_modules.sort()
	
	for module in sorted_modules:
		var status = "ENABLED" if registered_modules[module] else "DISABLED"
		print("%s: %s" % [module, status])
	print("====================\n")

# Save current module settings and configurations to a file
func save_all_configurations() -> void:
	if disable_file_writing:
		print("File writing is disabled, not saving configurations.")
		return
		
	for module_name in registered_modules.keys():
		_save_module_config(module_name, registered_modules[module_name])
	print("All debug module configurations saved.")

# Reset all modules to their default state (enabled)
func reset_all_modules() -> void:
	for module_name in registered_modules.keys():
		set_module_enabled(module_name, true)
	print("All debug modules reset to enabled state.")

# Enable or disable file writing
func set_file_writing_enabled(enabled: bool) -> void:
	disable_file_writing = !enabled
	print("File writing " + ("disabled" if disable_file_writing else "enabled"))
