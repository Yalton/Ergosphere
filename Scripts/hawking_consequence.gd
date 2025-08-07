# HawkingConsequence.gd
extends Node
class_name HawkingConsequence

## Handles the consequences of failing the hawking radiation task

## Particle effect 1 to enable when hawking radiation hits
@export var particle_effect_1: GPUParticles3D
## Particle effect 2 to enable when hawking radiation hits  
@export var particle_effect_2: GPUParticles3D
## Audio player for hawking radiation effect sound
@export var audio_player: AudioStreamPlayer3D
## Duration in seconds to apply the hawking effect
@export var effect_duration: float = 4.5
## Fade duration for audio when stopping
@export var audio_fade_duration: float = 1.0

var player: Node3D
var effect_timer: Timer
var fade_tween: Tween

func _ready() -> void:
	DebugLogger.register_module("HawkingConsequence")
	
	# Connect to task manager's task failed signal
	if GameManager.task_manager:
		GameManager.task_manager.emergency_task_failed.connect(_on_task_failed)
		DebugLogger.log_message("HawkingConsequence", "Connected to task manager emergency_task_failed signal")
	else:
		DebugLogger.log_message("HawkingConsequence", "TaskManager not found")
	
	# Create effect timer
	effect_timer = Timer.new()
	effect_timer.one_shot = true
	effect_timer.timeout.connect(_stop_effects)
	add_child(effect_timer)

func _on_task_failed(task_id: String) -> void:
	DebugLogger.log_message("HawkingConsequence", "Task failed: " + task_id)
	
	if task_id == "hawking_radiation":
		_apply_hawking_consequences()

func _apply_hawking_consequences() -> void:
	DebugLogger.log_message("HawkingConsequence", "Applying hawking radiation consequences")
	
	# Get player reference
	player = CommonUtils.get_player()
	if not player:
		DebugLogger.log_message("HawkingConsequence", "Player not found")
		return
	
	# Enable particle effects
	if particle_effect_1:
		particle_effect_1.emitting = true
		DebugLogger.log_message("HawkingConsequence", "Enabled particle effect 1")
	
	if particle_effect_2:
		particle_effect_2.emitting = true
		DebugLogger.log_message("HawkingConsequence", "Enabled particle effect 2")
	
	# Play audio
	if audio_player:
		audio_player.play()
		DebugLogger.log_message("HawkingConsequence", "Started audio playback")
	
	# Apply movement slow to player
	if player.has_method("apply_hawking_movement"):
		player.apply_hawking_movement(true)
		DebugLogger.log_message("HawkingConsequence", "Applied movement slow to player")
	
	# Start timer to stop effects
	effect_timer.start(effect_duration)
	DebugLogger.log_message("HawkingConsequence", "Started effect timer for " + str(effect_duration) + " seconds")

func _stop_effects() -> void:
	DebugLogger.log_message("HawkingConsequence", "Stopping hawking radiation effects")
	
	# Disable particle effects
	if particle_effect_1:
		particle_effect_1.emitting = false
		DebugLogger.log_message("HawkingConsequence", "Disabled particle effect 1")
	
	if particle_effect_2:
		particle_effect_2.emitting = false
		DebugLogger.log_message("HawkingConsequence", "Disabled particle effect 2")
	
	# Remove movement slow from player
	if player and player.has_method("apply_hawking_movement"):
		player.apply_hawking_movement(false)
		DebugLogger.log_message("HawkingConsequence", "Removed movement slow from player")
	
	# Fade out audio
	if audio_player and audio_player.playing:
		_fade_out_audio()

func _fade_out_audio() -> void:
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(audio_player, "volume_db", -80.0, audio_fade_duration)
	fade_tween.tween_callback(func(): 
		audio_player.stop()
		audio_player.volume_db = 0.0
		DebugLogger.log_message("HawkingConsequence", "Audio faded out and stopped")
	)
