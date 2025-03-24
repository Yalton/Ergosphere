# DebugLogger.gd
extends Node

# Use this to quickly enable/disable all debug output globally
var debug_enabled: bool = true

# Enable to write debug messages to a file
var log_to_file: bool = false
var log_file_path: String = "user://debug_log.txt"
var log_file = null

# Dictionary to store registered modules and their enabled status
var registered_modules: Dictionary = {}

# Log levels
enum LogLevel {
	INFO,
	WARNING,
	ERROR,
	DEBUG
}

# Log level colors
const LEVEL_COLORS = {
	LogLevel.INFO: "white",
	LogLevel.WARNING: "yellow",
	LogLevel.ERROR: "red",
	LogLevel.DEBUG: "cyan"
}

# Called when the node enters the scene tree for the first time
func _ready() -> void:
	if log_to_file:
		open_log_file()

# Called when the node is about to be removed from the scene tree
func _exit_tree() -> void:
	if log_file:
		close_log_file()

# Open log file for writing
func open_log_file() -> void:
	if log_to_file:
		log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
		if log_file:
			var timestamp = Time.get_datetime_string_from_system()
			log_file.store_line("=== Debug Log Started: %s ===" % timestamp)
		else:
			print("ERROR: Could not open debug log file at: " + log_file_path)

# Append to log file
func close_log_file() -> void:
	if log_file:
		log_file.close()
		log_file = null

# Register a module for debugging
func register_module(module_name: String, enabled: bool = true) -> void:
	registered_modules[module_name] = enabled
	
	# Only print the registration message if debugging is enabled for this module
	if debug_enabled && enabled:
		log_message(module_name, "Module registered for debugging", LogLevel.INFO)

# Unregister a module
func unregister_module(module_name: String) -> void:
	if registered_modules.has(module_name):
		registered_modules.erase(module_name)

# Enable or disable a specific module
func set_module_enabled(module_name: String, enabled: bool) -> void:
	if registered_modules.has(module_name):
		registered_modules[module_name] = enabled
		if debug_enabled:
			log_message(module_name, "Debug " + ("enabled" if enabled else "disabled"), LogLevel.INFO)

# Enable or disable all modules
func set_all_modules_enabled(enabled: bool) -> void:
	for module in registered_modules.keys():
		registered_modules[module] = enabled

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
	
	# Write to log file if enabled
	if log_to_file and log_file:
		var timestamp = Time.get_time_string_from_system()
		log_file.store_line("[%s] %s" % [timestamp, formatted_message])

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
	
	for module in registered_modules.keys():
		var status = "ENABLED" if registered_modules[module] else "DISABLED"
		print("%s: %s" % [module, status])
	print("====================\n")
