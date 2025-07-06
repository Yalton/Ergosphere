# DevConsoleManager.gd
extends Node

## Singleton that manages dev console commands and processing with permission and log system
## Access via DevConsoleManager in your code

signal command_processed(command: String, args: Array)
signal output_requested(text: String, type: String)
signal rebooted
signal diag_run

## Array of terminal log resources
@export var terminal_logs: Array[TerminalLog] = []

var commands: Dictionary = {}
var command_aliases: Dictionary = {}
var dev_console_ui: Control = null
var module_name: String = "DevConsoleManager"
var is_admin: bool = false

func _ready() -> void:
	# Register with DebugLogger
	DebugLogger.register_module(module_name, true)
	
	# Connect output signal
	output_requested.connect(_on_output_requested)
	
	DebugLogger.info(module_name, "Dev Console Manager initialized with " + str(terminal_logs.size()) + " logs")

func set_console_ui(console_ui: Control, admin_mode: bool = false) -> void:
	dev_console_ui = console_ui
	is_admin = admin_mode
	DebugLogger.debug(module_name, "Console UI reference set. Admin mode: " + str(is_admin))

func register_command(p_name: String, method: Callable, description: String = "", admin_only: bool = false) -> void:
	commands[p_name.to_lower()] = {
		"method": method,
		"description": description,
		"admin_only": admin_only
	}
	DebugLogger.debug(module_name, "Registered command: " + p_name + " (admin_only: " + str(admin_only) + ")")

func register_alias(alias: String, command: String) -> void:
	command_aliases[alias.to_lower()] = command.to_lower()
	DebugLogger.debug(module_name, "Registered alias: %s -> %s" % [alias, command])

func unregister_command(p_name: String) -> void:
	commands.erase(p_name.to_lower())
	# Remove any aliases pointing to this command
	for alias in command_aliases:
		if command_aliases[alias] == p_name.to_lower():
			command_aliases.erase(alias)
	DebugLogger.debug(module_name, "Unregistered command: " + p_name)

func process_command(input: String) -> void:
	var parts = input.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	
	var command = parts[0].to_lower()
	var args = parts.slice(1)
	
	# Check for alias
	if command in command_aliases:
		command = command_aliases[command]
	
	# Execute command
	if command in commands:
		var cmd_data = commands[command]
		
		# Check permissions
		if cmd_data["admin_only"] and not is_admin:
			output_error("Permission denied. Admin access required.")
			return
		
		DebugLogger.debug(module_name, "Executing command: %s with args: %s" % [command, args])
		cmd_data["method"].call(args)
		command_processed.emit(command, args)
	else:
		output_error("Unknown command: " + command)
		output_system("Type 'help' for available commands")

func output(text: String) -> void:
	output_requested.emit(text, "normal")

func output_system(text: String) -> void:
	output_requested.emit(text, "system")

func output_error(text: String) -> void:
	output_requested.emit(text, "error")

func output_warning(text: String) -> void:
	output_requested.emit(text, "warning")

func _on_output_requested(text: String, type: String) -> void:
	if not dev_console_ui:
		DebugLogger.warning(module_name, "No console UI set, cannot display: " + text)
		return
	
	match type:
		"normal":
			dev_console_ui.add_line(text)
		"system":
			dev_console_ui.add_system_message(text)
		"error":
			dev_console_ui.add_error_message(text)
		"warning":
			dev_console_ui.add_warning_message(text)
