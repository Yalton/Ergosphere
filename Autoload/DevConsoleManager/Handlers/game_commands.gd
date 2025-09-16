# GameCommands.gd
extends BaseCommandHandler


## Handles game-specific commands like events, tasks, tension, diagnostics
func _ready() -> void:
	handler_name = "GameCommands"
	module_name = "GameCommands"
	# Register with debug logger
	DebugLogger.register_module(module_name, true)
	super._ready()

func register_commands() -> void:
	# Admin commands
	register_command("assign_task", _cmd_assign_task, "Assigns a task by ID", true)
	register_command("complete_task", _cmd_complete_task, "Force completes a task by ID", true)
	register_command("fail_task", _cmd_fail_task, "Force fails an emergency task by ID", true)
	register_command("next_day", _cmd_next_day, "Instantly starts the next day", true)
	register_command("set_day", _cmd_set_day, "Sets the current day to a specific value", true)
	register_command("no_clip", _cmd_noclip, "Exactly what it sounds like", true)
	register_command("complete_all_daily", _cmd_complete_all_daily, "Completes all active daily tasks", true)
	register_command("unlock_log", _cmd_unlock_log, "Unlocks a specific log", true)
	
	# Visual Effects commands are now in VFX_Commands.gd
	
	# User commands
	register_command("status", _cmd_status, "Shows current game status", true)
	register_command("tasks", _cmd_tasks, "Lists current active tasks", false)
	register_command("tension", _cmd_tension, "Show or modify global tension", true)
	register_command("event_list", _cmd_event_list, "List all events with tension info", true)
	register_command("trigger_event", _cmd_trigger_event, "Triggers a game event by ID", true)

	register_command("reboot", _cmd_reboot, "Reboots Station systems", false)
	register_command("diag", _cmd_diagnostics, "Runs Diagnostics on the system", false)
	register_command("test_ending", _cmd_test_ending, "Tests the ending sequence for the game", true)

