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
	
	# Register default commands
	_register_default_commands()
	
	# Register game commands
	_register_game_commands()
	
	# Register log commands
	_register_log_commands()
	
	DebugLogger.info(module_name, "Dev Console Manager initialized with " + str(terminal_logs.size()) + " logs")

func set_console_ui(console_ui: Control, admin_mode: bool = false) -> void:
	dev_console_ui = console_ui
	is_admin = admin_mode
	DebugLogger.debug(module_name, "Console UI reference set. Admin mode: " + str(is_admin))

func _register_default_commands() -> void:
	# Help command
	register_command("help", _cmd_help, "Shows available commands", false)
	
	# Clear command
	register_command("clear", _cmd_clear, "Clears the console", false)
	register_alias("cls", "clear")
	
	# Exit command
	register_command("exit", _cmd_exit, "Closes the console", false)
	register_alias("quit", "exit")
	register_command("list_events", _cmd_list_events, "Lists all available events", true)
	# Echo command
	register_command("echo", _cmd_echo, "Prints text to console", false)
	
	register_command("reboot", _cmd_reboot, "Reboots Station systems", false)

	# List commands
	register_command("list", _cmd_list, "Lists all available commands", false)
	register_command("diag", _cmd_diagnostics, "Runs Diagnostics on the system", false)
	DebugLogger.debug(module_name, "Default commands registered")

func _register_game_commands() -> void:
	# Admin-only commands
	register_command("trigger_event", _cmd_trigger_event, "Triggers a game event by ID", true)
	register_command("assign_task", _cmd_assign_task, "Assigns a task by ID", true)
	register_command("complete_task", _cmd_complete_task, "Force completes a task by ID", true)
	register_command("next_day", _cmd_next_day, "Instantly starts the next day", true)
	register_command("no_clip", _cmd_noclip, "Exactly what it sounds like", true)
	register_command("complete_all_daily", _cmd_complete_all_daily, "Completes all active daily tasks", true)
	
	# User-accessible commands
	register_command("status", _cmd_status, "Shows current game status", false)
	register_command("tasks", _cmd_tasks, "Lists current active tasks", false)
	
	DebugLogger.debug(module_name, "Game commands registered")

func _register_log_commands() -> void:
	# Log commands accessible to all users
	register_command("logs", _cmd_list_logs, "Lists available terminal logs", false)
	register_command("log", _cmd_show_log, "Shows a specific log (usage: log <number>)", false)
	
	# Admin can unlock logs
	register_command("unlock_log", _cmd_unlock_log, "Unlocks a specific log", true)
	
	DebugLogger.debug(module_name, "Log commands registered")

func register_command(name: String, method: Callable, description: String = "", admin_only: bool = false) -> void:
	commands[name.to_lower()] = {
		"method": method,
		"description": description,
		"admin_only": admin_only
	}
	DebugLogger.debug(module_name, "Registered command: " + name + " (admin_only: " + str(admin_only) + ")")

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

# Default command implementations
func _cmd_help(args: Array) -> void:
	output_system("Available commands:")
	var sorted_commands = commands.keys()
	sorted_commands.sort()
	
	for cmd in sorted_commands:
		var cmd_data = commands[cmd]
		# Skip admin commands if not admin
		if cmd_data["admin_only"] and not is_admin:
			continue
			
		var desc = cmd_data["description"]
		var admin_tag = " [ADMIN]" if cmd_data["admin_only"] else ""
		if desc:
			output("  %s%s - %s" % [cmd, admin_tag, desc])
		else:
			output("  %s%s" % [cmd, admin_tag])
	
	if not command_aliases.is_empty():
		output_system("\nAliases:")
		for alias in command_aliases:
			output("  %s -> %s" % [alias, command_aliases[alias]])

func _cmd_clear(args: Array) -> void:
	if dev_console_ui:
		dev_console_ui.clear_console()

