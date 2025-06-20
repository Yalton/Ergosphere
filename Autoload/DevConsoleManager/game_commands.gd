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
	# Add your task assignment logic here
	output_system("Assigned task: " + task_id)

func _cmd_complete_task(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: complete_task <task_id>")
		return
	
	var task_id = args[0]
	# Add your task completion logic here
	output_system("Completed task: " + task_id)

func _cmd_next_day(args: Array) -> void:
	# Add your next day logic here
	output_system("Starting next day...")

func _cmd_noclip(args: Array) -> void:
	# Add your noclip logic here
	output_system("NoClip toggled")

func _cmd_complete_all_daily(args: Array) -> void:
	# Add your complete all daily tasks logic here
	output_system("All daily tasks completed")

func _cmd_force_event(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: force_event <event_id>")
		return
	
	var event_id = args[0]
	GameManager.event_manager.force_trigger_event(event_id)
	output_system("Force triggered event: " + event_id)

func _cmd_status(args: Array) -> void:
	output_system("=== Game Status ===")
	# Add your status display logic here
	output("Day: [current_day]")
	output("Active Tasks: [task_count]")

func _cmd_tasks(args: Array) -> void:
	output_system("=== Active Tasks ===")
	# Add your task listing logic here
	output("No active tasks") # placeholder

func _cmd_tension(args: Array) -> void:
	if args.is_empty():
		# Show current tension
		output_system("Current tension: [tension_value]")
	else:
		# Set tension
		var new_tension = args[0].to_float()
		output_system("Tension set to: " + str(new_tension))

func _cmd_event_list(args: Array) -> void:
	output_system("=== Event List ===")
	# Add your event listing logic here
	output("No events available") # placeholder

func _cmd_reboot(args: Array) -> void:
	var effects_manager = get_tree().get_first_node_in_group("effects_manager")
	DevConsoleManager.rebooted.emit()
	if effects_manager: 
		effects_manager.kill_power(5.0)
		output_system("Reboot issued successfully")
	else: 
		output_system("Reboot has failed")

func _cmd_diagnostics(args: Array) -> void:
	DevConsoleManager.diag_run.emit()
	output_system("Running system diagnostics...")
	# Add your diagnostics logic here

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
