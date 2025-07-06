# GameCommands.gd
extends BaseCommandHandler

## Handles game-specific commands like events, tasks, tension, diagnostics
func _ready() -> void:
	handler_name = "GameCommands"
	super._ready()

func register_commands() -> void:
	# Admin commands
	register_command("trigger_event", _cmd_trigger_event, "Triggers a game event by ID", true)
	register_command("assign_task", _cmd_assign_task, "Assigns a task by ID", true)
	register_command("complete_task", _cmd_complete_task, "Force completes a task by ID", true)
	register_command("next_day", _cmd_next_day, "Instantly starts the next day", true)
	register_command("no_clip", _cmd_noclip, "Exactly what it sounds like", true)
	register_command("complete_all_daily", _cmd_complete_all_daily, "Completes all active daily tasks", true)
	register_command("force_event", _cmd_force_event, "Force trigger an event", true)
	register_command("unlock_log", _cmd_unlock_log, "Unlocks a specific log", true)
	
	# Visual Effects commands
	register_command("vfx", _cmd_vfx, "Test visual effects (usage: vfx <effect_id> [startup] [duration] [winddown])", true)
	register_command("vfx_glitch", _cmd_vfx_glitch, "Quick glitch effect test", true)
	register_command("vfx_mind", _cmd_vfx_mind, "Test mind break effect", true)
	register_command("vfx_stop", _cmd_vfx_stop, "Stop all visual effects", true)
	register_command("vfx_list", _cmd_vfx_list, "List all available visual effects", true)
	register_alias("fx", "vfx")
	
	# User commands
	register_command("status", _cmd_status, "Shows current game status", false)
	register_command("tasks", _cmd_tasks, "Lists current active tasks", false)
	register_command("tension", _cmd_tension, "Show or modify global tension", false)
	register_command("event_list", _cmd_event_list, "List all events with tension info", false)
	register_command("reboot", _cmd_reboot, "Reboots Station systems", false)
	register_command("diag", _cmd_diagnostics, "Runs Diagnostics on the system", false)
	register_command("test_ending", _cmd_test_ending, "Tests the ending sequence for the game", false)


