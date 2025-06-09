extends Node
class_name DevConsoleManager

## Singleton that manages dev console commands and processing
## Access via DevConsoleManager in your code

signal command_processed(command: String, args: Array)
signal output_requested(text: String, type: String)

var commands: Dictionary = {}
var command_aliases: Dictionary = {}
var dev_console_ui: DevConsoleUI = null
var module_name: String = "DevConsoleManager"

func _ready() -> void:
	# Register with DebugLogger
	DebugLogger.register_module(module_name, true)
	
	# Connect output signal
	output_requested.connect(_on_output_requested)
	
	# Register default commands
	_register_default_commands()
	
	DebugLogger.info(module_name, "Dev Console Manager initialized")

func set_console_ui(console_ui: DevConsoleUI) -> void:
	dev_console_ui = console_ui
	DebugLogger.debug(module_name, "Console UI reference set")

func _register_default_commands() -> void:
	# Help command
	register_command("help", _cmd_help, "Shows available commands")
	
	# Clear command
	register_command("clear", _cmd_clear, "Clears the console")
	register_alias("cls", "clear")
	
	# Exit command
	register_command("exit", _cmd_exit, "Closes the console")
	register_alias("quit", "exit")
	
	# Echo command
	register_command("echo", _cmd_echo, "Prints text to console")
	
	# List commands
	register_command("list", _cmd_list, "Lists all available commands")
	
	DebugLogger.debug(module_name, "Default commands registered")

func register_command(name: String, method: Callable, description: String = "") -> void:
	commands[name.to_lower()] = {
		"method": method,
		"description": description
	}
	DebugLogger.debug(module_name, "Registered command: " + name)

func register_alias(alias: String, command: String) -> void:
	command_aliases[alias.to_lower()] = command.to_lower()
	DebugLogger.debug(module_name, "Registered alias: %s -> %s" % [alias, command])

func unregister_command(name: String) -> void:
	commands.erase(name.to_lower())
	# Remove any aliases pointing to this command
	for alias in command_aliases:
		if command_aliases[alias] == name.to_lower():
			command_aliases.erase(alias)
	DebugLogger.debug(module_name, "Unregistered command: " + name)

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

# Default command implementations
func _cmd_help(args: Array) -> void:
	output_system("Available commands:")
	var sorted_commands = commands.keys()
	sorted_commands.sort()
	
	for cmd in sorted_commands:
		var desc = commands[cmd]["description"]
		if desc:
			output("  %s - %s" % [cmd, desc])
		else:
			output("  %s" % cmd)
	
	if not command_aliases.is_empty():
		output_system("\nAliases:")
		for alias in command_aliases:
			output("  %s -> %s" % [alias, command_aliases[alias]])

func _cmd_clear(args: Array) -> void:
	if dev_console_ui:
		dev_console_ui.clear_console()

func _cmd_exit(args: Array) -> void:
	if dev_console_ui:
		dev_console_ui.hide_ui()

func _cmd_echo(args: Array) -> void:
	if args.is_empty():
		output("")
	else:
		output(" ".join(args))

func _cmd_list(args: Array) -> void:
	var sorted_commands = commands.keys()
	sorted_commands.sort()
	output_system("Commands: " + ", ".join(sorted_commands))
