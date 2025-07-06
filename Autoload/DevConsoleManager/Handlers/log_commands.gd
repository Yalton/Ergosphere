# LogCommands.gd
extends BaseCommandHandler

## Handles terminal log commands
func _ready() -> void:
	handler_name = "LogCommands"
	super._ready()

func register_commands() -> void:
	# User commands
	register_command("logs", _cmd_list_logs, "Lists available terminal logs", false)
	register_command("log", _cmd_show_log, "Shows a specific log (usage: log <number>)", false)

func _cmd_list_logs(args: Array) -> void:
	if DevConsoleManager.terminal_logs.is_empty():
		output_system("No logs available in the system")
		return
	
	output_system("=== Available Terminal Logs ===")
	
	for i in range(DevConsoleManager.terminal_logs.size()):
		var log_data = DevConsoleManager.terminal_logs[i]
		if not log_data:
			continue
			
		var status = ""
		if log_data.password_protected:
			status = " [PASSWORD]"
		elif log_data.is_locked:
			if log_data.is_accessible():
				status = " [UNLOCKED]"
			else:
				status = " [LOCKED]"
		
		var security = ""
		if not log_data.security_level.is_empty():
			security = " (" + log_data.security_level + ")"
		
		output("%d. %s%s%s" % [i + 1, log_data.log_title, security, status])
	
	output_system("\nUse 'log <number>' to read a specific log")
	output_system("Password protected logs require: 'log <number> <password>'")

func _cmd_show_log(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: log <number> [password]")
		output("Example: log 1")
		output("Example: log 37 ABC123")
		return
	
	var log_number = args[0].to_int()
	
	if log_number < 1 or log_number > DevConsoleManager.terminal_logs.size():
		output_error("Invalid log number. Use 'logs' to see available logs")
		return
	
	var log_data = DevConsoleManager.terminal_logs[log_number - 1]
	
	if not log_data:
		output_error("Log data is missing")
		return
	
	# Check if password protected
	if log_data.password_protected:
		if args.size() < 2:
			output_error("Access Denied - Password Required")
			output_system("Usage: log %d <password>" % log_number)
			return
		
		var provided_password = args[1]
		if not GameManager or not GameManager.has_method("get_session_password"):
			output_error("Password system not initialized")
			return
			
		if provided_password != GameManager.get_session_password():
			output_error("Access Denied - Invalid Password")
			DebugLogger.info(module_name, "Failed password attempt for log %d: %s" % [log_number, provided_password])
			return
		
		DebugLogger.info(module_name, "Log %d accessed with correct password" % log_number)
	
	# Check if accessible (state-based locking)
	if not log_data.is_accessible():
		output_error(log_data.locked_message)
		if not log_data.unlock_state_name.is_empty():
			output_system("Required: %s = %s" % [log_data.unlock_state_name, str(log_data.unlock_state_value)])
		return
	
	# Display the log
	output_system(log_data.get_formatted_content())
