# LogCommands.gd
extends BaseCommandHandler

## Handles terminal log commands
func _ready() -> void:
	handler_name = "LogCommands"
	module_name = "LogCommands"
	# Register with debug logger
	DebugLogger.register_module(module_name, true)
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
	
	var current_day = GameManager.current_day if GameManager else 1
	
	for i in range(DevConsoleManager.terminal_logs.size()):
		var log_data = DevConsoleManager.terminal_logs[i]
		if not log_data:
			continue
		
		var log_number = i + 1
		var status = ""
		
		# Check if it's the password-protected log (log 11)
		if log_number == 11:
			status = " [PASSWORD REQUIRED]"
		else:
			# Check if day-locked
			if not _is_log_available_on_day(log_number, current_day):
				var required_day = _get_required_day_for_log(log_number)
				status = " [LOCKED - Day %d]" % required_day
		
		var security = ""
		if not log_data.security_level.is_empty():
			security = " (" + log_data.security_level + ")"
		
		output("%d. %s%s%s" % [log_number, log_data.log_title, security, status])
	
	output_system("\nUse 'log <number>' to read a specific log")
	output_system("Log 11 requires: 'log 11 <password>'")
	output_system("Current Day: %d" % current_day)

func _cmd_show_log(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: log <number> [password]")
		output("Example: log 1")
		output("Example: log 11 iconoclast")
		return
	
	var log_number = args[0].to_int()
	
	if log_number < 1 or log_number > DevConsoleManager.terminal_logs.size():
		output_error("Invalid log number. Use 'logs' to see available logs")
		return
	
	var log_data = DevConsoleManager.terminal_logs[log_number - 1]
	
	if not log_data:
		output_error("Log data is missing")
		return
	
	var current_day = GameManager.current_day if GameManager else 1
	
	# Check if it's the special password-protected log (log 11)
	if log_number == 11:
		if args.size() < 2:
			output_error("Access Denied - Password Required")
			output_system("Usage: log 11 <password>")
			return
		
		var provided_password = args[1].to_lower()
		if provided_password != "iconoclast":
			output_error("Access Denied - Invalid Password")
			DebugLogger.info(module_name, "Failed password attempt for log 11: %s" % provided_password)
			return
		
		DebugLogger.info(module_name, "Log 11 accessed with correct password")
		# Display the log
		output_system(log_data.get_formatted_content())
		return
	
	# Check day-based availability for all other logs
	if not _is_log_available_on_day(log_number, current_day):
		var required_day = _get_required_day_for_log(log_number)
		output_error("Access Denied - Encrypted")
		output_system("This log will decrypt on Day %d" % required_day)
		output_system("Current Day: %d" % current_day)
		return
	
	# Display the log
	output_system(log_data.get_formatted_content())
	DebugLogger.debug(module_name, "Log %d accessed on day %d" % [log_number, current_day])

func _is_log_available_on_day(log_number: int, current_day: int) -> bool:
	# Log 11 is always "available" but password protected
	if log_number == 11:
		return true
	
	# Logs unlock in pairs of 2 based on day
	# Logs 1-2: Day 1+
	# Logs 3-4: Day 2+
	# Logs 5-6: Day 3+
	# Logs 7-8: Day 4+
	# Logs 9-10: Day 5+
	
	var required_day = _get_required_day_for_log(log_number)
	return current_day >= required_day

func _get_required_day_for_log(log_number: int) -> int:
	# Calculate which day a log unlocks on
	# Logs 1-2 = Day 1
	# Logs 3-4 = Day 2
	# Logs 5-6 = Day 3
	# Logs 7-8 = Day 4
	# Logs 9-10 = Day 5
	
	if log_number <= 2:
		return 1
	elif log_number <= 4:
		return 2
	elif log_number <= 6:
		return 3
	elif log_number <= 8:
		return 4
	elif log_number <= 10:
		return 5
	else:
		# Log 11+ are special cases (password protected)
		return 1
