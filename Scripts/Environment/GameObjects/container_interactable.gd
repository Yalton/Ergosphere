# ContainerInteractable.gd
extends Node3D
class_name ContainerInteractable

signal container_opened
signal container_closed

## Animation player for opening/closing animations
@export var animation_player: AnimationPlayer
## Name of the opening animation
@export var open_animation: String = "open"
## Name of the closing animation  
@export var close_animation: String = "close"
## Sound to play when opening
@export var open_sound: AudioStream
## Sound to play when closing
@export var close_sound: AudioStream
## Audio player for container sounds
@export var audio_player: AudioStreamPlayer3D

# Internal state
var is_open: bool = false
var is_animating: bool = false

## Debug settings
@export var enable_debug: bool = true
var module_name: String = "ContainerInteractable"

## Display name for interactions
@export var display_name: String = "Container"

func _ready() -> void:
	DebugLogger.register_module(module_name, enable_debug)
	
	# Set display name if not already set
	if display_name.is_empty():
		display_name = "Container"
	
	# Connect animation finished signal
	if animation_player:
		if not animation_player.is_connected("animation_finished", _on_animation_finished):
			animation_player.animation_finished.connect(_on_animation_finished)
	else:
		DebugLogger.warning(module_name, "No animation player assigned")
	
	DebugLogger.debug(module_name, "Container initialized")

func interact(player_interaction: PlayerInteractionComponent) -> void:
	# Prevent interaction during animation
	if is_animating:
		DebugLogger.debug(module_name, "Interaction blocked - animation in progress")
		return
	if is_open:
		close_container()
	else:
		open_container()

func open_container() -> void:
	if is_open or is_animating:
		return
	
	DebugLogger.debug(module_name, "Opening container")
	is_animating = true
	
	
	# Play open animation
	if animation_player and animation_player.has_animation(open_animation):
		animation_player.play(open_animation)
	else:
		# No animation, complete immediately
		_complete_open()

func close_container() -> void:
	if not is_open or is_animating:
		return
	
	DebugLogger.debug(module_name, "Closing container")
	is_animating = true
	
	# Play close sound
	if audio_player and close_sound:
		audio_player.stream = close_sound
		audio_player.play()
	
	# Play close animation
	if animation_player and animation_player.has_animation(close_animation):
		animation_player.play(close_animation)
	else:
		# No animation, complete immediately
		_complete_close()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == open_animation:
		_complete_open()
	elif anim_name == close_animation:
		_complete_close()

func _complete_open() -> void:
	is_open = true
	is_animating = false
	container_opened.emit(self)
	DebugLogger.debug(module_name, "Container opened")

func _complete_close() -> void:
	is_open = false
	is_animating = false
	container_closed.emit(self)
	DebugLogger.debug(module_name, "Container closed")

# Public methods for external control
func force_open() -> void:
	if not is_open:
		open_container()

func force_close() -> void:
	if is_open:
		close_container()

# Public method for interaction text
func get_interaction_text() -> String:
	if is_animating:
		return "Please wait..."
	elif is_open:
		return "Close " + display_name
	else:
		return "Open " + display_name

func is_container_open() -> bool:
	return is_open

func is_container_animating() -> bool:
	return is_animating
