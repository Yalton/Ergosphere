# VFX_Commands.gd
extends BaseCommandHandler

func _ready() -> void:
	handler_name = "VFX_Commands"
	module_name = "VFX_Commands"
	# Register with debug logger
	DebugLogger.register_module(module_name, true)
	super._ready()

func register_commands() -> void:
	# Player Visual Effects commands
	register_command("pvfx", _cmd_player_vfx, "Test player visual effects (usage: pvfx <effect_id> [startup] [duration] [winddown])", true)
	register_command("pvfx_stop", _cmd_player_vfx_stop, "Stop player visual effects (usage: pvfx_stop [effect_id])", true)
	register_command("pvfx_list", _cmd_player_vfx_list, "List all available player visual effects", true)
	register_command("pvfx_glitch", _cmd_player_vfx_glitch, "Quick player glitch effect test", true)
	register_command("pvfx_mind", _cmd_player_vfx_mind, "Test player mind break effect", true)
	register_command("pvfx_status", _cmd_player_vfx_status, "Show active player effects", true)
	register_alias("pfx", "pvfx")
	
	# Global Visual Effects commands
	register_command("vfx", _cmd_vfx, "Test global visual effects (usage: vfx <effect_id> [startup] [duration] [winddown])", true)
	register_command("vfx_glitch", _cmd_vfx_glitch, "Quick global glitch effect test", true)
	register_command("vfx_mind", _cmd_vfx_mind, "Test global mind break effect", true)
	register_command("vfx_stop", _cmd_vfx_stop, "Stop all global visual effects", true)
	register_command("vfx_list", _cmd_vfx_list, "List all available global visual effects", true)
	register_command("vfx_status", _cmd_vfx_status, "Show active global effects", true)
	register_alias("fx", "vfx")
	
	# Combined commands
	register_command("vfx_stop_all", _cmd_stop_all_vfx, "Stop both player and global visual effects", true)
	register_command("vfx_test_suite", _cmd_vfx_test_suite, "Run through all available effects", true)

######################################
# Player VFX Commands
######################################

