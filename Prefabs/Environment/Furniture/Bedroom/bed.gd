# bed.gd
extends AwareGameObject

signal sleep_initiated

@export_group("Bed Settings")
## Camera position when player is looking at the bed
@export var camera_position: Node3D
## Camera rotation when player is looking at the bed  
@export var camera_rotation: Vector3 = Vector3.ZERO
## Duration of camera transition to bed
@export var camera_transition_duration: float = 1.5
## Sleep sound effect
@export var sleep_sound: AudioStream

# Internal references
var current_player: Player = null
var current_player_interaction: PlayerInteractionComponent = null

func _ready() -> void:
	super._ready()
	module_name = "Bed"
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set display name if not already set
	if display_name.is_empty():
		display_name = "Bed"
	
	# Find task aware component
	task_aware_component = get_node_or_null("TaskAwareComponent")
	
	# Add to beds group for task system
	add_to_group("beds")
	
	# Set interaction text
	object_state_updated.emit("Sleep")
	
	DebugLogger.debug(module_name, "Bed initialized")

func interact(player_interaction: PlayerInteractionComponent) -> void:
	# Check if sleep task is available
	if task_aware_component: 
		task_aware_component.update_task_availability()
	if task_aware_component and not task_aware_component.is_task_available:
		DebugLogger.debug(module_name, "Sleep task not available")
		return
	
	DebugLogger.info(module_name, "Player initiating sleep")
	
	# Play sleep sound
	if sleep_sound:
		Audio.play_sound(sleep_sound)
	
	# Get player reference
	current_player = player_interaction.get_parent()
	current_player_interaction = player_interaction
	if not current_player:
		DebugLogger.error(module_name, "Could not find player")
		return
	
	# Move camera to bed view
	if camera_position:
		current_player.move_camera_to_position(
			camera_position.global_position,
			camera_position.rotation,
			camera_transition_duration
		)
	else:
		DebugLogger.warning(module_name, "No camera position set for bed")
	
	# Wait for camera transition
	await get_tree().create_timer(camera_transition_duration).timeout
	
	# Start the full sleep sequence
	_initiate_sleep_sequence()

func _initiate_sleep_sequence() -> void:
	DebugLogger.debug(module_name, "Starting sleep sequence")
	
	# Fade to black
	if TransitionManager:
		await TransitionManager.fade_to_black()
	else:
		DebugLogger.error(module_name, "TransitionManager not found")
		await get_tree().create_timer(1.0).timeout
	
	# Reset the day during black screen
	_reset_day()
	
	# Small delay to ensure reset is complete
	await get_tree().create_timer(0.5).timeout
	
	# Show stats screen if available
	if current_player_interaction.sleep_stats_screen:
		DebugLogger.debug(module_name, "Showing stats screen")
		
		# Connect to stats completion signal temporarily
		current_player_interaction.sleep_stats_screen.stats_complete.connect(_on_stats_complete, CONNECT_ONE_SHOT)
		
		# Tell stats screen to show current day stats
		var current_day = GameManager.current_day if GameManager else 1
		current_player_interaction.sleep_stats_screen.show_stats_for_day(current_day)
		
		# Wait for stats to complete
		await current_player_interaction.sleep_stats_screen.stats_complete
	else:
		DebugLogger.warning(module_name, "No stats screen assigned to player interaction component")
		await get_tree().create_timer(3.0).timeout
	
	# Continue with sleep completion
	_finish_sleep_sequence()

func _on_stats_complete() -> void:
	DebugLogger.debug(module_name, "Stats display completed")
	# This is handled by the await in _initiate_sleep_sequence

func _finish_sleep_sequence() -> void:
	DebugLogger.debug(module_name, "Finishing sleep sequence")
	
	# Reset player insanity (sleep restores mental health)
	if current_player:
		var insanity_comp = null
		for child in current_player.get_children():
			if child.has_method("reset_insanity"):
				insanity_comp = child
				break
		
		if insanity_comp:
			insanity_comp.reset_insanity()
			DebugLogger.debug(module_name, "Reset player insanity")
		
		# Restore camera position
		current_player.restore_camera_position(1.0)
		
		# Call player sleep method if it exists
		if current_player.has_method("sleep"):
			current_player.sleep()
	
	# Fade back from black
	if TransitionManager:
		await TransitionManager.fade_from_black()
	else:
		await get_tree().create_timer(1.0).timeout
	
	# Complete the sleep task
	if task_aware_component:
		task_aware_component.complete_task()
	
	# Emit sleep completion signal
	sleep_initiated.emit()
	
	# Clear references
	current_player = null
	current_player_interaction = null
	
	DebugLogger.info(module_name, "Sleep sequence completed")

func _reset_day() -> void:
	DebugLogger.debug(module_name, "Resetting day")
	if GameManager and GameManager.has_method("start_new_day"):
		GameManager.start_new_day()
	else:
		DebugLogger.error(module_name, "Cannot start new day - GameManager not available")
