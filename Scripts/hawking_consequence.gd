extends Node
class_name HawkingConsequence

## Handles the consequences of failing the hawking radiation task with smooth fade in/out

@export_group("Particle Effects")
## Particle effect 1 to enable when hawking radiation hits
@export var particle_effect_1: GPUParticles3D
## Particle effect 2 to enable when hawking radiation hits  
@export var particle_effect_2: GPUParticles3D

@export_group("Audio Settings")
## Audio player for hawking radiation effect sound
@export var audio_player: AudioStreamPlayer
## Fade in duration for audio when starting
@export var audio_fade_in_duration: float = 2.0
## Fade out duration for audio when stopping
@export var audio_fade_out_duration: float = 10.0

@export_group("Effect Timing")
## Duration in seconds to apply the hawking effect (actual radiation exposure)
@export var effect_duration: float = 4.5
## Delay before triggering visual effects after radiation starts
@export var vfx_delay: float = 3.0
## Delay after radiation stops before removing visual effects
@export var vfx_removal_delay: float = 5.0

@export_group("Movement Settings")
## Movement speed multiplier when affected (0.5 = half speed)
@export var movement_slow_factor: float = 0.3
## Fade in time for movement slow
@export var movement_fade_in: float = 2.0
## Fade out time for movement restoration
@export var movement_fade_out: float = 10.0

@export_group("Iconoclast Settings")
## Whether to spawn iconoclast avatar after radiation
@export var spawn_iconoclast: bool = true
## Delay after radiation ends before spawning iconoclast
@export var iconoclast_spawn_delay: float = 2.0

var player: Node3D
var effect_timer: Timer
var vfx_timer: Timer
var vfx_removal_timer: Timer
var iconoclast_timer: Timer
var fade_tween: Tween
var is_effect_active: bool = false
var vfx_active: bool = false

func _ready() -> void:
	DebugLogger.register_module("HawkingConsequence")
	
	# Connect to task manager's task failed signal
	if GameManager.task_manager:
		GameManager.task_manager.emergency_task_failed.connect(_on_task_failed)
		DebugLogger.log_message("HawkingConsequence", "Connected to task manager emergency_task_failed signal")
	else:
		DebugLogger.log_message("HawkingConsequence", "TaskManager not found")
	
	# Create timers
	effect_timer = Timer.new()
	effect_timer.one_shot = true
	effect_timer.timeout.connect(_stop_radiation_exposure)
	add_child(effect_timer)
	
	vfx_timer = Timer.new()
	vfx_timer.one_shot = true
	vfx_timer.timeout.connect(_apply_visual_effects)
	add_child(vfx_timer)
	
	vfx_removal_timer = Timer.new()
	vfx_removal_timer.one_shot = true
	vfx_removal_timer.timeout.connect(_remove_visual_effects)
	add_child(vfx_removal_timer)
	
	iconoclast_timer = Timer.new()
	iconoclast_timer.one_shot = true
	iconoclast_timer.timeout.connect(_spawn_iconoclast_avatar)
	add_child(iconoclast_timer)

func _on_task_failed(task_id: String) -> void:
	DebugLogger.log_message("HawkingConsequence", "Task failed: " + task_id)
	
	if task_id == "hawking_radiation":
		_apply_hawking_consequences()

func _apply_hawking_consequences() -> void:
	if is_effect_active:
		DebugLogger.log_message("HawkingConsequence", "Hawking effects already active")
		return
	
	is_effect_active = true
	DebugLogger.log_message("HawkingConsequence", "Applying hawking radiation consequences")
	
	# Get player reference
	player = CommonUtils.get_player()
	if not player:
		DebugLogger.log_message("HawkingConsequence", "Player not found")
		return
	
	# Start particle effects with smooth fade in
	_start_particle_effects()
	
	# Start audio with fade in
	_start_audio_with_fade()
	
	# Apply movement slow with smooth fade in
	_apply_movement_slow()
	
	# Send hint to player
	CommonUtils.send_player_hint("", "You should have closed the shutters...")
	
	# Start timer for main effect duration
	effect_timer.start(effect_duration)
	DebugLogger.log_message("HawkingConsequence", "Started effect timer for " + str(effect_duration) + " seconds")
	
	# Start timer for delayed visual effects
	vfx_timer.start(vfx_delay)
	DebugLogger.log_message("HawkingConsequence", "VFX will trigger in " + str(vfx_delay) + " seconds")

func _start_particle_effects() -> void:
	# Enable particle effects with emitting property
	if particle_effect_1:
		particle_effect_1.emitting = true
		particle_effect_1.restart()
		DebugLogger.log_message("HawkingConsequence", "Started particle effect 1")
	
	if particle_effect_2:
		particle_effect_2.emitting = true
		particle_effect_2.restart()
		DebugLogger.log_message("HawkingConsequence", "Started particle effect 2")

func _start_audio_with_fade() -> void:
	if not audio_player:
		return
	
	# Start from silent
	audio_player.volume_db = -80.0
	audio_player.play()
	
	# Fade in to normal volume
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(audio_player, "volume_db", 0.0, audio_fade_in_duration)
	DebugLogger.log_message("HawkingConsequence", "Started audio with fade in over " + str(audio_fade_in_duration) + " seconds")

