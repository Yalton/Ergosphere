extends BaseCommandHandler
## Handles core console commands like help, clear, exit, echo

func _ready() -> void:
	handler_name = "CoreCommands"
	super._ready()

func register_commands() -> void:
	# Basic commands everyone can use
	register_command("help", _cmd_help, "Shows available commands", false)
	register_command("clear", _cmd_clear, "Clears the console", false)
	register_alias("cls", "clear")
	register_command("exit", _cmd_exit, "Closes the console", false)
	register_alias("quit", "exit")
	register_command("echo", _cmd_echo, "Prints text to console", false)
	register_command("list", _cmd_list, "Lists all available commands", false)

func _cmd_help(args: Array) -> void:
	output_system("Available commands:")
	var sorted_commands = DevConsoleManager.commands.keys()
	sorted_commands.sort()
	
	for cmd in sorted_commands:
		var cmd_data = DevConsoleManager.commands[cmd]
		# Skip admin commands if not admin
		if cmd_data["admin_only"] and not DevConsoleManager.is_admin:
			continue
			
		var desc = cmd_data["description"]
		var admin_tag = " [ADMIN]" if cmd_data["admin_only"] else ""
		if desc:
			output("  %s%s - %s" % [cmd, admin_tag, desc])
		else:
			output("  %s%s" % [cmd, admin_tag])
	
	# Only show aliases for commands the user can access
	var visible_aliases = {}
	for alias in DevConsoleManager.command_aliases:
		var target_cmd = DevConsoleManager.command_aliases[alias]
		if target_cmd in DevConsoleManager.commands:
			var cmd_data = DevConsoleManager.commands[target_cmd]
			# Only show alias if user has permission for the target command
			if not cmd_data["admin_only"] or DevConsoleManager.is_admin:
				visible_aliases[alias] = target_cmd
	
	if not visible_aliases.is_empty():
		output_system("\nAliases:")
		for alias in visible_aliases:
			output("  %s -> %s" % [alias, visible_aliases[alias]])

func _cmd_clear(args: Array) -> void:
	if DevConsoleManager.dev_console_ui:
		DevConsoleManager.dev_console_ui.clear_console()

func _cmd_exit(args: Array) -> void:
	if DevConsoleManager.dev_console_ui:
		DevConsoleManager.dev_console_ui.hide_console()

func _cmd_echo(args: Array) -> void:
	if args.is_empty():
		output("")
	else:
		output(" ".join(args))

func _cmd_list(args: Array) -> void:
	var sorted_commands = DevConsoleManager.commands.keys()
	sorted_commands.sort()
	
	var available_commands = []
	for cmd in sorted_commands:
		var cmd_data = DevConsoleManager.commands[cmd]
		# Only add command to list if user has permission
		if not cmd_data["admin_only"] or DevConsoleManager.is_admin:
			available_commands.append(cmd)
	
	output_system("Commands: " + ", ".join(available_commands))
