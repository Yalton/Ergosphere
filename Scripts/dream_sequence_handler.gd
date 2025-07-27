# DreamSequenceEventHandler.gd
extends Node
class_name DreamSequenceEventHandler

signal dream_sequence_started()
signal dream_sequence_finished()

## Control node to show during dream sequence (should be in main game scene)
@export var dream_sequence_control: Control

## Audio stream player for dream audio
@export var dream_audio_player: AudioStreamPlayer

## Duration to show the dream sequence
@export var dream_display_duration: float = 5.0

## Enable debug logging
@export var enable_debug: bool = true

var module_name: String = "DreamSequenceEventHandler"
var is_processing_dream: bool = false

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Add to group for easy access
	add_to_group("dream_sequence_handler")
	
	# Ensure dream sequence control is hidden
	if dream_sequence_control:
		dream_sequence_control.hide()

func should_trigger_dream_sequence() -> bool:
	# Check if we're on day 2
	return GameManager.get_current_day() == 2 and not is_processing_dream

func trigger_dream_sequence(player_interaction: PlayerInteractionComponent) -> void:
	if is_processing_dream:
		DebugLogger.warning(module_name, "Dream sequence already in progress")
		return
		
	is_processing_dream = true
	DebugLogger.info(module_name, "Starting day 2 dream sequence")
	
	dream_sequence_started.emit()
	
	# Start the sequence
	await _run_dream_sequence(player_interaction)
	
	is_processing_dream = false
	dream_sequence_finished.emit()
	DebugLogger.info(module_name, "Dream sequence completed")

func _run_dream_sequence(player_interaction: PlayerInteractionComponent) -> void:
	var transition_manager = GameManager.transition_manager
	
	# Phase 1: Fade to black
	DebugLogger.debug(module_name, "Phase 1: Fading to black")
	await transition_manager.fade_to_black()
	
	# Phase 2: Show player stats screen
	DebugLogger.debug(module_name, "Phase 2: Showing player stats")
	if player_interaction.sleep_stats_screen:
		player_interaction.sleep_stats_screen.show_sleep_stats()
		# Wait for stats screen to be dismissed
		await player_interaction.sleep_stats_screen.stats_screen_closed
	else:
		DebugLogger.warning(module_name, "No sleep stats screen found, skipping stats phase")
		# Just wait a moment
		await get_tree().create_timer(2.0).timeout
	
	# Phase 3: Fade to black again
	DebugLogger.debug(module_name, "Phase 3: Fading to black again")
	await transition_manager.fade_to_black()
	
	# Phase 4: Show dream sequence
	DebugLogger.debug(module_name, "Phase 4: Showing dream sequence")
	if dream_sequence_control:
		dream_sequence_control.show()
		
		# Play audio if available
		if dream_audio_player and dream_audio_player.stream:
			dream_audio_player.play()
			DebugLogger.debug(module_name, "Playing dream audio")
		
		# Fade back in to show the dream
		await transition_manager.fade_from_black()
		
		# Wait for display duration
		DebugLogger.debug(module_name, "Displaying dream for %f seconds" % dream_display_duration)
		await get_tree().create_timer(dream_display_duration).timeout
		
		# Fade to black before hiding
		await transition_manager.fade_to_black()
		
		# Hide dream sequence
		dream_sequence_control.hide()
		
		# Stop audio if still playing
		if dream_audio_player and dream_audio_player.playing:
			dream_audio_player.stop()
	else:
		DebugLogger.error(module_name, "No dream sequence control node assigned!")
		await get_tree().create_timer(1.0).timeout
	
	# Phase 5: Resume normal game
	DebugLogger.debug(module_name, "Phase 5: Resuming normal game")
	# The bed interactable will handle the final fade in and day transition