func _cmd_trigger_event(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: trigger_event <event_id>")
		return
	
	var event_id = args[0]
	GameManager.event_manager.force_trigger_event(event_id)
	output_system("Triggered event: " + event_id)

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

func _cmd_force_event(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: force_event <event_id>")
		return
		
	if not GameManager.event_manager:
		output_error("Event manager not available")
		return
		
	var event_id = args[0]
	
	# Check if event exists
	var found = false
	for event in GameManager.event_manager.available_events:
		if event.event_id == event_id:
			found = true
			break
			
	if not found:
		output_error("Event not found: %s" % event_id)
		return
		
	GameManager.event_manager.force_trigger_event(event_id)
	output("Force triggered event: %s" % event_id)
	
	# Show updated tension
	var tension = GameManager.event_manager.global_tension
	output("Global tension now: %.1f" % tension)

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
	## List all events with tension information
	if not GameManager.event_manager:
		output_error("Event manager not available")
		return
		
	var events = GameManager.event_manager.available_events
	if events.is_empty():
		output("No events configured")
		return
	
	output_system("=== Configured Events ===")
	output("Format: [ID] Name (Category) - T:tension D:disruption +Tension:gain Chance:base%")
	output("")
	
	for event in events:
		var tension_gain = event.get_tension_contribution()
		var categories = []
		if event.has_visual_effects:
			categories.append("V")
		if event.has_audio:
			categories.append("A")
		if event.disruption_score > 0:
			categories.append("G")
		var cat_str = "[%s]" % "".join(categories) if not categories.is_empty() else ""
		
		var line = "[%s] %s (%s) - T:%d D:%d +Tension:%.0f Chance:%.1f%% %s" % [
			event.event_id,
			event.event_name if not event.event_name.is_empty() else "Unnamed",
			event.get_category_description(),
			event.tension_score,
			event.disruption_score,
			tension_gain,
			event.base_chance,
			cat_str
		]
		
		output(line)
		
		# Show relationships if any
		if not event.boosts_events.is_empty():
			var boosts = []
			for related_id in event.boosts_events:
				boosts.append("%s(x%.1f)" % [related_id, event.boosts_events[related_id]])
			output("    Boosts: %s" % ", ".join(boosts))
	
	# Show current cooldowns by category
	output("")
	output_system("--- Active Cooldowns by Category ---")
	var cooldowns = GameManager.event_manager.cooldown_categories
	
	for category in ["visual", "audio", "gameplay"]:
		if cooldowns[category].is_empty():
			output("%s: None" % category.capitalize())
		else:
			var items = []
			for key in cooldowns[category]:
				items.append("%s(%.1fs)" % [key, cooldowns[category][key]])
			output("%s: %s" % [category.capitalize(), ", ".join(items)])
	
	DebugLogger.debug(module_name, "Listed events with tension info")

func _cmd_reboot(args: Array) -> void:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
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
	DevConsoleManager.diag_run.emit()

func _cmd_unlock_log(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: unlock_log <number>")
		return
	
	var log_number = args[0].to_int()
	
	if log_number < 1 or log_number > DevConsoleManager.terminal_logs.size():
		output_error("Invalid log number")
		return
	
	var log_data = DevConsoleManager.terminal_logs[log_number - 1]
	
	if not log_data:
		output_error("Log data is missing")
		return
	
	if not log_data.is_locked:
		output_warning("Log is not locked")
		return

	# Force unlock by setting the required state
	if not log_data.unlock_state_name.is_empty() and GameManager.state_manager:
		GameManager.state_manager.set_state(log_data.unlock_state_name, log_data.unlock_state_value)
		output_system("Log '%s' unlocked by setting %s to %s" % [log_data.log_title, log_data.unlock_state_name, str(log_data.unlock_state_value)])
	else:
		log_data.is_locked = false
		output_system("Log '%s' force unlocked" % log_data.log_title)


# Add this to your game_commands.gd file in the _ready() function with other commands:
# register_command("test_ending", _cmd_test_ending, "Skip to final day and complete all tasks for ending test")

func _cmd_test_ending(args: Array) -> void:
	## Test ending sequence by jumping to final day and completing tasks
	if not GameManager or not GameManager.task_manager or not GameManager.ending_sequence_manager:
		output_error("Required managers not available")
		return
	
	# Parse arguments
	var complete_path_a = false
	var complete_path_b = false
	var skip_delay = false
	
	for arg in args:
		match arg.to_lower():
			"a":
				complete_path_a = true
			"b": 
				complete_path_b = true
			"both":
				complete_path_a = true
				complete_path_b = true
			"nodelay":
				skip_delay = true
			_:
				output_warning("Unknown argument: " + arg)
	
	output_system("=== Testing Ending Sequence ===")
	
	# Get final day from EndingSequenceManager
	var final_day = GameManager.ending_sequence_manager.final_day
	output("Target day: %d" % final_day)
	
	# Skip to day before final day
	while GameManager.current_day < final_day - 1:
		GameManager.current_day += 1
		output("Skipping to day %d..." % GameManager.current_day)
	
	# Start the final day
	output("Starting final day %d..." % final_day)
	GameManager.start_new_day()
	
	# Wait a moment for day to initialize
	await get_tree().create_timer(0.5).timeout
	
	# Complete secret tasks if requested
	if complete_path_a:
		output("Completing secret path A tasks...")
		_complete_secret_path("a")
	
	if complete_path_b:
		output("Completing secret path B tasks...")
		_complete_secret_path("b")
	
	# Complete all regular daily tasks
	output("Completing all daily tasks...")
	var todays_tasks = GameManager.task_manager.get_todays_tasks()
	var completed_count = 0
	
	for task in todays_tasks:
		# Skip sleep task and secrets
		if task.task_id == GameManager.task_manager.sleep_task_id or task.is_secret:
			continue
			
		if not task.is_completed:
			GameManager.task_manager.complete_task(task.task_id)
			completed_count += 1
			output("  ✓ " + task.task_name)
	
	output("Completed %d daily tasks" % completed_count)
	
	# Optionally skip the delay
	if skip_delay:
		output("Skipping sequence delay...")
		GameManager.ending_sequence_manager.sequence_delay = 0.1
	
	output_system("=== Ending Test Setup Complete ===")
	output("Available endings: %s" % str(GameManager.ending_sequence_manager.get_available_endings()))
	output("Ending sequence will start in %.1f seconds..." % GameManager.ending_sequence_manager.sequence_delay)
	
	# Show usage hint
	output("")
	output_system("Usage: test_ending [options]")
	output("  a       - Complete secret path A")
	output("  b       - Complete secret path B") 
	output("  both    - Complete both secret paths")
	output("  nodelay - Skip the 5 second delay")
	output("")
	output("Example: test_ending both nodelay")

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
	
	# Check default tasks
	for task in GameManager.task_manager.default_available_tasks:
		if task.task_id == task_id:
			return task
			
	return null
	
# Visual Effects command implementations
func _cmd_vfx(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: vfx <effect_id> [startup] [duration] [winddown]")
		output("Available effects: blink, warp, glitch, edge_detection, chromatic_aberration, mind_break")
		return
	
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No visual effects manager found in scene")
		return
	
	# Parse arguments
	var effect_id = args[0]
	var startup = 0.5 if args.size() < 2 else float(args[1])
	var duration = 2.0 if args.size() < 3 else float(args[2])
	var winddown = 0.5 if args.size() < 4 else float(args[3])
	
	# Invoke effect
	output_system("Triggering effect: %s (startup: %f, duration: %f, winddown: %f)" % [effect_id, startup, duration, winddown])
	vfx_manager.invoke_effect(effect_id, startup, duration, winddown)

func _cmd_vfx_glitch(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No visual effects manager found")
		return
	
	output_system("Testing glitch effect...")
	vfx_manager.invoke_effect("glitch", 0.2, 1.0, 0.2)

func _cmd_vfx_mind(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No visual effects manager found")
		return
	
	output_system("Testing mind break effect...")
	vfx_manager.invoke_effect("mind_break", 1.0, 5.0, 1.0)

func _cmd_vfx_stop(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No visual effects manager found")
		return
	
	vfx_manager.stop_all_effects()
	output_system("All visual effects stopped")

func _cmd_vfx_list(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No visual effects manager found")
		return
	
	output_system("=== Available Visual Effects ===")
	
	# Get all effect handlers
	var effects = []
	for child in vfx_manager.get_children():
		if child is BaseVisualEffect:
			var effect_info = {
				"id": child.effect_id,
				"name": child.effect_name,
				"compositor_index": child.compositor_index,
				"use_blink": child.use_blink_transition
			}
			effects.append(effect_info)
	
	if effects.is_empty():
		output("No effects found. Make sure effect handlers are children of VisualEffectsManager")
	else:
		for effect in effects:
			var active = " [ACTIVE]" if vfx_manager.is_effect_active(effect.id) else ""
			var compositor = " (Compositor: %d)" % effect.compositor_index if effect.compositor_index >= 0 else " (ColorRect)"
			var blink = " +Blink" if effect.use_blink else ""
			output("- %s (%s)%s%s%s" % [effect.id, effect.name, compositor, blink, active])
	
	# Show active effects count
	var active_effects = vfx_manager.get_active_effects()
	output_system("\nActive effects: %d" % active_effects.size())
	
	# Show usage examples
	output_system("\nExamples:")
	output("  vfx blink 0.1 0.05 0.1     # Quick blink")
	output("  vfx glitch                 # Default glitch (0.5s/2s/0.5s)")
	output("  vfx mind_break 1 5 1       # 5-second mind break")
	output("  vfx_stop                   # Stop all effects")
