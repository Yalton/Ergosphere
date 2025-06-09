extends Node

## Component that plays impact sounds when attached to a RigidBody3D based on collision velocity
class_name ImpactSound

## Array of AudioStream resources to randomly choose from when playing impact sounds
@export var impact_sounds: Array[AudioStream] = []

## Minimum velocity required to trigger an impact sound (units per second)
@export var velocity_threshold: float = 0.5

## Minimum volume in decibels when at velocity threshold
@export var min_volume_db: float = -20.0

## Maximum volume in decibels when at max expected velocity
@export var max_volume_db: float = 0.0

## Velocity at which maximum volume is reached
@export var max_velocity: float = 10.0

## Minimum pitch scale (lower pitch)
@export var min_pitch: float = 0.8

## Maximum pitch scale (higher pitch)
@export var max_pitch: float = 1.2

## Additional random pitch variation (-/+ this value)
@export var pitch_randomness: float = 0.1

## Time in seconds before another impact sound can be played
@export var impact_cooldown: float = 0.1

var audio_player: AudioStreamPlayer3D
var parent_body: RigidBody3D
var last_impact_time: float = 0.0
var debug_logger

func _ready():
	# Register with DebugLogger if available
	if Engine.has_singleton("DebugLogger"):
		debug_logger = Engine.get_singleton("DebugLogger")
		debug_logger.register_module("ImpactSound")
	
	# Get parent RigidBody3D
	parent_body = get_parent() as RigidBody3D
	if not parent_body:
		push_error("ImpactSound must be a child of a RigidBody3D")
		queue_free()
		return
	
	# Create AudioStreamPlayer3D
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	
	# Connect to collision signal
	parent_body.body_entered.connect(_on_body_entered)
	parent_body.contact_monitor = true
	parent_body.max_contacts_reported = 10

func _on_body_entered(body: Node):
	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_impact_time < impact_cooldown:
		return
	
	# Get impact velocity
	var velocity = parent_body.linear_velocity.length()
	
	# Check velocity threshold
	if velocity < velocity_threshold:
		return
	
	# Play impact sound
	_play_impact_sound(velocity)
	last_impact_time = current_time

func _play_impact_sound(velocity: float):
	if impact_sounds.is_empty():
		if debug_logger:
			debug_logger.log("ImpactSound", "No impact sounds configured")
		return
	
	# Select random sound
	var sound = impact_sounds.pick_random()
	audio_player.stream = sound
	
	# Calculate volume based on velocity
	var velocity_normalized = clamp((velocity - velocity_threshold) / (max_velocity - velocity_threshold), 0.0, 1.0)
	var volume = lerp(min_volume_db, max_volume_db, velocity_normalized)
	audio_player.volume_db = volume
	
	# Calculate pitch based on velocity with randomness
	var pitch_base = lerp(min_pitch, max_pitch, velocity_normalized)
	var pitch_random = randf_range(-pitch_randomness, pitch_randomness)
	audio_player.pitch_scale = pitch_base + pitch_random
	
	# Play the sound
	audio_player.play()
	
	if debug_logger:
		debug_logger.log("ImpactSound", "Playing impact: velocity=%.2f, volume=%.2f dB, pitch=%.2f" % [velocity, volume, audio_player.pitch_scale])
