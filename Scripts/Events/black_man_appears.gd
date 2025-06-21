extends Node
class_name EnhancedVFXCleanup
## Enhanced VFX cleanup that rotates to face player, plays animations, handles audio, and manages complex particle cleanup
## Builds on VFXCleanup but adds player interaction and multi-stage cleanup

signal cleanup_requested

## Reference to the visibility timer component
@export var visibility_timer: VisibleOnScreenTimer3D
## How long the VFX should be visible before being removed (in seconds)
@export var visible_lifetime: float = 2.0
## Maximum time before cleanup regardless of visibility (in seconds) 
@export var max_lifetime: float = 10.0

@export_group("Player Interaction")
## Speed of rotation towards player
@export var rotation_speed: float = 2.0
## Whether to constantly face player or just rotate once
@export var continuous_rotation: bool = false

@export_group("Animation")
## Animation player for ready animation
@export var animation_player: AnimationPlayer
## Animation to play on ready
@export var ready_animation: String = "spawn"

@export_group("Audio")
## Audio player for when effect becomes visible
@export var audio_player: AudioStreamPlayer3D
## Whether to start audio automatically when visible
@export var auto_start_audio: bool = true

@export_group("Particle Cleanup")
## Particle system to emit during cleanup
@export var cleanup_particles: GPUParticles3D
## Negative light to fade out during final cleanup
@export var negative_light: Light3D
## Duration to wait for particles to finish
@export var particle_cleanup_duration: float = 2.0
## Duration to fade out negative light
@export var light_fade_duration: float = 1.0

@export_group("Advanced Cleanup")
## If true, fade out the parent node before removing it
@export var fade_out: bool = false
## Fade duration in seconds (only used if fade_out is true)
@export var fade_duration: float = 1.0

var max_timer: Timer
var is_cleaning_up: bool = false
var has_rotated_to_player: bool = false
var audio_started: bool = false
var cleanup_stage: int = 0  # 0=normal, 1=particle_phase, 2=light_fade, 3=complete
var player: Player  # Cached player reference

func _ready() -> void:
	DebugLogger.register_module("EnhancedVFXCleanup", true)
	
	# Get player from CommonUtils
	player = CommonUtils.get_player()
	if not player:
		DebugLogger.warning("EnhancedVFXCleanup", "No player found via CommonUtils")
	
	# Check if visibility timer is assigned
	if not visibility_timer:
		DebugLogger.error("EnhancedVFXCleanup", "No VisibleOnScreenTimer3D assigned!")
		return
	
	# Configure the visibility timer
	visibility_timer.required_visibility_duration = visible_lifetime
	visibility_timer.auto_reset_on_exit = false
	
	# Connect to visibility signals
	visibility_timer.visibility_duration_reached.connect(_on_visible_duration_reached)
	visibility_timer.screen_entered.connect(_on_screen_entered)
	
	# Set up max lifetime timer
	max_timer = Timer.new()
	max_timer.wait_time = max_lifetime
	max_timer.one_shot = true
	max_timer.timeout.connect(_on_max_lifetime_reached)
	add_child(max_timer)
	max_timer.start()
	
	# Play ready animation
	if animation_player and animation_player.has_animation(ready_animation):
		animation_player.play(ready_animation)
		DebugLogger.debug("EnhancedVFXCleanup", "Playing ready animation: %s" % ready_animation)
	
	DebugLogger.debug("EnhancedVFXCleanup", "Initialized - visible: %fs, max: %fs" % [visible_lifetime, max_lifetime])

func _process(delta: float) -> void:
	if is_cleaning_up:
		return
	
	# Get fresh player reference if we don't have one
	if not player:
		player = CommonUtils.get_player()
		if not player:
			return
	
	# Handle rotation to face player
	if continuous_rotation or not has_rotated_to_player:
		_rotate_towards_player(delta)

func _on_screen_entered() -> void:
	DebugLogger.debug("EnhancedVFXCleanup", "Entered screen - starting audio")
	
	# Start audio when visible
	if auto_start_audio and audio_player and not audio_started:
		audio_player.play()
		audio_started = true
		DebugLogger.debug("EnhancedVFXCleanup", "Audio started")

