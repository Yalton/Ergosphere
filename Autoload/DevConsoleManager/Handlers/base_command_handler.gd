# BaseCommandHandler.gd
extends Node
class_name BaseCommandHandler

## Base class for command handlers that register with DevConsoleManager
## Handles common functionality like debug logging and registration

## Name of this command handler module
@export var handler_name: String = "BaseCommandHandler"
## Whether to enable debug logging for this handler
@export var enable_debug: bool = true

var module_name: String

func _ready() -> void:
	module_name = handler_name
	DebugLogger.register_module(module_name, enable_debug)
	
	# Register our commands with the main console manager
	register_commands()
	
	DebugLogger.info(module_name, "Command handler initialized")

## Override this in child classes to register specific commands
func register_commands() -> void:
	DebugLogger.warning(module_name, "No commands registered - override register_commands() in child class")

## Helper function to register a command with the main console manager
func register_command(p_name: String, method: Callable, description: String = "", admin_only: bool = false) -> void:
	DevConsoleManager.register_command(p_name, method, description, admin_only)
	DebugLogger.debug(module_name, "Registered command: " + p_name)

## Helper function to register an alias
func register_alias(alias: String, command: String) -> void:
	DevConsoleManager.register_alias(alias, command)
	DebugLogger.debug(module_name, "Registered alias: %s -> %s" % [alias, command])

## Helper functions for output
func output(text: String) -> void:
	DevConsoleManager.output(text)

func output_system(text: String) -> void:
	DevConsoleManager.output_system(text)

func output_error(text: String) -> void:
	DevConsoleManager.output_error(text)

func output_warning(text: String) -> void:
	DevConsoleManager.output_warning(text)
