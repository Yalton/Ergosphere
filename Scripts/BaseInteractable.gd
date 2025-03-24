# BaseInteractable.gd
# Base class for all interactable objects
class_name BaseInteractable
extends Node3D

signal interaction_started(interactor)
signal interaction_completed(interactor)
signal interaction_cancelled(interactor)

# Common properties for all interactables
@export var interaction_text: String = "Interact"
@export var interaction_hold_text: String = "Hold to interact"
@export var requires_hold: bool = false
@export var hold_duration: float = 1.0  # Time in seconds to hold
@export var cooldown_time: float = 0.0  # Time before interaction can happen again
@export var interaction_sound: AudioStream
@export var is_enabled: bool = true

# Internal variables
var current_interactor = null
var hold_progress: float = 0.0
var cooldown_timer: float = 0.0
var _sound_player: AudioStreamPlayer3D

func _ready() -> void:
	add_to_group("interactable")
	
	# Create audio player if not already a child
	if not has_node("InteractionAudio"):
		_sound_player = AudioStreamPlayer3D.new()
		_sound_player.name = "InteractionAudio"
		_sound_player.max_distance = 5.0
		add_child(_sound_player)
	else:
		_sound_player = get_node("InteractionAudio")

func _process(delta: float) -> void:
	# Handle cooldown
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	# Reset hold progress if no interactor
	if current_interactor == null and hold_progress > 0:
		hold_progress = 0.0

func can_interact() -> bool:
	return is_enabled and cooldown_timer <= 0

func get_interaction_text() -> String:
	if requires_hold:
		return interaction_hold_text
	return interaction_text

# Called when interaction begins
func begin_interaction(interactor) -> void:
	if not can_interact():
		return
		
	current_interactor = interactor
	
	if requires_hold:
		hold_progress = 0.0
	else:
		complete_interaction(interactor)
	
	interaction_started.emit(interactor)

# Called when interaction is held
func hold_interaction(interactor, delta: float) -> float:
	if current_interactor != interactor or not requires_hold:
		return 0.0
	
	hold_progress += delta / hold_duration
	hold_progress = clamp(hold_progress, 0.0, 1.0)
	
	if hold_progress >= 1.0:
		complete_interaction(interactor)
	
	return hold_progress

# Called when interaction is completed
func complete_interaction(interactor) -> void:
	if current_interactor != interactor:
		return
	
	# Play interaction sound
	if _sound_player and interaction_sound:
		_sound_player.stream = interaction_sound
		_sound_player.play()
	
	# Reset hold progress
	hold_progress = 0.0
	
	# Start cooldown
	cooldown_timer = cooldown_time
	
	# Perform the actual interaction behavior
	_on_interaction_completed(interactor)
	
	interaction_completed.emit(interactor)
	current_interactor = null

# Called when interaction is cancelled
func cancel_interaction(interactor) -> void:
	if current_interactor != interactor:
		return
	
	hold_progress = 0.0
	interaction_cancelled.emit(interactor)
	current_interactor = null

# Virtual method to be overridden by child classes
func _on_interaction_completed(interactor) -> void:
	pass

# Enable/disable interaction
func set_enabled(enabled: bool) -> void:
	is_enabled = enabled

# Update interaction text dynamically
func update_interaction_text(new_text: String) -> void:
	interaction_text = new_text
	
func update_hold_text(new_text: String) -> void:
	interaction_hold_text = new_text