func _rotate_towards_player(delta: float) -> void:
	if not player:
		return
	
	var parent_node = get_parent()
	if not parent_node is Node3D:
		return
	
	var target_transform = parent_node.global_transform.looking_at(player.global_position, Vector3.UP, true)
	parent_node.global_transform = parent_node.global_transform.interpolate_with(target_transform, rotation_speed * delta)
	
	if not continuous_rotation and not has_rotated_to_player:
		# Check if we're close enough to consider rotation complete
		var angle_diff = parent_node.global_transform.basis.z.angle_to(target_transform.basis.z)
		if angle_diff < 0.1:  # Close enough
			has_rotated_to_player = true
			DebugLogger.debug("EnhancedVFXCleanup", "Rotation to player complete")

func _on_visible_duration_reached(total_time: float) -> void:
	if is_cleaning_up:
		return
		
	DebugLogger.debug("EnhancedVFXCleanup", "Player viewed for %fs - starting cleanup" % total_time)
	_start_cleanup()

func _on_max_lifetime_reached() -> void:
	if is_cleaning_up:
		return
		
	DebugLogger.debug("EnhancedVFXCleanup", "Max lifetime reached - starting cleanup")
	_start_cleanup()

func _start_cleanup() -> void:
	if is_cleaning_up:
		return
		
	is_cleaning_up = true
	cleanup_stage = 0
	
	# Stop the max timer
	if max_timer:
		max_timer.stop()
	
	# Stop audio
	if audio_player and audio_player.playing:
		audio_player.stop()
	
	if fade_out:
		_fade_out_and_cleanup()
	else:
		_start_particle_cleanup()

func _fade_out_and_cleanup() -> void:
	var parent_node = get_parent()
	if not parent_node:
		_start_particle_cleanup()
		return
	
	if parent_node.has_method("set_modulate"):
		var tween = create_tween()
		tween.tween_property(parent_node, "modulate", Color(1, 1, 1, 0), fade_duration)
		tween.tween_callback(_start_particle_cleanup)
		DebugLogger.debug("EnhancedVFXCleanup", "Fading out over %fs" % fade_duration)
	else:
		_start_particle_cleanup()

func _start_particle_cleanup() -> void:
	cleanup_stage = 1
	DebugLogger.debug("EnhancedVFXCleanup", "Starting particle cleanup phase")
	
	# Hide everything except particles and negative light
	var parent_node = get_parent()
	if parent_node:
		_hide_all_children_except_particles_and_light(parent_node)
	
	# Start particle emission
	if cleanup_particles:
		cleanup_particles.emitting = true
		DebugLogger.debug("EnhancedVFXCleanup", "Cleanup particles started")
	
	# Wait for particles to finish
	var particle_timer = Timer.new()
	particle_timer.wait_time = particle_cleanup_duration
	particle_timer.one_shot = true
	particle_timer.timeout.connect(_start_light_fade)
	add_child(particle_timer)
	particle_timer.start()

func _hide_all_children_except_particles_and_light(node: Node) -> void:
	for child in node.get_children():
		if child == cleanup_particles or child == negative_light or child == self:
			continue
		
		if child.has_method("set_visible"):
			child.set_visible(false)
		elif child.has_method("hide"):
			child.hide()

func _start_light_fade() -> void:
	cleanup_stage = 2
	DebugLogger.debug("EnhancedVFXCleanup", "Starting light fade phase")
	
	# Stop particle emission
	if cleanup_particles:
		cleanup_particles.emitting = false
	
	# Fade out negative light
	if negative_light:
		var tween = create_tween()
		tween.tween_property(negative_light, "light_energy", 0.0, light_fade_duration)
		tween.tween_callback(_complete_cleanup)
		DebugLogger.debug("EnhancedVFXCleanup", "Fading negative light over %fs" % light_fade_duration)
	else:
		_complete_cleanup()

func _complete_cleanup() -> void:
	cleanup_stage = 3
	DebugLogger.debug("EnhancedVFXCleanup", "Cleanup complete - requesting removal")
	cleanup_requested.emit()

## Tell spawners we handle our own cleanup
func handles_own_cleanup() -> bool:
	return true