func _cmd_reboot(args: Array) -> void:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	rebooted.emit()
	if effects_manager: 
		effects_manager.kill_power(5.0)
		output_system("Reboot issued successfully")
	else: 
		output_system("Reboot has failed")
		
func _cmd_exit(args: Array) -> void:
	if dev_console_ui:
		dev_console_ui.hide_console()

func _cmd_echo(args: Array) -> void:
	if args.is_empty():
		output("")
	else:
		output(" ".join(args))

func _cmd_list(args: Array) -> void:
	var sorted_commands = commands.keys()
	sorted_commands.sort()
	
	var available_commands = []
	for cmd in sorted_commands:
		if not commands[cmd]["admin_only"] or is_admin:
			available_commands.append(cmd)
	
	output_system("Commands: " + ", ".join(available_commands))

# Game command implementations
func _cmd_trigger_event(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: trigger_event <event_id>")
		return
	
	var event_id = args[0]
	GameManager.event_manager.force_trigger_event(event_id)



func _cmd_assign_task(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: assign_task <task_id>")
		return
	
	var task_id = args[0]
	
	if GameManager.task_manager:
		var task = GameManager.task_manager.get_task(task_id)
		if task:
			GameManager.task_manager.assign_task(task)
			output_system("Task '%s' assigned successfully" % task_id)
		else:
			output_error("Task '%s' not found" % task_id)
	else:
		output_error("Task manager not available")

func _cmd_diagnostics(args: Array) -> void:
	# ASCII art
	output("                                                        ")
	output("   m    #               m    #                          ")
	output(" mm#mm  # mm    mmm   mm#mm  # mm           mmm    mmm  ")
	output("   #    #:  #  #: :#    #    #:  #         #: :#  #   : ")
	output("   #    #   #  #   #    #    #   #   :::   #   #   :::m ")
	output("   :mm  #   #  :#m#:    :mm  #   #         :#m#:  :mmm: ")
	output("                                                        ")
														
	
	# Fake diagnostic info
	output_system("THOTH Operating System v3.14.159")
	output("Kernel: THOTH-CORE 7.42.1337")
	output("Architecture: x86_64")
	output("Uptime: " + str(randi_range(100, 9999)) + " cycles")
	output("Memory: " + str(randi_range(60, 95)) + "% utilized")
	output("Quantum cores: " + str(randi_range(4, 16)) + " active")
	output("Neural pathways: " + str(randi_range(1024, 8192)) + " synchronized")
	output("Temporal variance: " + str(randf_range(0.001, 0.999)) + "ms")
	output("Consciousness buffer: " + str(randi_range(70, 100)) + "% coherent")
	output("")
	output_system("All systems nominal.")
	diag_run.emit()
	
func _cmd_complete_task(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: complete_task <task_id>")
		return
	
	var task_id = args[0]
	GameManager.task_manager.complete_task(task_id)
	output_system("Task '%s' force completed" % task_id)

# Add this command implementation
func _cmd_complete_all_daily(args: Array) -> void:
	if not GameManager.task_manager:
		output_error("Task manager not available")
		return
	
	var todays_tasks = GameManager.task_manager.get_todays_tasks()
	var completed_count = 0
	var already_completed = 0
	var failed_count = 0
	
	output_system("=== Completing All Daily Tasks ===")
	
	for task in todays_tasks:
		# Skip sleep task and emergency tasks
		if task.task_id == GameManager.task_manager.sleep_task_id:
			continue
			
		if task.is_completed:
			already_completed += 1
			output("SKIP: %s (already completed)" % task.task_name)
			continue
		
		# Force complete the task
		GameManager.task_manager.complete_task(task.task_id)
		
		# Check if it actually completed
		if task.is_completed:
			completed_count += 1
			output("DONE: %s" % task.task_name)
		else:
			failed_count += 1
			output_warning("FAIL: %s (conditions not met)" % task.task_name)
	
	output_system("=== Summary ===")
	output("Completed: %d" % completed_count)
	output("Already done: %d" % already_completed)
	output("Failed: %d" % failed_count)
	
	if completed_count > 0:
		output_system("All completable daily tasks have been finished")
	else:
		output_warning("No tasks were completed")
		
func _cmd_next_day(args: Array) -> void:
	if GameManager.time_manager:
		GameManager.time_manager.start_next_day()
		output_system("Started next day")
	else:
		output_error("Time manager not available")

func _cmd_status(args: Array) -> void:
	output_system("=== Game Status ===")
	
	# Time status
	if GameManager.time_manager:
		output("Day: %d" % GameManager.time_manager.current_day)
		output("Time: %s" % GameManager.time_manager.get_time_string())
	
	# Task status
	if GameManager.task_manager:
		var active_tasks = GameManager.task_manager.get_active_tasks()
		output("Active tasks: %d" % active_tasks.size())
	
	# Player status
	if GameManager.player:
		output("Player position: %s" % str(GameManager.player.global_position))

func _cmd_tasks(args: Array) -> void:
	if not GameManager.task_manager:
		output_error("Task manager not available")
		return
	
	var active_tasks = GameManager.task_manager.get_active_tasks()
	
	if active_tasks.is_empty():
		output_system("No active tasks")
		return
	
	output_system("=== Active Tasks ===")
	for task in active_tasks:
		var status = "In Progress" if not task.is_completed else "Completed"
		output("[%s] %s - %s" % [task.task_id, task.task_name, status])
		if task.task_description:
			output("  Description: %s" % task.task_description)

# Log command implementations
func _cmd_list_logs(args: Array) -> void:
	if terminal_logs.is_empty():
		output_system("No logs available in the system")
		return
	
	output_system("=== Available Terminal Logs ===")
	
	for i in range(terminal_logs.size()):
		var log = terminal_logs[i]
		if not log:
			continue
			
		var status = ""
		if log.is_locked:
			if log.is_accessible():
				status = " [UNLOCKED]"
			else:
				status = " [LOCKED]"
		
		var security = ""
		if not log.security_level.is_empty():
			security = " (" + log.security_level + ")"
		
		output("%d. %s%s%s" % [i + 1, log.log_title, security, status])
	
	output_system("\nUse 'log <number>' to read a specific log")

func _cmd_show_log(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: log <number>")
		output("Example: log 1")
		return
	
	var log_number = args[0].to_int()
	
	if log_number < 1 or log_number > terminal_logs.size():
		output_error("Invalid log number. Use 'logs' to see available logs")
		return
	
	var log = terminal_logs[log_number - 1]
	
	if not log:
		output_error("Log data is missing")
		return
	
	# Check if accessible
	if not log.is_accessible():
		output_error(log.locked_message)
		if not log.unlock_state_name.is_empty():
			output_system("Required: %s = %s" % [log.unlock_state_name, str(log.unlock_state_value)])
		return
	
	# Display the log
	output_system(log.get_formatted_content())

func _cmd_noclip(args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player") as Player
	
	if not player:
		output_error("Player not found")
		return
	
	if not player.has_method("toggle_noclip"):
		output_error("Player doesn't support noclip")
		return
	
	player.toggle_noclip()
	var state = "enabled" if player.noclip_enabled else "disabled"
	output_system("No-clip mode " + state)
	
func _cmd_unlock_log(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: unlock_log <number>")
		return
	
	var log_number = args[0].to_int()
	
	if log_number < 1 or log_number > terminal_logs.size():
		output_error("Invalid log number")
		return
	
	var log = terminal_logs[log_number - 1]
	
	if not log:
		output_error("Log data is missing")
		return
	
	if not log.is_locked:
		output_warning("Log is not locked")
		return

	# Force unlock by setting the required state
	if not log.unlock_state_name.is_empty() and GameManager.state_manager:
		GameManager.state_manager.set_state(log.unlock_state_name, log.unlock_state_value)
		output_system("Log '%s' unlocked by setting %s to %s" % [log.log_title, log.unlock_state_name, str(log.unlock_state_value)])
	else:
		log.is_locked = false
		output_system("Log '%s' force unlocked" % log.log_title)
	

func _cmd_list_events(args: Array) -> void:
	if not GameManager.event_manager:
		output_error("Event Manager not initialized")
		return
	
	var events = GameManager.event_manager.available_events
	if events.is_empty():
		output_warning("No events configured")
		return
	
	output_system("=== Available Events ===")
	output_system("Total: %d events" % events.size())
	output("")
	
	# Sort events by category then by ID
	var sorted_events = events.duplicate()
	sorted_events.sort_custom(func(a, b): 
		if a.category != b.category:
			return a.category < b.category
		return a.event_id < b.event_id
	)
	
	var current_category = -1
	for event in sorted_events:
		# Category header
		if event.category != current_category:
			current_category = event.category
			output("")
			output_system("--- %s Events ---" % event.get_category_description())
		
		# Event details
		var severity = event.get_severity_description()
		var tension_str = "T:%d" % event.tension_score
		var disruption_str = "D:%d" % event.disruption_score
		var chance_str = "%.1f%%" % event.base_chance if event.category != EventData.EventCategory.PLANNED else "PLANNED"
		var day_str = ""
		
		# Add day restrictions if any
		if event.min_day > 0 or event.max_day > 0:
			if event.min_day > 0 and event.max_day > 0:
				day_str = " [Days %d-%d]" % [event.min_day, event.max_day]
			elif event.min_day > 0:
				day_str = " [Day %d+]" % event.min_day
			else:
				day_str = " [Days 1-%d]" % event.max_day
		
		# For planned events, show scheduled day
		if event.category == EventData.EventCategory.PLANNED:
			day_str = " [Day %d @ %02d:00]" % [event.scheduled_day, int(event.scheduled_time_hours)]
		
		# Format: ID - Name (Severity) [T:X D:Y] Chance% [Day restrictions]
		var line = "  %s - %s (%s) [%s %s] %s%s" % [
			event.event_id,
			event.event_name if not event.event_name.is_empty() else "Unnamed",
			severity,
			tension_str,
			disruption_str,
			chance_str,
			day_str
		]
		
		output(line)
		
		# Show cooldowns
		var cooldown_info = []
		if event.tension_cooldown > 0:
			cooldown_info.append("Tension CD: %.1fs" % event.tension_cooldown)
		if event.disruption_cooldown > 0:
			cooldown_info.append("Disruption CD: %.1fs" % event.disruption_cooldown)
		if not cooldown_info.is_empty():
			output("    Cooldowns: %s" % ", ".join(cooldown_info))
		
		# Show custom data if any
		if not event.custom_data.is_empty():
			output("    Custom Data: %s" % str(event.custom_data))
	
	# Show current cooldowns
	output("")
	output_system("--- Active Cooldowns ---")
	var cooldowns = GameManager.event_manager.active_cooldowns
	if cooldowns.is_empty():
		output("  None")
	else:
		for key in cooldowns:
			output("  %s: %.1fs remaining" % [key, cooldowns[key]])
	
	# Show scheduled events
	output("")
	output_system("--- Scheduled Events ---")
	var scheduled = GameManager.event_manager.scheduled_events
	if scheduled.is_empty():
		output("  None")
	else:
		for sched in scheduled:
			var time_str = Time.get_datetime_string_from_unix_time(int(sched.trigger_time))
			output("  %s on Day %d at %s" % [sched.event_id, sched.scheduled_day, time_str])
	
	# Show current state
	output("")
	output_system("--- Event System State ---")
	output("  Current Day: %d" % GameManager.event_manager.current_day)
	output("  Insanity Level: %.1f" % GameManager.event_manager.insanity_level)
	output("  Task Completion Boost: %.1fx" % GameManager.event_manager.task_completion_boost)
	
	DebugLogger.debug(module_name, "Listed %d events" % events.size())
	
