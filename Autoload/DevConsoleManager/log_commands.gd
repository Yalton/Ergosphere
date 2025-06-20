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
	
	# Admin commands
	register_command("unlock_log", _cmd_unlock_log, "Unlocks a specific log", true)

func _cmd_list_logs(args: Array) -> void:
	var logs = DevConsoleManager.terminal_logs
	if logs.is_empty():
		output_system("No terminal logs available")
		return
	
	output_system("Available terminal logs:")
	for i in range(logs.size()):
		var log = logs[i]
		var status = "LOCKED" if not log.is_unlocked else "UNLOCKED"
		output("  %d. %s [%s]" % [i + 1, log.log_title, status])

func _cmd_show_log(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: log <number>")
		return
	
	var log_index = args[0].to_int() - 1  # Convert to 0-based index
	var logs = DevConsoleManager.terminal_logs
	
	if log_index < 0 or log_index >= logs.size():
		output_error("Invalid log number. Use 'logs' to see available logs.")
		return
	
	var log = logs[log_index]
	if not log.is_unlocked:
		output_error("Log is locked. Admin can unlock with 'unlock_log %d'" % (log_index + 1))
		return
	
	output_system("=== %s ===" % log.log_title)
	output(log.log_content)

func _cmd_unlock_log(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: unlock_log <number>")
		return
	
	var log_index = args[0].to_int() - 1
	var logs = DevConsoleManager.terminal_logs
	
	if log_index < 0 or log_index >= logs.size():
		output_error("Invalid log number. Use 'logs' to see available logs.")
		return
	
	var log = logs[log_index]
	log.is_unlocked = true
	output_system("Unlocked log: %s" % log.log_title)