func _apply_movement_slow() -> void:
	if not player:
		return
	
	# Use the player's new slow_player function
	player.slow_player(true, movement_slow_factor, movement_fade_in, movement_fade_out)
	DebugLogger.log_message("HawkingConsequence", "Applied movement slow with fade in")

func _apply_visual_effects() -> void:
	if not is_effect_active:
		return
	
	vfx_active = true
	DebugLogger.log_message("HawkingConsequence", "Applying visual effects")
	
	# Get player VFX component
	var vfx_component = player.get_node_or_null("PlayerVFXComponent")
	if not vfx_component:
		vfx_component = player.vfx_component if "vfx_component" in player else null
	
	if vfx_component and vfx_component.has_method("invoke_effect"):
		# First do a blink effect
		vfx_component.invoke_effect("blink", 0.3, 0.5, 0.3)
		
		# Start shape dilation during the blink (wait for blink to reach peak darkness)
		await get_tree().create_timer(0.5).timeout
		
		if is_effect_active and vfx_active:
			# Enable shape dilation for remaining duration
			vfx_component.invoke_effect("shape_dilation", 0.5, 999.0, 0.5)
			DebugLogger.log_message("HawkingConsequence", "Enabled shape dilation effect")
	else:
		DebugLogger.log_message("HawkingConsequence", "No VFX component found on player")

func _stop_radiation_exposure() -> void:
	DebugLogger.log_message("HawkingConsequence", "Stopping radiation exposure")
	
	# Stop particle emission (but let existing particles fade naturally)
	if particle_effect_1:
		particle_effect_1.emitting = false
		DebugLogger.log_message("HawkingConsequence", "Stopped particle effect 1 emission")
	
	if particle_effect_2:
		particle_effect_2.emitting = false
		DebugLogger.log_message("HawkingConsequence", "Stopped particle effect 2 emission")
	
	# Start fade out of movement slow
	_restore_movement_with_fade()
	
	# Start fade out of audio
	_fade_out_audio()
	
	# Start timer to remove visual effects after delay
	if vfx_active:
		vfx_removal_timer.start(vfx_removal_delay)
		DebugLogger.log_message("HawkingConsequence", "Visual effects will be removed in " + str(vfx_removal_delay) + " seconds")
	
	# Start timer to spawn iconoclast avatar after delay
	if spawn_iconoclast:
		iconoclast_timer.start(iconoclast_spawn_delay)
		DebugLogger.log_message("HawkingConsequence", "Iconoclast will spawn in " + str(iconoclast_spawn_delay) + " seconds")
	
	# Mark main effect as inactive
	is_effect_active = false

func _restore_movement_with_fade() -> void:
	if not player:
		return
	
	# Use the player's slow_player function to restore movement
	# The fade out time is passed as a parameter
	player.slow_player(false, movement_slow_factor, movement_fade_in, movement_fade_out)
	DebugLogger.log_message("HawkingConsequence", "Restoring movement speed over " + str(movement_fade_out) + " seconds")

func _fade_out_audio() -> void:
	if not audio_player or not audio_player.playing:
		return
	
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.tween_property(audio_player, "volume_db", -80.0, audio_fade_out_duration)
	fade_tween.tween_callback(func(): 
		audio_player.stop()
		audio_player.volume_db = 0.0
		DebugLogger.log_message("HawkingConsequence", "Audio faded out and stopped")
	)

func _remove_visual_effects() -> void:
	if not vfx_active:
		return
	
	vfx_active = false
	DebugLogger.log_message("HawkingConsequence", "Removing visual effects")
	
	# Get player VFX component
	var vfx_component = player.get_node_or_null("PlayerVFXComponent")
	if not vfx_component:
		vfx_component = player.vfx_component if "vfx_component" in player else null
	
	if vfx_component and vfx_component.has_method("stop_effect"):
		# Do a blink transition
		vfx_component.invoke_effect("blink", 0.3, 0.5, 0.3)
		
		# Wait for blink to start then stop the effects
		await get_tree().create_timer(0.4).timeout
		
		# Stop shape dilation
		vfx_component.stop_effect("shape_dilation")
		DebugLogger.log_message("HawkingConsequence", "Disabled shape dilation effect")
	else:
		DebugLogger.log_message("HawkingConsequence", "No VFX component found on player")

func _spawn_iconoclast_avatar() -> void:
	DebugLogger.log_message("HawkingConsequence", "Attempting to spawn iconoclast avatar")
	
	# Check if event manager exists
	if not GameManager.event_manager:
		DebugLogger.log_message("HawkingConsequence", "Event manager not available")
		return
	
	# Trigger the entity_appearance event which will spawn the iconoclast
	# This uses the same system as the game commands
	GameManager.event_manager.trigger_event("spawn_iconoclast")
	
	DebugLogger.log_message("HawkingConsequence", "Triggered entity_appearance event for iconoclast spawn")

func _exit_tree() -> void:
	# Clean up any active tweens
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