func _cmd_player_vfx(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: pvfx <effect_id> [startup] [duration] [winddown]")
		output("Available effects: blink, warp, glitch, edge_detection, chromatic_aberration, mind_break")
		output("Example: pvfx glitch 0.2 1.0 0.2")
		return
	
	# Get player reference using CommonUtils
	var player = CommonUtils.get_player()
	if not player:
		output_error("Player not found")
		return
	
	if not player.vfx_component:
		output_error("Player has no VFX component attached")
		output("Make sure PlayerVFXComponent is a child of the Player node")
		return
	
	# Parse arguments
	var effect_id = args[0]
	var startup = 0.5 if args.size() < 2 else float(args[1])
	var duration = 2.0 if args.size() < 3 else float(args[2])
	var winddown = 0.5 if args.size() < 4 else float(args[3])
	
	# Validate timing values
	if startup < 0 or duration < 0 or winddown < 0:
		output_error("Timing values must be positive")
		return
	
	# Invoke effect on player
	output_system("Triggering player effect: %s" % effect_id)
	output("  Startup: %.2fs | Duration: %.2fs | Winddown: %.2fs" % [startup, duration, winddown])
	player.trigger_player_vfx(effect_id, startup, duration, winddown)
	DebugLogger.debug(module_name, "Triggered player VFX: %s (%.1f/%.1f/%.1f)" % [effect_id, startup, duration, winddown])

func _cmd_player_vfx_stop(args: Array) -> void:
	var player = CommonUtils.get_player()
	if not player:
		output_error("Player not found")
		return
	
	if not player.vfx_component:
		output_error("Player has no VFX component attached")
		return
	
	if args.is_empty():
		player.stop_player_vfx()
		output_system("All player visual effects stopped")
		DebugLogger.debug(module_name, "Stopped all player VFX")
	else:
		var effect_id = args[0]
		player.stop_player_vfx(effect_id)
		output_system("Stopped player effect: %s" % effect_id)
		DebugLogger.debug(module_name, "Stopped player VFX: %s" % effect_id)

func _cmd_player_vfx_list(args: Array) -> void:
	var player = CommonUtils.get_player()
	if not player:
		output_error("Player not found")
		return
	
	if not player.vfx_component:
		output_error("Player has no VFX component attached")
		return
	
	output_system("=== Available Player Visual Effects ===")
	
	# Get all available effects from handlers
	var effects = []
	var active_count = 0
	
	# Check if there's a consolidated handler (CompositorVFXHandler)
	var has_compositor_handler = false
	
	for child in player.vfx_component.get_children():
		if child is CompositorVFXHandler:
			has_compositor_handler = true
			# Get all effects from the consolidated handler
			for effect_id in CompositorVFXHandler.EFFECT_CONFIG.keys():
				var config = CompositorVFXHandler.EFFECT_CONFIG[effect_id]
				var effect_info = {
					"id": effect_id,
					"name": config.name,
					"type": "Compositor",
					"active": player.vfx_component.is_effect_active(effect_id)
				}
				if effect_info.active:
					active_count += 1
				effects.append(effect_info)
		elif child.has_method("invoke_effect"):
			# Regular individual effect handler
			var effect_info = {
				"id": child.effect_id if "effect_id" in child else child.name,
				"name": child.effect_name if "effect_name" in child else child.name,
				"type": "Individual",
				"active": false
			}
			
			# Check if active
			if player.vfx_component.has_method("is_effect_active"):
				effect_info.active = player.vfx_component.is_effect_active(effect_info.id)
				if effect_info.active:
					active_count += 1
			
			effects.append(effect_info)
	
	if effects.is_empty():
		output("No effects found. Make sure effect handlers are children of PlayerVFXComponent")
	else:
		for effect in effects:
			var active = " [ACTIVE]" if effect.active else ""
			var type_info = " (%s)" % effect.type
			output("- %s: %s%s%s" % [effect.id, effect.name, type_info, active])
	
	output("")
	output("Total effects: %d | Active: %d" % [effects.size(), active_count])
	
	# Show usage examples
	output("")
	output_system("Quick tests:")
	output("  pvfx_glitch     # Test glitch effect")
	output("  pvfx_mind       # Test mind break effect")
	output("  pvfx_stop       # Stop all effects")

func _cmd_player_vfx_glitch(args: Array) -> void:
	var player = CommonUtils.get_player()
	if not player:
		output_error("Player not found")
		return
	
	if not player.vfx_component:
		output_error("Player has no VFX component attached")
		return
	
	output_system("Testing player glitch effect...")
	player.trigger_player_vfx("glitch", 0.2, 1.0, 0.2)
	DebugLogger.debug(module_name, "Quick test: player glitch")

func _cmd_player_vfx_mind(args: Array) -> void:
	var player = CommonUtils.get_player()
	if not player:
		output_error("Player not found")
		return
	
	if not player.vfx_component:
		output_error("Player has no VFX component attached")
		return
	
	output_system("Testing player mind break effect...")
	player.trigger_player_vfx("mind_break", 1.0, 5.0, 1.0)
	DebugLogger.debug(module_name, "Quick test: player mind break")

func _cmd_player_vfx_status(args: Array) -> void:
	var player = CommonUtils.get_player()
	if not player:
		output_error("Player not found")
		return
	
	if not player.vfx_component:
		output_error("Player has no VFX component attached")
		return
	
	output_system("=== Player VFX Status ===")
	
	var active_effects = []
	
	# Get active effects from the VFX component
	if player.vfx_component.has_method("get_active_effects"):
		active_effects = player.vfx_component.get_active_effects()
	
	if active_effects.is_empty():
		output("No active player effects")
	else:
		output("Active effects: %s" % ", ".join(active_effects))

######################################
# Global VFX Commands
######################################

func _cmd_vfx(args: Array) -> void:
	if args.is_empty():
		output_error("Usage: vfx <effect_id> [startup] [duration] [winddown]")
		output("Available effects: blink, warp, glitch, edge_detection, chromatic_aberration, mind_break")
		output("Example: vfx glitch 0.2 1.0 0.2")
		return
	
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No global visual effects manager found in scene")
		output("Make sure VisualEffectsManager is in the scene and in group 'visual_effects_manager'")
		return
	
	# Parse arguments
	var effect_id = args[0]
	var startup = 0.5 if args.size() < 2 else float(args[1])
	var duration = 2.0 if args.size() < 3 else float(args[2])
	var winddown = 0.5 if args.size() < 4 else float(args[3])
	
	# Validate timing values
	if startup < 0 or duration < 0 or winddown < 0:
		output_error("Timing values must be positive")
		return
	
	# Invoke effect
	output_system("Triggering global effect: %s" % effect_id)
	output("  Startup: %.2fs | Duration: %.2fs | Winddown: %.2fs" % [startup, duration, winddown])
	vfx_manager.invoke_effect(effect_id, startup, duration, winddown)
	DebugLogger.debug(module_name, "Triggered global VFX: %s (%.1f/%.1f/%.1f)" % [effect_id, startup, duration, winddown])

func _cmd_vfx_glitch(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No global visual effects manager found")
		return
	
	output_system("Testing global glitch effect...")
	vfx_manager.invoke_effect("glitch", 0.2, 1.0, 0.2)
	DebugLogger.debug(module_name, "Quick test: global glitch")

func _cmd_vfx_mind(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No global visual effects manager found")
		return
	
	output_system("Testing global mind break effect...")
	vfx_manager.invoke_effect("mind_break", 1.0, 5.0, 1.0)
	DebugLogger.debug(module_name, "Quick test: global mind break")

func _cmd_vfx_stop(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No global visual effects manager found")
		return
	
	vfx_manager.stop_all_effects()
	output_system("All global visual effects stopped")
	DebugLogger.debug(module_name, "Stopped all global VFX")

func _cmd_vfx_list(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No global visual effects manager found")
		return
	
	output_system("=== Available Global Visual Effects ===")
	
	# Get all available effects from handlers
	var effects = []
	var active_count = 0
	
	# Check if there's a consolidated handler (CompositorVFXHandler)
	var has_compositor_handler = false
	
	for child in vfx_manager.get_children():
		if child is CompositorVFXHandler:
			has_compositor_handler = true
			# Get all effects from the consolidated handler
			for effect_id in CompositorVFXHandler.EFFECT_CONFIG.keys():
				var config = CompositorVFXHandler.EFFECT_CONFIG[effect_id]
				var effect_info = {
					"id": effect_id,
					"name": config.name,
					"compositor_index": config.index,
					"active": vfx_manager.is_effect_active(effect_id)
				}
				if effect_info.active:
					active_count += 1
				effects.append(effect_info)
		elif child.has_method("invoke_effect"):
			# Regular individual effect handler
			var effect_info = {
				"id": child.effect_id if "effect_id" in child else child.name,
				"name": child.effect_name if "effect_name" in child else child.name,
				"compositor_index": child.compositor_index if "compositor_index" in child else -1,
				"use_blink": child.use_blink_transition if "use_blink_transition" in child else false,
				"active": false
			}
			
			# Check if active
			if vfx_manager.has_method("is_effect_active"):
				effect_info.active = vfx_manager.is_effect_active(effect_info.id)
				if effect_info.active:
					active_count += 1
			
			effects.append(effect_info)
	
	if effects.is_empty():
		output("No effects found. Make sure effect handlers are children of VisualEffectsManager")
	else:
		for effect in effects:
			var active = " [ACTIVE]" if effect.active else ""
			var compositor = " (Compositor: %d)" % effect.compositor_index if effect.compositor_index >= 0 else " (ColorRect)"
			var blink = " +Blink" if effect.get("use_blink", false) else ""
			output("- %s: %s%s%s%s" % [effect.id, effect.name, compositor, blink, active])
	
	output("")
	output("Total effects: %d | Active: %d" % [effects.size(), active_count])
	
	# Show usage examples
	output("")
	output_system("Quick tests:")
	output("  vfx_glitch     # Test glitch effect")
	output("  vfx_mind       # Test mind break effect")
	output("  vfx_stop       # Stop all effects")

func _cmd_vfx_status(args: Array) -> void:
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if not vfx_manager:
		output_error("No global visual effects manager found")
		return
	
	output_system("=== Global VFX Status ===")
	
	if vfx_manager.has_method("get_active_effects"):
		var active_effects = vfx_manager.get_active_effects()
		if active_effects.is_empty():
			output("No active global effects")
		else:
			output("Active effects: %d" % active_effects.size())
			for effect in active_effects:
				output("  - %s" % effect)
	else:
		output_warning("VFX Manager doesn't support status reporting")

######################################
# Combined Commands
######################################

func _cmd_stop_all_vfx(args: Array) -> void:
	output_system("Stopping all visual effects...")
	
	var stopped_player = false
	var stopped_global = false
	
	# Stop player effects using CommonUtils
	var player = CommonUtils.get_player()
	if player and player.vfx_component:
		player.stop_player_vfx()
		stopped_player = true
		output("  ✓ Player effects stopped")
	else:
		output("  ✗ No player VFX component found")
	
	# Stop global effects
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if vfx_manager:
		vfx_manager.stop_all_effects()
		stopped_global = true
		output("  ✓ Global effects stopped")
	else:
		output("  ✗ No global VFX manager found")
	
	if stopped_player or stopped_global:
		output_system("All available effects stopped")
		DebugLogger.debug(module_name, "Stopped all VFX systems")
	else:
		output_error("No VFX systems found")

func _cmd_vfx_test_suite(args: Array) -> void:
	output_system("=== VFX Test Suite ===")
	output("This will cycle through all effects. Press any key to continue...")
	
	# Get available effects
	var test_effects = ["blink", "glitch", "warp", "edge_detection", "chromatic_aberration", "mind_break"]
	var test_duration = 2.0
	var test_delay = 0.5
	
	# Parse optional duration argument
	if args.size() > 0:
		test_duration = float(args[0])
	
	output("Testing with %.1fs duration per effect" % test_duration)
	
	# Test on player using CommonUtils
	var player = CommonUtils.get_player()
	if player and player.vfx_component:
		output("")
		output_system("Testing Player Effects:")
		for effect_id in test_effects:
			output("  Testing: %s" % effect_id)
			player.trigger_player_vfx(effect_id, 0.2, test_duration, 0.2)
			await get_tree().create_timer(test_duration + test_delay).timeout
		output("  ✓ Player effects complete")
	
	# Test global
	var vfx_manager = get_tree().get_first_node_in_group("visual_effects_manager")
	if vfx_manager:
		output("")
		output_system("Testing Global Effects:")
		for effect_id in test_effects:
			output("  Testing: %s" % effect_id)
			vfx_manager.invoke_effect(effect_id, 0.2, test_duration, 0.2)
			await get_tree().create_timer(test_duration + test_delay).timeout
		output("  ✓ Global effects complete")
	
	output_system("Test suite complete!")
	DebugLogger.debug(module_name, "Completed VFX test suite")
