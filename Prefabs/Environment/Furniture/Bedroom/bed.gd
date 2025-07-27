# bed.gd
extends AwareGameObject

signal sleep_initiated
signal dream_sequence_requested

@export_group("Bed Settings")
## Camera position when player is looking at the bed
@export var camera_position: Node3D
## Camera rotation when player is looking at the bed  
@export var camera_rotation: Vector3 = Vector3.ZERO
## Duration of camera transition to bed
@export var camera_transition_duration: float = 1.5
## Sleep sound effect
@export var sleep_sound: AudioStream

@export_group("Dream Sequence Settings")
## Control node to show during dream sequence (should be in main game scene)
@export var dream_sequence_control: Control
## Audio stream player for dream audio
@export var dream_audio_player: AudioStreamPlayer
## Duration to show the dream sequence
@export var dream_display_duration: float = 5.0

# Internal references
var current_player: Player = null
var current_player_interaction: PlayerInteractionComponent = null
var is_processing_dream: bool = false

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
	
	# Ensure dream sequence control is hidden
	if dream_sequence_control:
		dream_sequence_control.hide()
	
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
	
	# Notify GameManager that player is sleeping
	if GameManager:
		GameManager.player_sleeping.emit()
	
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
	
	# Check if we should show dream sequence (day 2)
	if _should_show_dream_sequence():
		await _run_dream_sequence()
	
	# Continue with sleep completion
	_finish_sleep_sequence()

func _should_show_dream_sequence() -> bool:
	# Show dream sequence on day 2 (which is actually the night after day 2)
	# Since we already incremented the day, we check if current day is 3
	var show_dream = GameManager and GameManager.current_day == 3 and not is_processing_dream
	
	# Also check if dream handler exists in the scene
	if show_dream:
		var has_handler = get_tree().get_first_node_in_group("dream_sequence_handler") != null
		if has_handler:
			DebugLogger.info(module_name, "Day 2 sleep detected, will show dream sequence")
		else:
			DebugLogger.debug(module_name, "Day 2 but no dream sequence handler found")
		return has_handler
	
	return false

func _run_dream_sequence() -> void:
	if is_processing_dream:
		DebugLogger.warning(module_name, "Dream sequence already in progress")
		return
		
	is_processing_dream = true
	DebugLogger.info(module_name, "Starting day 2 dream sequence")
	
	# Emit signal for any external handlers
	dream_sequence_requested.emit()
	
	# Phase 1: We're already faded to black from stats screen
	
	# Phase 2: Show dream sequence
	DebugLogger.debug(module_name, "Showing dream sequence")
	if dream_sequence_control:
		dream_sequence_control.show()
		
		# Play audio if available
		if dream_audio_player and dream_audio_player.stream:
			dream_audio_player.play()
			DebugLogger.debug(module_name, "Playing dream audio")
		
		# Fade back in to show the dream
		if TransitionManager:
			await TransitionManager.fade_from_black()
		else:
			await get_tree().create_timer(1.0).timeout
		
		# Wait for display duration
		DebugLogger.debug(module_name, "Displaying dream for %f seconds" % dream_display_duration)
		await get_tree().create_timer(dream_display_duration).timeout
		
		# Fade to black before hiding
		if TransitionManager:
			await TransitionManager.fade_to_black()
		else:
			await get_tree().create_timer(1.0).timeout
		
		# Hide dream sequence
		dream_sequence_control.hide()
		
		# Stop audio if still playing
		if dream_audio_player and dream_audio_player.playing:
			dream_audio_player.stop()
	else:
		DebugLogger.error(module_name, "No dream sequence control node assigned!")
		await get_tree().create_timer(1.0).timeout
	
	is_processing_dream = false
	DebugLogger.info(module_name, "Dream sequence completed")

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