func _cmd_set_day(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: set_day <day_number>")
		output("Current day: %d" % GameManager.current_day)
		return
	
	var target_day = args[0].to_int()
	
	if target_day < 1:
		output_error("Day must be 1 or greater")
		return
	
	if not GameManager:
		output_error("GameManager not available")
		return
	
	var old_day = GameManager.current_day
	GameManager.current_day = target_day
	
	output_system("Day changed: %d -> %d" % [old_day, target_day])
	
	# Optionally trigger day start logic
	if args.size() > 1 and args[1] == "start":
		GameManager.start_new_day()
		output("New day sequence initiated")
	else:
		output("Use 'set_day %d start' to also trigger day start sequence" % target_day)
	
	DebugLogger.debug(module_name, "Day forcibly changed from %d to %d" % [old_day, target_day])

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

func _cmd_fail_task(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: fail_task <task_id>")
		output("Available fatal tasks: restore_power, replace_heatsink")
		return
	
	var task_id = args[0]
	
	if not GameManager.task_manager:
		output_error("Task manager not available")
		return
	
	output_system("=== Force Failing Task: %s ===" % task_id)
	
	# Check if this is a fatal emergency task
	var fatal_tasks = ["restore_power", "replace_heatsink"]
	if task_id in fatal_tasks:
		output_warning("FATAL: This will trigger death cutscene!")
	
	# Emit the emergency task failed signal
	if GameManager.task_manager.has_signal("emergency_task_failed"):
		GameManager.task_manager.emergency_task_failed.emit(task_id)
		output("✓ Emergency task failure signal emitted")
	else:
		output_error("Emergency task failed signal not found on TaskManager")
		return
	
	# Also mark the task as failed if it exists
	var task = GameManager.task_manager.get_task(task_id)
	if task:
		if task.has_method("fail"):
			task.fail()
			output("✓ Task marked as failed")
		else:
			output_warning("Task doesn't have fail() method")
		output("Task Name: %s" % task.task_name)
	else:
		output_warning("Task '%s' not found in task system" % task_id)
		output("Signal was still emitted for testing purposes")
	
	# Show what should happen
	match task_id:
		"restore_power":
			output("")
			output_system("Expected Death Animation:")
			output("1. Creaking sound plays")
			output("2. Station model swaps to shattered")
			output("3. Small impulse applied to pieces")
			output("4. Pieces fall toward black hole")
			output("5. Transition to main menu after 5 seconds")
		"replace_heatsink":
			output("")
			output_system("Expected Death Animation:")
			output("1. Explosion sound plays")
			output("2. Explosion VFX triggers")
			output("3. Station model swaps to shattered")
			output("4. Large impulse applied to pieces")
			output("5. Pieces fall toward black hole")
			output("6. Transition to main menu after 5 seconds")
		_:
			output("")
			output_warning("Non-fatal task - check for other consequences")

func _cmd_complete_task(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: complete_task <task_id>")
		return
	
	var task_id = args[0]
	GameManager.task_manager.complete_task(task_id)
	output_system("Task '%s' force completed" % task_id)

func _cmd_next_day(args: Array) -> void:
	if GameManager.time_manager:
		GameManager.time_manager.start_next_day()
		output_system("Started next day")
	else:
		output_error("Time manager not available")

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

func _cmd_tension(args: Array) -> void:
	## Show or modify global tension
	if not GameManager.event_manager:
		output_error("Event manager not available")
		return
	
	if args.is_empty():
		# Show current tension info
		var info = GameManager.event_manager.get_tension_info()
		output_system("=== Global Tension System ===")
		output("Current Tension: %.1f/100" % info.global_tension)
		output("Decay Rate: %.1f/sec" % info.tension_decay_rate)
		output("Grace Period: %s" % ("ACTIVE" if info.grace_period_active else "Inactive"))
		output("")
		output("Active Cooldowns:")
		output("  Visual: %d" % info.cooldowns.visual)
		output("  Audio: %d" % info.cooldowns.audio)
		output("  Gameplay: %d" % info.cooldowns.gameplay)
		output("")
		output("Relationship Boosts: %d active" % info.active_boosts)
		
		DebugLogger.debug(module_name, "Displayed tension info")
		return
	
	# Modify tension
	var action = args[0].to_lower()
	match action:
		"set":
			if args.size() < 2:
				output_error("Usage: tension set <value>")
				return
			var value = float(args[1])
			GameManager.event_manager.global_tension = clamp(value, 0.0, 100.0)
			output("Set tension to %.1f" % GameManager.event_manager.global_tension)
			
		"add":
			if args.size() < 2:
				output_error("Usage: tension add <value>")
				return
			var value = float(args[1])
			var old_tension = GameManager.event_manager.global_tension
			GameManager.event_manager.global_tension = clamp(old_tension + value, 0.0, 100.0)
			output("Tension: %.1f -> %.1f" % [old_tension, GameManager.event_manager.global_tension])
			
		"reset":
			GameManager.event_manager.global_tension = 0.0
			output("Reset tension to 0")
			
		_:
			output_error("Unknown action: %s" % action)
			output("Usage: tension [set|add|reset] <value>")

func _cmd_event_list(args: Array) -> void:
	## Lists all registered events with their tension costs
	if not GameManager.event_manager:
		output_error("Event manager not available")
		return
	
	# Get events from the event_resources array
	var events = GameManager.event_manager.event_resources
	
	if events.is_empty():
		output_system("No events registered")
		return
	
	output_system("=== Registered Events ===")
	output("%-20s | %-30s | %8s | %6s | %8s | %4s" % ["ID", "Name", "Cost", "Day", "Cooldown", "Disr"])
	output("-".repeat(80))
	
	# Sort events by ID for better readability
	var sorted_events = events.duplicate()
	sorted_events.sort_custom(func(a, b): return a.id < b.id)
	
	for event in sorted_events:
		var event_id = event.id if event.id else "unknown"
		var event_name = event.name if event.name else "Unnamed Event"
		var base_cost = str(event.cost)
		var min_day = str(event.min_day)
		var cooldown = "%.1fs" % event.cooldown
		var disruption = "%d%%" % event.disruption_percentage
		
		# Check if event is currently active
		var active = " [ACTIVE]" if GameManager.event_manager.is_event_active(event_id) else ""
		
		output("%-20s | %-30s | %8s | %6s | %8s | %4s%s" % [
			event_id.substr(0, 20), 
			event_name.substr(0, 30), 
			base_cost, 
			min_day, 
			cooldown, 
			disruption,
			active
		])
	
	output("-".repeat(80))
	output("Total events: %d" % events.size())
	
	# Show current system state
	var debug_info = GameManager.event_manager.get_debug_info()
	output("")
	output("Current Points: %.1f" % debug_info.points)
	output("Current Disruption: %d%%" % debug_info.disruption)
	output("Active Events: %d" % debug_info.active_events.size())
	output("Next Evaluation: %.1fs" % debug_info.next_evaluation)
	
	# Log to debug
	DebugLogger.debug(module_name, "Listed %d events" % events.size())

func _cmd_trigger_event(args: Array) -> void:
	## Forcibly triggers an event by ID, bypassing all checks
	if args.is_empty():
		output_error("Usage: trigger_event <event_id>")
		return
	
	if not GameManager.event_manager:
		output_error("Event manager not available")
		return
	
	var event_id = args[0]
	
	# Log the attempt
	DebugLogger.debug(module_name, "Attempting to trigger event: %s" % event_id)
	
	# Check if event exists in resources
	var event_found = false
	var event_data = null
	
	for event in GameManager.event_manager.event_resources:
		if event.id == event_id:
			event_found = true
			event_data = event
			break
	
	if not event_found:
		output_error("Event '%s' not found" % event_id)
		output("Use 'event_list' to see available events")
		return
	
	# Check if already active
	if GameManager.event_manager.is_event_active(event_id):
		output_warning("Event '%s' is already active" % event_id)
		return
	
	# Display event info
	output_system("Force triggering event: %s" % event_id)
	output("Event Name: %s" % event_data.name)
	output("Base Cost: %d" % event_data.cost)
	output("Disruption: %d%%" % event_data.disruption_percentage)
	output("Min Day: %d" % event_data.min_day)
	
	# Use the trigger_event method which bypasses cost
	GameManager.event_manager.trigger_event(event_id)
	
	# Check if it actually triggered
	if GameManager.event_manager.is_event_active(event_id):
		output_system("Event '%s' triggered successfully" % event_id)
		DebugLogger.debug(module_name, "Successfully triggered event: %s" % event_id)
	else:
		output_error("Failed to trigger event '%s'" % event_id)
		output("The event may have failed its execution check or no handler exists")
		DebugLogger.debug(module_name, "Failed to trigger event: %s" % event_id)

func _cmd_reboot(args: Array) -> void:
	var effects_manager : EffectsManager = get_tree().get_first_node_in_group("effects_manager")
	DevConsoleManager.rebooted.emit()
	if effects_manager: 
		effects_manager.kill_power(5.0)
		output_system("Reboot issued successfully")
	else: 
		output_system("Reboot has failed")

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
	var effects_manager : EffectsManager = get_tree().get_first_node_in_group("effects_manager")
	if effects_manager: 
		effects_manager.trigger_light_pulse()
	DevConsoleManager.diag_run.emit()

func _cmd_unlock_log(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: unlock_log <number>")
		return
	
	var log_number = args[0].to_int()
	
	if log_number < 1 or log_number > DevConsoleManager.terminal_logs.size():
		output_error("Invalid log number")
		return
	
	# Since we're now using day-based locking, this command will just set the day
	# to whatever is needed to unlock that log
	var required_day = _get_required_day_for_log(log_number)
	
	if log_number == 11:
		output_warning("Log 11 is password protected. Use: log 11 iconoclast")
		return
	
	if GameManager.current_day < required_day:
		var old_day = GameManager.current_day
		GameManager.current_day = required_day
		if GameManager.time_manager:
			GameManager.time_manager.current_day = required_day
		output_system("Advanced to Day %d to unlock log %d" % [required_day, log_number])
		DebugLogger.debug(module_name, "Day changed from %d to %d to unlock log %d" % [old_day, required_day, log_number])
	else:
		output("Log %d is already unlocked (current day: %d)" % [log_number, GameManager.current_day])

func _get_required_day_for_log(log_number: int) -> int:
	# Same logic as in LogCommands
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
		return 1  # Password protected logs

func _cmd_test_ending(args: Array) -> void:
	## Test ending sequence by jumping to final day and triggering collapse
	if not GameManager or not GameManager.task_manager:
		output_error("Required managers not available")
		return
	
	output_system("=== Testing Ending Sequence ===")
	
	# Jump directly to day 5
	var final_day = 5
	output("Jumping to day %d..." % final_day)
	GameManager.current_day = final_day
	
	# Clear all existing tasks
	# Clear all existing tasks
	output("Clearing all tasks...")
	# Use the proper methods to get and clear tasks
	var todays_tasks = GameManager.task_manager.get_todays_tasks()
	var active_tasks = GameManager.task_manager.get_active_tasks()
		
	# Set ending_triggered flag to simulate conditions being met
	GameManager.ending_triggered = true
	
	# Set reality collapse state
	if GameManager.state_manager:
		GameManager.state_manager.set_state("reality_collapse", true)
		output("Reality collapse state activated")
	
	output("Waiting 1 second before triggering collapse_inevitable...")
	await get_tree().create_timer(1.0).timeout
	
	# Trigger the collapse emergency task
	output("Triggering collapse_inevitable emergency task...")
	if GameManager.task_manager:
		GameManager.task_manager.trigger_emergency_task(GameManager.collapse_task_id)
		output("Emergency task '%s' triggered" % GameManager.collapse_task_id)
		output("Task will fail in 20 seconds, triggering ending cutscene")
	
	output_system("=== Ending Test Active ===")
	output("The collapse_inevitable task is now running.")
	output("Wait 20 seconds for it to fail and trigger the ending.")
	output("")
	output("Or use 'fail_task collapse_inevitable' to trigger immediately.")

func _complete_secret_path(path: String) -> void:
	## Helper to complete all tasks in a secret path
	var task_ids = []
	
	match path:
		"a":
			task_ids = ["secret_a_1", "secret_a_2", "secret_a_3"]
		"b":
			task_ids = ["secret_b_1", "secret_b_2", "secret_b_3"]
	
	for task_id in task_ids:
		# First, make sure the task is revealed by setting any required states
		var task = _find_task_by_id(task_id)
		if task:
			# Force reveal the task
			task.is_revealed = true
			GameManager.task_manager.todays_tasks.append(task)
			
			# Complete it
			GameManager.task_manager.complete_task(task_id)
			output("  ✓ Secret: " + task.task_name)
		else:
			output_warning("  ✗ Secret task not found: " + task_id)

func _find_task_by_id(task_id: String) -> BaseTask:
	## Find a task in all available pools
	# Check current day config
	if GameManager.task_manager.current_day_config:
		for task in GameManager.task_manager.current_day_config.available_tasks:
			if task.task_id == task_id:
				return task
	
	# Check active tasks
	var active_tasks = GameManager.task_manager.get_active_tasks()
	for task in active_tasks:
		if task.task_id == task_id:
			return task
	
	# Check today's tasks
	var todays_tasks = GameManager.task_manager.get_todays_tasks()
	for task in todays_tasks:
		if task.task_id == task_id:
			return task
			
	return null
